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

KERNELREPO="https://github.com/tmshlvck/omnia-linux.git"
REMOTE="github"
#KERNELBRANCH="omnia"
KERNELBRANCH="omnia-upstream"


export ARCH=arm
export CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf-

if [ -d linux ]; then
  cd linux
  git checkout $KERNELBRANCH
  git pull github $KERNELBRANCH
  make distclean
else
  git clone -o $REMOTE $KERNELREPO linux
  cd linux
  git checkout $KERNELBRANCH
  make distclean
fi

make omnia_defconfig

export DEB_HOST_ARCH=armhf
export CONCURRENCY_LEVEL=`grep -m1 cpu\ cores /proc/cpuinfo | cut -d : -f 2`

make-kpkg --rootcmd fakeroot --arch arm --cross-compile arm-linux-gnueabihf- --revision=1.0 kernel_image kernel_headers
