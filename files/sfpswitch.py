#!/usr/bin/python

import sys
import os
import select
import time

sfpdet_pin = 508
sfpdis_pin = 505

gpio_export = '/sys/class/gpio/export'
sfp_select = '/sys/devices/platform/soc/soc:internal-regs/f1034000.ethernet/net/eth1/phy_select'
map = { 1: 'phy-def', 0: 'phy-sfp' }
#cmd_net_res = 'ip link set down dev eth1; /etc/init.d/network restart' # OpenWRT
cmd_net_res = 'ifdown eth1; ifup eth1' # Debian
cmd_safety_sleep = 2

def write_once(path, value):
	with open(path, 'w') as f:
		f.write(value)



def gpio_dir(pin):
	return '/sys/class/gpio/gpio%d/' % pin

def init_gpio(pin):
	if not (os.path.exists(gpio_dir(pin)) and
		os.path.isdir(gpio_dir(pin))):
		write_once(gpio_export, str(pin))

	if not (os.path.exists(gpio_dir(pin)) and
		os.path.isdir(gpio_dir(pin))):
		raise Exception('Can not access %s' % gpio_dir(pin))
	

def init():
	init_gpio(sfpdet_pin)
	init_gpio(sfpdis_pin)

	write_once(os.path.join(gpio_dir(sfpdet_pin), 'direction'), 'in')
	write_once(os.path.join(gpio_dir(sfpdet_pin), 'edge'), 'both')

	write_once(os.path.join(gpio_dir(sfpdis_pin), 'direction'), 'out')
	write_once(os.path.join(gpio_dir(sfpdis_pin), 'value'), '0')



def do_switch(state, restart_net=True):
	print 'Switching state to %s' % map[state]
	write_once(sfp_select, map[state])
	if restart_net:
		time.sleep(cmd_safety_sleep)
		os.system(cmd_net_res)


def oneshot():
	init()
	f = open(os.path.join(gpio_dir(sfpdet_pin), 'value'), 'r')
	state_last = int(f.read().strip())
	do_switch(state_last, False)


def run():
	init()

	f = open(os.path.join(gpio_dir(sfpdet_pin), 'value'), 'r')
	po = select.poll()
	po.register(f, select.POLLPRI)

	state_last = int(f.read().strip())
	do_switch(state_last)

	while 1:
		events = po.poll(60000)
		if events:
			f.seek(0)
			state = int(f.read().strip())
			if state != state_last:
				state_last = state
				do_switch(state)

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
NO PARAM : daemonize and wait for PHY change
"""

def main():
	if len(sys.argv) > 1:
		if sys.argv[1] == '--oneshot':
			oneshot()
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

