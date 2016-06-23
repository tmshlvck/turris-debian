#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# git
# gcc-arm-linux-gnueabihf
# devscrips
#

KERNELREPO="https://github.com/tmshlvck/omnia-linux.git"
KERNELBRANCH="omnia"

if [ -d linux ]; then
  rm -rf linux
fi

git clone $KERNELREPO linux
cd linux
git checkout $KERNELBRANCH

export ARCH=arm; export CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf-
make omnia_defconfig
make -j5
make modules -j5
make deb-pkg -j5

