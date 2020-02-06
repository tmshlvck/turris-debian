#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - install packages:
# apt-get install git devscripts kernel-package libssl-dev libncurses-dev equivs
#
# Linaro GCC 7.3 & toolchain in /opt
#

#KERNELREPO="https://github.com/tmshlvck/omnia-linux.git"
##KERNELBRANCH="omnia"
#KERNELBRANCH="master-omnia"


export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

cd kernel

if [ -f linux/.config ] && [ -f linux/arch/arm64/configs/mox_defconfig ]; then
	if ! diff ../files/mox_defconfig linux/.config >/dev/null; then
		echo "The config in Kernel tree differs from files/mox_defconfig. Copy it or remove it:"
		echo "  ---->   cp kernel/linux/.config files/mox_defconfig"
		echo "  ---->   rm kernel/linux/.config"
		exit 0
	fi
fi
cp ../files/mox_defconfig linux/arch/arm64/configs
cd linux
make mox_defconfig

export DEB_HOST_ARCH=arm64

TOOLCHAINDIR=`dirname $(which ${CROSS_COMPILE}gcc)`
CROSS_PREFIX="${TOOLCHAINDIR}/${CROSS_COMPILE}"

make -j $(nproc) deb-pkg LOCALVERSION=-mox

# crete meta-package
cd ..

KIP=`ls linux-image-*_arm64.deb | grep -v -- "-dbg_" | ../../sortkernel.py | tail -n1`
HIP=`ls linux-headers-*_arm64.deb | ../../sortkernel.py | tail -n1`
KDIP=`ls linux-image-*-dbg_*_arm64.deb | ../../sortkernel.py | tail -n1`

if ! [ -f $KIP ]; then
	        echo "Missing file $KIP . Exit."
		exit -1
fi

KIPN=`echo $KIP | awk -F'_' '{print $1}'`
HIPN=`echo $HIP | awk -F'_' '{print $1}'`
KDIPN=`echo $KDIP | awk -F'_' '{print $1}'`
KV=`echo $KIP | awk -F'_' '{print $2}'`

#equivs-control linux-kernel-mox.cfg
cat > linux-kernel-mox.cfg <<EOF
# Source: <source package name; defaults to package name>
Section: misc
Priority: optional
Homepage: https://github.com/tmshlvck/turris-debian
Standards-Version: 3.9.2

Package: linux-kernel-mox
Version: $KV
Maintainer: Tomas Hlavacek <tmshlvck@gmail.com>
Depends: $KIPN(>=$KV),$HIPN(>=$KV)
Recommends: $KDIPN(>=$KV),linux-libc-dev(>=$KV)
# Suggests: <comma-separated list of packages>
# Provides: <comma-separated list of packages>
# Replaces: <comma-separated list of packages>
Architecture: arm64
Description: Turris MOX up-to-date kernel metapackage.
 This metapackage points to the latest working kernel for the board.
EOF
equivs-build linux-kernel-mox.cfg

