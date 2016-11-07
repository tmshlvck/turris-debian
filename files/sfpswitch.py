#!/usr/bin/python
#
# sfpswitch daemon for Turris Omnia
# Copyright (c) 2016 CZ.NIC, z.s.p.o.

force_mode = None
# possible force_mode values are:
# None : autodetection
# 'phy-def' - metallic PHY
# 'phy-sfp' - 1000BASE-X
# 'phy-sfp-noneg' - 1000BASE-X, no up/down in-band signalling (force up)
# 'phy-sfp-sgmii' - SGMII

lockfile = '/var/run/sfpswitch.lock'
debug = False
daemon = False


import sys
import os
import select
import time
import fcntl
import syslog
import getopt
import subprocess


def l(message):
	if daemon:
		syslog.syslog(message)
	else:
		sys.stderr.write(message + "\n")

def d(message):
	if debug:
		l(message)


class GPIO:
	gpio_export = '/sys/class/gpio/export'

	def _sysfs_dir(self):
		return '/sys/class/gpio/gpio%d/' % self.pin


	def __init__(self, pin, direction, edge=None, value=None):
		self.pin = pin
		
		d = self._sysfs_dir()
		if not (os.path.exists(d) and os.path.isdir(d)):
			with open(GPIO.gpio_export, 'w') as f:
				f.write(str(pin))

		if not (os.path.exists(d) and os.path.isdir(d)):
			raise Exception('Can not access %s' % d)

		with open(os.path.join(d, 'direction'), 'w') as f:
			f.write(direction)

		if direction == 'in':
			self.fd = open(os.path.join(d, 'value'), 'r')
		elif direction == 'out':
			self.fd = open(os.path.join(d, 'value'), 'w')
		else:
			raise Exception('Unknown direction %s' % direction)

		if edge:
			with open(os.path.join(d, 'edge'), 'w') as f:
				f.write(edge)

		if value:
			self.fd.write(value)


	def read(self):
		self.fd.seek(0)
		return int(self.fd.read().strip())


	def write(self, val):
		self.fd.write(str(val))


	def getfd(self):
		return self.fd.fileno()


class LED:
	def __init__(self, sysfsdir):
		self.sysfsdir = sysfsdir

	def _get_file(self, filename):
		return os.path.join(self.sysfsdir, filename) 

	def set_autonomous(self, aut):
		with open(self._get_file('autonomous'), 'w') as f:
			f.write('1' if aut else '0')


	def set_brightness(self, light):
		with open(self._get_file('brightness'), 'w') as f:
			f.write('255' if light else '0')


class EEPROM:
	IOCTL_I2C_SLAVE = 0x0703

	def __init__(self, busnum, address=0x50, size=256, pagesize=8):
		self.busnum = busnum
		self.address = address
		self.size = size
		self.pagesize = pagesize

	@staticmethod
	def _get_dev_filename(busnum):
		return "/dev/i2c-%d" % busnum

	def open_i2c(self):
		self.f = open(self._get_dev_filename(self.busnum), "w+b", 0)
		fcntl.ioctl(self.f, self.IOCTL_I2C_SLAVE, self.address)

	def read_byte(self, offset):
		self.f.write(chr(offset))
		return self.f.read(1)

	def read_page(self, offset, size):
		self.f.write(chr(offset))
		return self.f.read(size)

	def read_eeprom(self):
		self.open_i2c()

		for addr in range(0, self.size-1):
			offset = addr % self.pagesize
			if offset == 0:
				b = self.read_page(addr, self.pagesize)
			if addr == self.size-1:
				self.f.close()
			yield b[offset]



