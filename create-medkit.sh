#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# debootstrap
# qemu-user
# qemu-user-static
# git
# gcc-arm-linux-gnueabihf
#
# sudo root privileges
#

MIRROR="http://ucho.ignum.cz/debian/"
HOSTNAME="turris"
PASSWORD="turris"

BUILDROOT=`pwd`
ROOTDIR="$BUILDROOT/root"

SWCONFIGREPO="https://github.com/jekader/swconfig.git"

SCHNAPPSREPO="https://gitlab.labs.nic.cz/turris/misc.git"
SCHNAPPSBIN="schnapps/schnapps"




if [ -z "${ROOTDIR}" ]; then
	echo "Wrong ROOTDIR: ${ROOTDIR}"
	exit -1
fi

sudo bash <<ENDSCRIPT
rm -rf $ROOTDIR
mkdir $ROOTDIR

# debootstrap stage1
debootstrap --arch armhf --foreign jessie $ROOTDIR $MIRROR

# prepare QEMU
cp /usr/bin/qemu-arm-static $ROOTDIR/usr/bin/

# deboostrap stage2
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR /debootstrap/debootstrap --second-stage
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR dpkg --configure -a

# configure the system
echo -e "${PASSWORD}\n${PASSWORD}" | chroot $ROOTDIR passwd root

echo "$HOSTNAME" >$ROOTDIR/etc/hostname
cat >$ROOTDIR/etc/network/interfaces <<EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual

auto eth2
iface eth2 inet manual

auto br0
iface br0 inet static
        bridge_ports wlan0 eth0 eth2
        address 192.168.1.1
        netmask 255.255.255.0

auto eth1
iface eth1 inet dhcp
	pre-up /usr/local/sbin/sfpswitch.py --oneshot
EOF

cat >$ROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR jessie main
EOF

cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

/usr/local/sbin/sfpswitch.py

swconfig dev switch0 set reset
swconfig dev switch0 vlan 1 set ports "0 1 2 3 5"
swconfig dev switch0 vlan 2 set ports "4 6"
swconfig dev switch0 set enable_vlan 1
swconfig dev switch0 set apply 1

exit 0
EOF

sed -ir 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf
ENDSCRIPT

# build kernel
cd $BUILDROOT
./create-kernel.sh
cd $BUILDROOT
KIP=`ls linux-image-*_armhf.deb | grep -v -- "-dbg_"`
FIP=`ls linux-firmware-image-*_armhf.deb`
HIP=`ls linux-headers-*_armhf.deb`
sudo cp $KIP $FIP $HIP $ROOTDIR

# copy omnia-gen-bootlink.sh
sudo cp files/omnia-gen-bootlink.sh $ROOTDIR/etc/kernel/postinst.d/
sudo chown root:root /etc/kernel/postinst.d/omnia-gen-bootlink.sh

# install packages and run postinst
sudo bash <<ENDSCRIPT
chroot $ROOTDIR dpkg -i $KIP $FIP $HIP
rm $ROOTDIR/$KIP $ROOTDIR/$FIP $ROOTDIR/$HIP

mkdir -p $ROOTDIR/usr/include/linux
cp $BUILDROOT/linux/include/uapi/linux/switch.h $ROOTDIR/usr/include/linux
chown root:root $ROOTDIR/usr/include/linux/switch.h

cd $BUILDROOT

# run postinst script in QEMU
cat >$ROOTDIR/root/postinst.sh <<EOF
/etc/kernel/postinst.d/omnia-gen-bootlink.sh
apt-get -y update
apt-get -y install build-essential gcc make git libnl-3-dev linux-libc-dev libnl-genl-3-dev python ssh
cd /root
git clone $SWCONFIGREPO swconfig
cd swconfig
make
cp swconfig /usr/local/sbin/
rm -rf /root/swconfig
EOF

chroot $ROOTDIR /bin/bash /root/postinst.sh
rm $ROOTDIR/root/postinst.sh

# cleanup QEMU
rm $ROOTDIR/usr/bin/qemu-arm-static
ENDSCRIPT

cd $BUILDROOT
rm -rf linux

# copy schnapps script
cd $BUILDROOT
git clone $SCHNAPPSREPO misc
sudo cp misc/$SCHNAPPSBIN $ROOTDIR/usr/local/sbin/schnapps
sudo chown root:root $ROOTDIR/usr/local/sbin/schnapps
sudo chmod a+x $ROOTDIR/usr/local/sbin/schnapps
rm -rf misc

# copy sfpswitch.py
sudo cp files/sfpswitch.py $ROOTDIR/usr/local/sbin/sfpswitch.py
sudo chown root:root $ROOTDIR/usr/local/sbin/sfpswitch.py

# create package
cd $ROOTDIR
touch ../omnia-medkit.tar.gz
sudo tar zcf ../omnia-medkit.tar.gz *
cd $BUILDROOT
sudo rm -rf $ROOTDIR
