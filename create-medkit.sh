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
# sudo root privileges
#

MIRROR="http://ucho.ignum.cz/debian/"
HOSTNAME="turris"
PASSWORD="turris"

BUILDROOT=`pwd`
ROOTDIR="$BUILDROOT/root"

SWCONFIGREPO="https://github.com/jekader/swconfig.git"

SCHNAPPSREPO="https://gitlab.labs.nic.cz/turris/misc.git"
SCHNAPPSBIN="schnapps/schnapps.sh"




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

cp files/interfaces $ROOTDIR/etc/network/interfaces
chown root:root $ROOTDIR/etc/network/interfaces

cat >$ROOTDIR/etc/apt/sources.list <<EOF
deb $MIRROR jessie main
deb http://security.debian.org/ jessie/updates main
EOF

cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

/usr/local/sbin/sfpswitch.py

exit 0
EOF

cp files/swconfig.sh $ROOTDIR/etc/swconfig.sh
chown root:root $ROOTDIR/etc/swconfig.sh

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / btrfs rw,relatime,ssd,subvol=@			0	0
EOF

sed -ir 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf
ENDSCRIPT

# build kernel
cd $BUILDROOT
./create-kernel.sh
cd $BUILDROOT
KIP=`ls linux-image-*_armhf.deb | grep -v -- "-dbg_"`
HIP=`ls linux-headers-*_armhf.deb`
sudo cp $KIP $HIP $ROOTDIR

# copy omnia-gen-bootlink
sudo cp files/omnia-gen-bootlink $ROOTDIR/etc/kernel/postinst.d/
sudo chown root:root /etc/kernel/postinst.d/omnia-gen-bootlink

# install packages and run postinst
sudo bash <<ENDSCRIPT
chroot $ROOTDIR dpkg -i $KIP $HIP
rm $ROOTDIR/$KIP $ROOTDIR/$HIP

mkdir -p $ROOTDIR/usr/include/linux
cp $BUILDROOT/linux/include/uapi/linux/switch.h $ROOTDIR/usr/include/linux
chown root:root $ROOTDIR/usr/include/linux/switch.h

cd $BUILDROOT

# run postinst script in QEMU
cat >$ROOTDIR/root/postinst.sh <<EOF
/etc/kernel/postinst.d/omnia-gen-bootlink
apt-get -y update
apt-get -y install build-essential gcc make git libnl-3-dev linux-libc-dev libnl-genl-3-dev python ssh bridge-utils btrfs-tools i2c-tools
cd /root
git clone $SWCONFIGREPO swconfig
cd swconfig
make
cp swconfig /usr/local/sbin/
rm -rf /root/swconfig
sed -ir 's/^PermitRootLogin without-password$/PermitRootLogin yes/' /etc/ssh/sshd_config
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
d=`date "+%Y%m%d"`
mv omnia-medkit.tar.gz omnia-medkit-${d}.tar.gz
md5sum omnia-medkit-${d}.tar.gz >omnia-medkit-${d}.tar.gz.md5
$SUDO rm -rf $ROOTDIR