class SFP:
	def __init__(self, i2cbus):
		self.i2cbus = i2cbus

	@staticmethod
	def detect_metanoia_xdsl(eeprom):
		return ['X', 'C', 'V', 'R', '-', '0', '8', '0', 'Y', '5',
			'5',] == eeprom[40:51]

	@staticmethod
	def detect_zisa_gpon(eeprom):
		return ['T', 'W', '2', '3', '6', '2', 'H'] == eeprom[40:47]

	@staticmethod
	def detect_sgmii(eeprom):
		if ord(eeprom[6]) & 0x08:
			d("Mode selected: generic SGMII")
			return True
		else:
			d("Mode selected: generic 1000BASE-X")

		return False


	def decide_sfpmode(self):
		ec = []
		try:
			ec = list(EEPROM(self.i2cbus).read_eeprom())
			d("SFP EEPROM: %s" % str(ec))
		except Exception as e:
			l("EEPROM read error: " + str(e))
			return 'phy-sfp'

		# special case: Metanoia xDSL SFP, 1000BASE-X, no link autonegotiation
		if self.detect_metanoia_xdsl(ec):
			l("Metanoia DSL SFP detected. Switching to phy-sfp-noneg mode.")
			return 'phy-sfp-noneg'

		# special case: Zisa GPON SFP, SGMII
		if self.detect_zisa_gpon(ec):
			l("Zisa GPON SFP detected. Switching to phy-sfp-sgmii mode.")
			return 'phy-sfp-sgmii'

		# SGMII detection
		if self.detect_sgmii(ec):
			return 'phy-sfp-sgmii'

		# default 1000BASE-X
		return 'phy-sfp'



