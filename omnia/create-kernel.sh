#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# git
# gcc-arm-linux-gnueabihf
# devscripts
# kernel-package
#

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

R=`ls linux-image-*.deb | cut -d"_" -f2 | awk '$0>x{x=$0};END{print x}'`
if [ -z "${R}" ]; then
	R=0
fi
R=$(($R + 1))

cp files/omnia_defconfig linux/arch/arm/configs
cd linux
make omnia_defconfig

export DEB_HOST_ARCH=armhf
export CONCURRENCY_LEVEL=$(( `grep processor /proc/cpuinfo | tail -n1 | cut -d: -f2` + 1 ))

make-kpkg --rootcmd fakeroot --arch arm --cross-compile arm-linux-gnueabihf- --revision=$R kernel_image kernel_headers

