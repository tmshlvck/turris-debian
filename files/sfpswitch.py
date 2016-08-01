#!/usr/bin/python

import sys
import os
import select
import time

debug = 1

sfpdet_pin = 508
sfpdis_pin = 505
sfplos_pin = 507
sfpflt_pin = 504

sfp_select = '/sys/devices/platform/soc/soc:internal-regs/f1034000.ethernet/net/eth1/phy_select'
modemap = { 1: 'phy-def', 0: 'phy-sfp' }
#cmd_net_res = 'ip link set down dev eth1; /etc/init.d/network restart' # OpenWRT
cmd_net_res = 'ifdown eth1; ifup eth1' # Debian
cmd_safety_sleep = 2
wan_led = '/sys/devices/platform/soc/soc:internal-regs/f1011000.i2c/i2c-0/i2c-1/1-002b/leds/omnia-led:wan'



def d(message):
	if debug:
		print message


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
		self.fd.write(val)


	def getfd(self):
		return self.fd.fileno()


class LED:
	def __init__(self, sysfsdir):
		self.sysfsdir = sysfsdir


	def set_autonomous(self, aut):
		with open(os.path.join(self.sysfsdir, 'autonomous'), 'w') as f:
			f.write('1' if aut else '0')


	def set_brightness(self, bright):
		with open(os.path.join(self.sysfsdir, 'brightness'), 'w') as f:
			f.write('1' if bright else '0')





def set_nic_mode(mode, restart_net=True):
	d('Switching mode to %s' % modemap[mode])

	with open(sfp_select, 'r') as f:
		c = f.read()
		if c == modemap[mode]:
			d("Current mode is %s . Noop." % c)
			return
		
	with open(sfp_select, 'w') as f:
		f.write(modemap[mode])

	d("Switch success.")

	if restart_net:
		time.sleep(cmd_safety_sleep)
		d("Restarting net with command %s" % cmd_net_res)
		os.system(cmd_net_res)


def led_change(led, sfplos, sfpflt):
	led.set_brightness(False if sfplos.read() or sfpflt.read() else True)


def led_init(mode, led, sfplos, sfpflt):
	if mode == 1: # phy-def, autonomous blink
		led.set_brightness(False)
	led.set_autonomous(mode)
	if mode == 0: # phy-sfp, user blink
		led_change(led, sfplos, sfpflt)



def mode_change(sfpdet, led, sfplos, sfpflt, restart_net=True):
	m = sfpdet.read() # 0: phy-sfp, user blink; 1: phy-def, autonomous blink
	set_nic_mode(m, restart_net)
	led_init(m, led, sfplos, sfpflt)



# Frontend functions

def reset_led():
	sfpdet = GPIO(sfpdet_pin, 'in', edge='both')
	sfplos = GPIO(sfplos_pin, 'in', edge='both')
	sfpflt = GPIO(sfpflt_pin, 'in', edge='both')
	led = LED(wan_led)

	m = sfpdet.read() # 0: phy-sfp, user blink; 1: phy-def, autonomous blink
	led.set_autonomous(m)
	led_change(led, sfplos, sfpflt)


def oneshot():
	sfpdet = GPIO(sfpdet_pin, 'in', edge='both')
	sfpdis = GPIO(sfpdis_pin, 'out', value='0')
	sfplos = GPIO(sfplos_pin, 'in', edge='both')
	sfpflt = GPIO(sfpflt_pin, 'in', edge='both')
	led = LED(wan_led)

	mode_change(sfpdet, led, sfplos, sfpflt, False)


def run():
	sfpdet = GPIO(sfpdet_pin, 'in', edge='both')
	sfpdis = GPIO(sfpdis_pin, 'out', value='0')
	sfplos = GPIO(sfplos_pin, 'in', edge='both')
	sfpflt = GPIO(sfpflt_pin, 'in', edge='both')
	led = LED(wan_led)

	def fdet_changed():
		d("sfpdet change detected: %d" % sfpdet.read())
		mode_change(sfpdet, led, sfplos, sfpflt)

	def flos_changed():
		d("sfplos change detected: %d " % sfplos.read())
		led_change(led, sfplos, sfpflt)

	def fflt_changed():
		d("sfpflt change detected: %d" % sfpflt.read())
		led_change(led, sfplos, sfpflt)

	mode_change(sfpdet, led, sfplos, sfpflt, True)

	po = select.epoll()
	po.register(sfpdet.getfd(), select.EPOLLPRI)
	po.register(sfplos.getfd(), select.EPOLLPRI)
	po.register(sfpflt.getfd(), select.EPOLLPRI)

	# main loop
	while 1:
		events = po.poll(60000)
		for e in events:
			ef = e[0] # event file descriptor
			if ef == sfpdet.getfd():
				fdet_changed()
			elif ef == sfplos.getfd():
				flos_changed()
			elif ef == sfpflt.getfd():
				fflt_changed()
			else:
				raise Exception("Unknown FD. Can not happen.")


def create_daemon():
	try:
		pid = os.fork()
		if pid > 0:
			print 'PID: %d' % pid
			os._exit(0)

	except OSError, error:
		print 'Unable to fork. Error: %d (%s)' % (error.errno, error.strerror)
		os._exit(1)

	run()

def help():
	print """sfpswitch.py daemon for Turris Omnia

--oneshot : set the PHY and restart network, then exit
--nodaemon : run in foreground
--resetled : reset the LED according to current mode, then exit
NO PARAM : daemonize and wait for PHY change
"""

def main():
	if len(sys.argv) > 1:
		if sys.argv[1] == '--oneshot':
			oneshot()
		elif sys.argv[1] == '--resetled':
			reset_led()
		elif sys.argv[1] == '--nodaemon':
			run()
		elif sys.argv[1] == '--help':
			help()
		else:
			print "Unknown option: %s" % sys.argv[1]
			help()
	else:
		create_daemon()

if __name__ == '__main__':
	main()

