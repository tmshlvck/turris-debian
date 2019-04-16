turris-debian
=============

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

Omnia
=====

Resulting file is `omnia-medkit-<date>.tar.gz`. Put this file to a root of
an ext2/3/4 filesystem on the USB flash and then go the reflash mode
on the Turris Omnia and wait until the Debian starts.

Root password is "turris" and by default a DHCP client runs on WAN
(eth1) interface and 192.168.1.1/24 address is set on LAN ports (all
ports are connected to the same VLAN in the switch chip).

Latest compiled image is here:
http://aule.elfove.cz/~th/turris-debian/omnia/

But... Create your own image. It is easy!

Please note:

There the project Wiki: https://github.com/tmshlvck/turris-debian/wiki

You can find more information about installation, upstreaming of the
software, experimental Omnia Debian branch etc. there.

MOX
===

Resulting file is `mox-sdimg-<date>.tar.gz`. Extract contents of this file to a SD card formated with either ext2/3/4 or btrfs 
and use it as the Turris MOX boot device.
  
Root password is "turris".


Latest compiled image is here:
http://aule.elfove.cz/~th/turris-debian/mox/

But... Create your own image. It is easy!

