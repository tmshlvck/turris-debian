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

cd kernel

R=`ls linux-image-*.deb | cut -d"_" -f2 | awk '$0>x{x=$0};END{print x}'`
if [ -z "${R}" ]; then
	R=0
fi
R=$(($R + 1))

if [ -f linux/.config ] && [ -f linux/arch/arm/configs/omnia_defconfig ]; then
	if ! diff ../files/omnia_defconfig linux/.config >/dev/null; then
		echo "The config in Kernel tree differs from files/omnia_defconfig. Copy it or remove it:"
		echo "  ---->   cp kernel/linux/.config files/omnia_defconfig"
		echo "  ---->   rm kernel/linux/.config"
		exit 0
	fi
fi
cp ../files/omnia_defconfig linux/arch/arm/configs
cd linux
make omnia_defconfig

export DEB_HOST_ARCH=armhf

make -j $(nproc) deb-pkg KDEB_PKGVERSION=${R}

