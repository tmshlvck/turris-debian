#!/bin/bash

S3="http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-20181206T214502Z.tar.xz"

if (( `id -u` != 0 )); then
	echo "Error: Script must run as root in order to chroot to the directory. Exit."
	exit -1
fi

if ! [ -d builddir ]; then
	mkdir builddir
	if ! [ -f s3.tar.xz ]; then
		wget -O s3.tar.xz $S3
	fi
	cd builddir
	tar xf ../s3.tar.xz
	cd ..

	if ! [ -f portage-latest.tar.bz2 ]; then
		wget http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2
	fi
	cd builddir/usr
	tar xf ../../portage-latest.tar.bz2
	cd ..

	cp /etc/resolv.conf etc/

	cd ..
fi

mount --rbind /dev builddir/dev
mount --make-rslave builddir/dev
mount -t proc /proc builddir/proc
mount --rbind /sys builddir/sys
mount --make-rslave builddir/sys
mount --rbind /tmp builddir/tmp


### in the builddir
cat >builddir/tmp/mkbuilddir.tmp.sh <<EOF
#!/bin/bash
echo 'PORTDIR_OVERLAY="/usr/local/portage"' >> /etc/make.conf
mkdir -p /usr/local/portage/profiles
echo "moxprofile" > /usr/local/portage/profiles/repo_name

emerge crossdev

crossdev --g 5.4.0-r4 armv7m-none-eabi
crossdev --g 5.4.0-r4 aarch64-linux-gnu
crossdev aarch64-linux-gnu

ln -s /usr/libexec/gcc/aarch64-linux-gnu/ld /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/5.4.0/aarch64-linux-gnu-ld
ln -s /usr/libexec/gcc/aarch64-linux-gnu/objcopy /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/5.4.0/aarch64-linux-gnu-objcopy

ln -s /usr/libexec/gcc/aarch64-linux-gnu/ar /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-ar
ln -s /usr/libexec/gcc/aarch64-linux-gnu/ld /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-ld
ln -s /usr/libexec/gcc/aarch64-linux-gnu/objcopy /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-objcopy
ln -s /usr/libexec/gcc/aarch64-linux-gnu/readelf /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-readelf
ln -s /usr/libexec/gcc/aarch64-linux-gnu/nm /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-nm
ln -s /usr/libexec/gcc/aarch64-linux-gnu/objdump /usr/x86_64-pc-linux-gnu/aarch64-linux-gnu/gcc-bin/8.2.0/aarch64-linux-gnu-objdump
EOF
chmod a+x builddir/tmp/mkbuilddir.tmp.sh
chroot builddir /tmp/mkbuilddir.tmp.sh

echo "Ready for MOX U-Boot image build"

cd builddir/root

# this fails due to security through obscurity - username & password is needed (why?)
git clone --recurse-submodules https://gitlab.labs.nic.cz/turris/mox-boot-builder.git
cd mox-boot-builder
git am ../../../0001-Add-support-for-multiple-versions-of-GCC.patch

cd ../../..

cat >builddir/tmp/mkbuilddir2.tmp.sh <<EOF
#!/bin/bash
cd /root/mox-boot-builder
make untrusted-flash-image.bin
# the image will be created in this directory (untrusted-flash-image.bin -> flash to MOX to offset 0)
EOF
chmod a+x builddir/tmp/mkbuilddir2.tmp.sh
chroot builddir /tmp/mkbuilddir2.tmp.sh

# chroot to the builddir and let the user do the dirty tricks
echo "Chrooting to builddir. Free range for more work. Press Ctrl-D to exit."
chroot builddir

umount -R builddir/dev
umount -f builddir/dev
umount -f builddir/proc
umount -R builddir/sys
umount -f builddir/sys
umount -f builddir/tmp

