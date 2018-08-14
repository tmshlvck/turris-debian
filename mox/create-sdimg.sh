#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# debootstrap
# qemu-user
# qemu-user-static
# git
# devscripts
# kernel-package
# u-boot-tools
#
# Linaro GCC 7.3 & toolchain
#
# $SUDO || root privileges
#

MIRROR="http://ucho.ignum.cz/debian/"
DEBVER="stretch"
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
QEMU=`which qemu-aarch64-static`
if ! [ -f ${QEMU} ]; then
	echo "QEMU $QEMU not found. Stop."
	exit -1
fi

$SUDO bash <<ENDSCRIPT
rm -rf $ROOTDIR
mkdir $ROOTDIR

# debootstrap stage1
debootstrap --arch arm64 --foreign $DEBVER $ROOTDIR $MIRROR
if [[ $? != 0 ]]; then
	print "Debootstrap failed. Exit."
	exit -1
fi

# prepare QEMU
cp $QEMU $ROOTDIR/usr/bin/

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

# allow the console
echo "ttyMV0" >>$ROOTDIR/etc/securetty

# configure the system
echo -e "${PASSWORD}\n${PASSWORD}" | chroot $ROOTDIR passwd root

echo "$HOSTNAME" >$ROOTDIR/etc/hostname

cp files/interfaces $ROOTDIR/etc/network/interfaces
chown root:root $ROOTDIR/etc/network/interfaces

cat >$ROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR $DEBVER main
deb http://security.debian.org/ $DEBVER/updates main
EOF


cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

exit 0
EOF

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / ext4 rw,noatime,nodiratime		0	0
EOF

# enable watchdog
sed -ir 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf

# prepare U-Boot bootscript
mkimage -T script -C none -n boot -d files/boot.txt ${ROOTDIR}/boot/boot.scr

# copy gen-bootlink
cd $BUILDROOT
cp files/gen-bootlink $ROOTDIR/etc/kernel/postinst.d/
chown root:root $ROOTDIR/etc/kernel/postinst.d/gen-bootlink

# copy Marvell firmware
cd $BUILDROOT
mkdir -p $ROOTDIR/lib/firmware/mrvl
cp files/sd8997_uapsta.bin $ROOTDIR/lib/firmware/mrvl
 
# prepare directory for scripts
mkdir -p $ROOTDIR/usr/local/sbin/
ENDSCRIPT

if [[ $? != 0 ]]; then
	print "Sudoed script failed. Exit."
	exit -1
fi


# use already built kernel
cd $BUILDROOT
KIP=`ls linux-image-*_arm64.deb | grep -v -- "-dbg_" | sort --version-sort | tail -n1`
HIP=`ls linux-headers-*_arm64.deb | sort --version-sort | tail -n1`
if ! [ -f $KIP ]; then
	echo "Missing file $KIP . Exit."
fi
if ! [ -f $HIP ]; then
	echo "Missing file $HIP . Exit."
fi
$SUDO cp $KIP $HIP $ROOTDIR

# run postinst script in QEMU and cleanup


$SUDO bash <<ENDSCRIPT
cat >$ROOTDIR/root/postinst.sh <<EOF
cd /
dpkg -i $KIP $HIP
rm -f $KIP $HIP
/etc/kernel/postinst.d/gen-bootlink
apt-get -y update
apt-get -y install build-essential gcc make git python ssh btrfs-tools i2c-tools
sed -ir 's/^[#]*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
EOF

chroot $ROOTDIR /bin/bash /root/postinst.sh
rm $ROOTDIR/root/postinst.sh

# cleanup QEMU
#rm ${ROOTDIR}${QEMU}
ENDSCRIPT

# create package
cd $ROOTDIR
$SUDO rm -f ../mox-sdimg.tar.gz
$SUDO tar zcf ../mox-sdimg.tar.gz *
cd $BUILDROOT
d=`date "+%Y%m%d"`
$SUDO mv mox-sdimg.tar.gz mox-sdimg-${d}.tar.gz
$SUDO md5sum mox-sdimg-${d}.tar.gz >mox-sdimg-${d}.tar.gz.md5

exit 0
$SUDO rm -rf $ROOTDIR

