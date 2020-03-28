#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# apt-get install git devscripts kernel-package libssl-dev equivs ncurses-dev
#

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

cd kernel/

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

make -j $(nproc) deb-pkg LOCALVERSION=-omnia

# crete meta-package
cd ..

KIP=`ls linux-image-*_armhf.deb | grep -v -- "-dbg_" | ../../sortkernel.py | tail -n1`
HIP=`ls linux-headers-*_armhf.deb | ../../sortkernel.py | tail -n1`
KDIP=`ls linux-image-*-dbg_*_armhf.deb | ../../sortkernel.py | tail -n1`

if ! [ -f $KIP ]; then
	        echo "Missing file $KIP . Exit."
		exit -1
fi

KIPN=`echo $KIP | awk -F'_' '{print $1}'`
HIPN=`echo $HIP | awk -F'_' '{print $1}'`
KDIPN=`echo $KDIP | awk -F'_' '{print $1}'`
KV=`echo $KIP | awk -F'_' '{print $2}'`

#equivs-control linux-kernel-omnia.cfg
cat > linux-kernel-omnia.cfg <<EOF
# Source: <source package name; defaults to package name>
Section: misc
Priority: optional
Homepage: https://github.com/tmshlvck/turris-debian
Standards-Version: 3.9.2

Package: linux-kernel-omnia
Version: $KV
Maintainer: Tomas Hlavacek <tmshlvck@gmail.com>
Depends: $KIPN(>=$KV),$HIPN(>=$KV)
Recommends: $KDIPN(>=$KV),linux-libc-dev(>=$KV)
# Suggests: <comma-separated list of packages>
# Provides: <comma-separated list of packages>
# Replaces: <comma-separated list of packages>
Architecture: armhf
Description: Turris Omnia up-to-date kernel metapackage.
 This metapackage points to the latest working kernel for the board.
EOF
equivs-build linux-kernel-omnia.cfg

