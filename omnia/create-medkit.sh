#!/bin/bash
#
# Copyright (C) 2016-2021 Tomas Hlavacek (tmshlvck@gmail.com)


MIRROR="http://ftp.ch.debian.org/debian/"
DEBVER="stable"
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

$SUDO bash <<ENDSCRIPT
rm -rf $ROOTDIR
mkdir $ROOTDIR

qemu-debootstrap --arch armhf $DEBVER $ROOTDIR $MIRROR
if [[ \$? != 0 ]]; then
	print "Debootstrap failed. Exit."
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
deb $MIRROR $DEBVER main non-free non-free-firmware
deb http://security.debian.org/ $DEBVER-security/updates main non-free non-free-firmware
EOF

cat >$ROOTDIR/etc/rc.local <<EOF
#!/bin/sh -e

exit 0
EOF

cat >$ROOTDIR/etc/fstab <<EOF
/dev/mmcblk0p1 / btrfs rw,ssd,subvol=@,noatime,nodiratime		0	0
tmpfs          /tmp       tmpfs   defaults,noatime,mode=1777            0       0
tmpfs          /var/tmp   tmpfs   defaults,noatime,mode=1777            0       0
EOF

# enable watchdog
sed -i 's/#RuntimeWatchdogSec=0/RuntimeWatchdogSec=30/' $ROOTDIR/etc/systemd/system.conf

# create static DTBs
cp $BUILDROOT/files/armada-385-turris-omnia-phy.dtb $ROOTDIR/boot/
cp $BUILDROOT/files/armada-385-turris-omnia-sfp.dtb $ROOTDIR/boot/ 

# copy genbootscr
cd $BUILDROOT
cp files/genbootscr $ROOTDIR/etc/kernel/postinst.d/z99-genbootscr
chown root:root $ROOTDIR/etc/kernel/postinst.d/z99-genbootscr
ENDSCRIPT

if [[ $? != 0 ]]; then
	print "Ssudoed script failed. Exit."
	exit -1
fi


$SUDO chroot $ROOTDIR bash <<ENDSCRIPT
cd /
apt-get -y update
apt-get -y install u-boot-tools initramfs-tools xz-utils

# TODO: Install a package with genbootscr and script to do the following initramfs hack
# change initrd compressions to XZ
sed -r -i 's/^COMPRESS=.*/COMPRESS=xz/' /etc/initramfs-tools/initramfs.conf

apt-get -y install linux-image-armmp
apt-get -y install ssh btrfs-progs i2c-tools firmware-atheros mtd-utils bridge-utils

sed -i 's/^.\?PermitRootLogin .\+$/PermitRootLogin yes/' /etc/ssh/sshd_config

echo "spi_nor" >>/etc/modules
ENDSCRIPT

# cleanup QEMU
#$SUDO rm -f ${ROOTDIR}${QEMU}

# create package
cd $ROOTDIR
$SUDO rm -f ../omnia-medkit.tar.gz
$SUDO tar zcf ../omnia-medkit.tar.gz *
$SUDO mv ../omnia-medkit.tar.gz ${BUILDROOT}
cd $BUILDROOT
d=`date "+%Y%m%d"`
$SUDO mv omnia-medkit.tar.gz omnia-medkit-${d}.tar.gz
$SUDO md5sum omnia-medkit-${d}.tar.gz >omnia-medkit-${d}.tar.gz.md5

exit 0

# cleanup rootdir
$SUDO rm -rf $ROOTDIR

