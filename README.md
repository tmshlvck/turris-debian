omnia-debian
============

Scripts for creating Debian image for board Turris Omnia
by CZ.NIC, z.s.p.o. (https://www.turris.cz/en/).

Dependencies:

 * debootstrap
 * qemu-user-static
 * git
 * gcc-arm-linux-gnueabihf
 * sudo & root privileges via sudo

The script needs some space (~3 GB) and takes some time (kernel
cross-compilation is the most time consuming operation).

Resulting file is omnia-medkit.tar.gz. Put this file to a root of
an ext2/3/4 filesystem on the USB flash and then go the reflash mode
on the Turris Omnia and wait until the Debian starts.

Root password is "turris" and by default a DHCP client runs on WAN
(eth1) interface and 192.168.1.1/24 address is set on LAN ports (all
ports are connected to the same VLAN in the switch chip).

