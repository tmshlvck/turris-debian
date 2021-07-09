#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# apt-get install debootstrap qemu-user qemu-user-static git devscripts u-boot-tools
#
# Linaro GCC 7.3 & toolchain int /opt
#
# $SUDO || root privileges
#

#echo "Not testedi yet. Not supported at this time. Sorry!"
#exit -1

MIRROR="http://debian.ignum.cz/debian/"
DEBVER="bullseye"
HOSTNAME="turris"
PASSWORD="turris"

BUILDROOT=`pwd`
ROOTDIR="/turrisroot"


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
qemu-debootstrap --arch arm64 $DEBVER $ROOTDIR $MIRROR
if [[ \$? != 0 ]]; then
	print "Debootstrap failed. Exit."
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
deb $MIRROR $DEBVER main non-free
deb http://security.debian.org/ $DEBVER/updates main non-free
EOF


cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

exit 0
EOF

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / ext4 rw,noatime,nodiratime		0	0
tmpfs          /tmp       tmpfs   defaults,noatime,mode=1777            0       0
tmpfs          /var/tmp   tmpfs   defaults,noatime,mode=1777            0       0
EOF

# enable watchdog
sed -ir 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf

# copy genbootscr
cd $BUILDROOT
cp files/genbootscr $ROOTDIR/etc/kernel/postinst.d/z99-genbootscr
chown root:root $ROOTDIR/etc/kernel/postinst.d/z99-genbootscr

## copy Marvell firmware
#cd $BUILDROOT
#mkdir -p $ROOTDIR/lib/firmware/mrvl
#cp files/sd8997_uapsta.bin $ROOTDIR/lib/firmware/mrvl
 
echo "moxtet" >>/etc/modules
ENDSCRIPT

if [[ $? != 0 ]]; then
	print "Sudoed script failed. Exit."
	exit -1
fi


$SUDO chroot $ROOTDIR /bin/bash <<ENDSCRIPT
cd /
apt-get -y update
apt-get -y install u-boot-tools
apt-get -y install linux-image-arm64
apt-get -y install ssh i2c-tools firmware-atheros crda bridge-utils

sed -ir 's/^[#]*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config

## temporary hack for buggy kernels
#if ! [ -d /etc/modprobe.d/ ]; then
#  mkdir -p /etc/modprobe.d/
#fi
#cat >/etc/modprobe.d/xhci-blacklist.conf <<EOF
#blacklist xhci-hcd
#blacklist xhci-plat-hcd
#EOF
ENDSCRIPT

# cleanup QEMU
#$SUDO rm -f ${ROOTDIR}${QEMU}

# create package
cd $ROOTDIR
$SUDO rm -f ../mox-sdimg.tar.gz
$SUDO tar zcf ../mox-sdimg.tar.gz *
$SUDO mv ../mox-sdimg.tar.gz ${BUILDROOT}
cd $BUILDROOT
d=`date "+%Y%m%d"`
$SUDO mv mox-sdimg.tar.gz mox-sdimg-${d}.tar.gz
$SUDO md5sum mox-sdimg-${d}.tar.gz >mox-sdimg-${d}.tar.gz.md5

exit 0

# cleanup rootdir
$SUDO rm -rf $ROOTDIR

