#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# apt-get install debootstrap qemu-user qemu-user-static git devscripts kernel-package 	u-boot-tools
#
# optional: either own ARM cross-compiler or package gcc-arm-linux-gnueabihf
#
# $SUDO || root privileges
#

MIRROR="http://debian.ignum.cz/debian/"
DEBVER="buster"
HOSTNAME="turris"
PASSWORD="turris"

BUILDROOT=`pwd`
ROOTDIR="$BUILDROOT/root"




SUDO='/usr/bin/sudo'
if [ "$(id -u)" == "0" ]; then
	SUDO=''
fi
echo "Using sudo: $SUDO"

if [ -z "${ROOTDIR}" ]; then
	echo "Wrong ROOTDIR: ${ROOTDIR}"
	exit -1
fi
QEMU=`which qemu-arm-static`
if ! [ -f ${QEMU} ]; then
	echo "QEMU $QEMU not found. Stop."
	exit -1
fi

$SUDO bash <<ENDSCRIPT
rm -rf $ROOTDIR
mkdir $ROOTDIR

# debootstrap stage1
debootstrap --arch armhf --foreign $DEBVER $ROOTDIR $MIRROR
if [[ $? != 0 ]]; then
	print "Debootstrap failed. Exit."
	exit -1
fi

# prepare QEMU
cp $QEMU $ROOTDIR/usr/bin/
#update-binfmts --enable qemu-arm

# deboostrap stage2
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR /debootstrap/debootstrap --second-stage
if [[ $? != 0 ]]; then
	print "Debootstrap failed. Exit."
	exit -1
fi

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR dpkg --configure -a
if [[ $? != 0 ]]; then
	print "dpkg --configure failed. Exit."
	exit -1
fi

# configure the system
echo -e "${PASSWORD}\n${PASSWORD}" | chroot $ROOTDIR passwd root

echo "$HOSTNAME" >$ROOTDIR/etc/hostname

cp files/interfaces $ROOTDIR/etc/network/interfaces
chown root:root $ROOTDIR/etc/network/interfaces

cp files/fw_env.config $ROOTDIR/etc/
chown root:root $ROOTDIR/etc/fw_env.config

cat >$ROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR $DEBVER main non-free
deb http://security.debian.org/ $DEBVER/updates main non-free
EOF


cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

exit 0
EOF

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / btrfs rw,ssd,subvol=@,noatime,nodiratime		0	0
EOF

# enable watchdog
sed -i 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf

# prepare U-Boot bootscript
$SUDO mkimage -T script -C none -n boot -d files/boot.txt ${ROOTDIR}/boot/boot.scr

# copy gen-bootlink
d $BUILDROOT
cp files/gen-bootlink $ROOTDIR/etc/kernel/postinst.d/
chown root:root $ROOTDIR/etc/kernel/postinst.d/gen-bootlink
 
# prepare directory for scripts
mkdir -p $ROOTDIR/usr/local/sbin/
ENDSCRIPT

if [[ $? != 0 ]]; then
	print "Sudoed script failed. Exit."
	exit -1
fi


# use already built kernel
cd $BUILDROOT

# run postinst script in QEMU and cleanup


$SUDO chroot $ROOTDIR bash <<ENDSCRIPT
cd /
apt-get -y update
apt-get -y install gnupg build-essential gcc make git python ssh btrfs-tools i2c-tools firmware-atheros libnl-3-dev linux-libc-dev libnl-genl-3-dev python ssh bridge-utils btrfs-tools i2c-tools crda u-boot-tools mtd-utils

echo "deb http://cirrus.openavionics.eu/~th/omnia/ buster main" >>/etc/apt/sources.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B2A1CABB35F7C596
apt-get -y update
apt-get -y install linux-kernel-omnia
#/etc/kernel/postinst.d/gen-bootlink

/etc/kernel/postinst.d/gen-bootlink
sed -i 's/^.\?PermitRootLogin .\+$/PermitRootLogin yes/' /etc/ssh/sshd_config
ENDSCRIPT

# cleanup QEMU
$SUDO rm -f ${ROOTDIR}${QEMU}

# create package
cd $ROOTDIR
$SUDO rm -f ../omnia-medkit.tar.gz
$SUDO tar zcf ../omnia-medkit.tar.gz *
cd $BUILDROOT
d=`date "+%Y%m%d"`
$SUDO mv omnia-medkit.tar.gz omnia-medkit-${d}.tar.gz
$SUDO md5sum omnia-medkit-${d}.tar.gz >omnia-medkit-${d}.tar.gz.md5

exit 0

# cleanup rootdir
$SUDO rm -rf $ROOTDIR