class Omnia:
	sfpdet_pin = 508
	sfpdis_pin = 505
	sfplos_pin = 507
	sfpflt_pin = 504

	sfp_select = '/sys/devices/platform/soc/soc:internal-regs/f1034000.ethernet/net/eth1/phy_select'
	bin_ip = '/sbin/ip'
	sfp_iface = 'eth1'
	cmd_init_time = 1
	wan_led = '/sys/devices/platform/soc/soc:internal-regs/f1011000.i2c/i2c-0/i2c-1/1-002b/leds/omnia-led:wan'

	sfp_i2c_bus = 5
	sfp_i2c_eeprom_init_time = 1


	def __init__(self):
		self.sfpdet = GPIO(self.sfpdet_pin, 'in', edge='both')
		self.sfplos = GPIO(self.sfplos_pin, 'in', edge='both')
		self.sfpflt = GPIO(self.sfpflt_pin, 'in', edge='both')
		self.sfpdis = GPIO(self.sfpdis_pin, 'out', edge=None, value=0)
		self.led = LED(self.wan_led)

	def set_nic_mode(self, mode):
		l('Switching NIC mode to %s.' % mode)

		with open(self.sfp_select, 'r') as f:
			c = f.read()
			if c == mode:
				d("Current mode is already %s. Noop." % c)
				return False
		
		with open(self.sfp_select, 'w') as f:
			f.write(mode)

		d("Switched successfully to mode %s." % mode)
		return True

	def restart_net(self):
		d("Testing whether the interface %s is up..." % self.sfp_iface)
		p = subprocess.Popen([self.bin_ip, 'link', 'show', 'dev', self.sfp_iface],
					stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		out, err = p.communicate()
		if ',UP,' in out:
			d("Interface %s is up. Sleeping for %d second(s)." % (self.sfp_iface,
				self.cmd_init_time))
			time.sleep(self.cmd_init_time)

			l("Shutting down interface %s" % self.sfp_iface)
			subprocess.call([self.bin_ip, 'link', 'set', 'down', 'dev', self.sfp_iface])
			l("Bringing up interface %s" % self.sfp_iface)
			subprocess.call([self.bin_ip, 'link', 'set', 'up', 'dev', self.sfp_iface])
		else:
			l("Interface is down. Noop." % self.sfp_iface)

		d("Net restart finished.")


	def led_light_handler(self):
		if self.sfpdet.read() == 1: # which is weird
			d("Warning: SFP status signal changing in PHY mode.")
			self.led.set_brightness(False)
			return

		self.led.set_brightness(False if self.sfplos.read() or
			self.sfpflt.read() else True)

	def led_mode_handler(self):
		sfpdet_val = self.sfpdet.read()

		if sfpdet_val == 1: # phy-def, autonomous blink
			self.led.set_brightness(False)

		self.led.set_autonomous(sfpdet_val)

		if sfpdet_val == 0: # phy-sfp or phy-sfp-*, user blink
			self.led_light_handler()

	def decide_nic_mode(self):
		global force_mode
		if force_mode:
			return force_mode

		sfpdet_val = self.sfpdet.read()

		if sfpdet_val == 1: # phy-def, autonomous blink
			d("Removed SFP, using onboad PHY.")
			return 'phy-def'
		elif sfpdet_val == 0: # phy-sfp or phy-sfp-*, user blink
			d("SFP inserted, setting sfpdis=0")
			self.sfpdis.write(0)
			d("Going to probe EEPROM after init in %d s." %
				self.sfp_i2c_eeprom_init_time)
			time.sleep(self.sfp_i2c_eeprom_init_time)
			return SFP(self.sfp_i2c_bus).decide_sfpmode()

	def nic_mode_handler(self):
		# set the NIC mode in /sys
		net_res_flag = self.set_nic_mode(self.decide_nic_mode())
		# set proper LED mode and turn on/off the LED
		self.led_mode_handler()
		# restart interface in Linux for changes in /sys to be applied
		if net_res_flag:
			o.restart_net()
		else:
			d("Mode not changed. Iface restart not needed.")





# Frontend functions

def reset_led():
	Omnia().led_mode_handler()

def oneshot():
	Omnia().nic_mode_handler()


def run():
	try:
		lf = open(lockfile, 'w+')
		fcntl.flock(lf, fcntl.LOCK_EX | fcntl.LOCK_NB)
		lf.write(str(os.getpid())+"\n")
		lf.flush()
	except IOError as e:
		l('Can not obtain lock file %s. Exit.' % lockfile)
		sys.exit(1)

	o = Omnia()

	def fdet_changed():
		d("sfp det change detected: %d" % o.sfpdet.read())
		o.nic_mode_handler()

	def flos_changed():
		d("sfp los change detected: %d " % o.sfplos.read())
		o.led_light_handler()

	def fflt_changed():
		d("sfp flt change detected: %d" % o.sfpflt.read())
		o.led_light_handler()

	# init
	fdet_changed()

	po = select.epoll()
	po.register(o.sfpdet.getfd(), select.EPOLLPRI)
	po.register(o.sfplos.getfd(), select.EPOLLPRI)
	po.register(o.sfpflt.getfd(), select.EPOLLPRI)

	# main loop
	while True:
		events = po.poll(60000)
		for e in events:
			ef = e[0] # event file descriptor
			if ef == o.sfpdet.getfd():
				fdet_changed()
			elif ef == o.sfplos.getfd():
				flos_changed()
			elif ef == o.sfpflt.getfd():
				fflt_changed()
			else:
				raise Exception("Unknown FD. Can not happen.")


def create_daemon():
	try:
		pid = os.fork()
		if pid > 0:
			sys.exit(0)

	except OSError as e:
		l('Unable to fork. Error: %s' % str(e))
		sys.exit(1)

	run()

def help():
	print """sfpswitch.py daemon for Turris Omnia

-o --oneshot : set the PHY and restart network, then exit
-n --nodaemon : run in foreground
-r --resetled : reset the LED according to current mode, then exit
-d --debug : turn on debug output
NO PARAM : daemonize and wait in loop for PHY change
"""

def main():
	global debug, daemon
	daemon = False
	oneshot_flag = False
	resetled_flag = False
	nodaemon_flag = False

	optlist = args = []
	try:
		optlist, args = getopt.getopt(sys.argv[1:], "ornhd",
			['oneshot', 'resetled', 'nodaemon', 'help', 'debug'])
	except getopt.GetoptError as err:
		print str(err)+"\n"
		help()
		sys.exit(1)

	for o, a in optlist:
		if o == '--oneshot' or o == '-o':
			oneshot_flag = True
		elif o == '--resetled' or o == '-r':
			resetled_flag = True
		elif o == '--nodaemon' or o == '-n':
			nodaemon_flag = True
		elif o == '--help' or o == '-h':
			help()
			sys.exit(0)
		elif o == '--debug' or o == '-d':
			debug = True
		else:
			print "Unknown option: %s" % o
			help()
			sys.exit(1)

	if oneshot_flag:
		oneshot()
	elif resetled_flag:
		reset_led()
	elif nodaemon_flag:
		run()
	else:
		daemon = True
		create_daemon()



if __name__ == '__main__':
	main()

