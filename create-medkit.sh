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
# devscripts
# kernel-package
#
# $SUDO || root privileges
#

MIRROR="http://ucho.ignum.cz/debian/"
HOSTNAME="turris"
PASSWORD="turris"

BUILDROOT=`pwd`
ROOTDIR="$BUILDROOT/root"

#SWCONFIGREPO="https://github.com/jekader/swconfig.git"

SCHNAPPSREPO="https://gitlab.labs.nic.cz/turris/misc.git"
SCHNAPPSBIN="schnapps/schnapps.sh"



SUDO='/usr/bin/sudo'
if [ "$(id -u)" == "0" ]; then
	SUDO=''
fi
echo "Using sudo: $SUDO"

if [ -z "${ROOTDIR}" ]; then
	echo "Wrong ROOTDIR: ${ROOTDIR}"
	exit -1
fi
QEMU="/usr/bin/qemu-arm-static"

$SUDO bash <<ENDSCRIPT
rm -rf $ROOTDIR
mkdir $ROOTDIR

# debootstrap stage1
debootstrap --arch armhf --foreign jessie $ROOTDIR $MIRROR

# prepare QEMU
cp $QEMU $ROOTDIR/usr/bin/
update-binfmts --enable qemu-arm

# deboostrap stage2
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR /debootstrap/debootstrap --second-stage
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTDIR dpkg --configure -a

# configure the system
echo -e "${PASSWORD}\n${PASSWORD}" | chroot $ROOTDIR passwd root

echo "$HOSTNAME" >$ROOTDIR/etc/hostname

cp files/interfaces $ROOTDIR/etc/network/interfaces
chown root:root $ROOTDIR/etc/network/interfaces

cat >$ROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR jessie main
deb http://security.debian.org/ jessie/updates main
EOF

cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

exit 0
EOF

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / btrfs rw,relatime,ssd,subvol=@			0	0
EOF

# enable watchdog
sed -ir 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf

# copy omnia-gen-bootlink
cd $BUILDROOT
cp files/omnia-gen-bootlink $ROOTDIR/etc/kernel/postinst.d/
chown root:root $ROOTDIR/etc/kernel/postinst.d/omnia-gen-bootlink
 
# prepare directory for scripts
mkdir -p $ROOTDIR/usr/local/sbin/
ENDSCRIPT

# build kernel
cd $BUILDROOT
./create-kernel.sh
cd $BUILDROOT
KIP=`ls linux-image-*_armhf.deb | grep -v -- "-dbg_"`
HIP=`ls linux-headers-*_armhf.deb`
$SUDO cp $KIP $HIP $ROOTDIR

# run postinst script in QEMU and cleanup
$SUDO bash <<ENDSCRIPT
cat >$ROOTDIR/root/postinst.sh <<EOF
cd /
dpkg -i $KIP $HIP
rm -f $KIP $HIP
/etc/kernel/postinst.d/omnia-gen-bootlink
apt-get -y update
apt-get -y install build-essential gcc make git libnl-3-dev linux-libc-dev libnl-genl-3-dev python ssh bridge-utils btrfs-tools i2c-tools
sed -ir 's/^PermitRootLogin without-password$/PermitRootLogin yes/' /etc/ssh/sshd_config
EOF

chroot $ROOTDIR /bin/bash /root/postinst.sh
rm $ROOTDIR/root/postinst.sh

# cleanup QEMU
rm ${ROOTDIR}${QEMU}
ENDSCRIPT

# copy schnapps script
cd $BUILDROOT
git clone $SCHNAPPSREPO misc
$SUDO cp misc/$SCHNAPPSBIN $ROOTDIR/usr/local/sbin/schnapps
$SUDO chown root:root $ROOTDIR/usr/local/sbin/schnapps
$SUDO chmod a+x $ROOTDIR/usr/local/sbin/schnapps
rm -rf misc

# create package
cd $ROOTDIR
$SUDO rm -f ../omnia-medkit.tar.gz
$SUDO tar zcf ../omnia-medkit.tar.gz *
cd $BUILDROOT
d=`date "+%Y%m%d"`
mv omnia-medkit.tar.gz omnia-medkit-${d}.tar.gz
md5sum omnia-medkit-${d}.tar.gz >omnia-medkit-${d}.tar.gz.md5
$SUDO rm -rf $ROOTDIR
