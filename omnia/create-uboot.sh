#!/bin/bash
#
# by Tomas Hlavacek (tmshlvck@gmail.com)
#
# prerequisities - Debian packages:
# git
# gcc-arm-linux-gnueabihf
#

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

cd turris-omnia-uboot
make turris_omnia_defconfig
make -j $(nproc)
echo "The resulting package is u-boot-spl.kwb"
echo "Installation hint:
usb start
load usb 0 0x1000000 u-boot-spl.kwb
sf probe 0 ; sf erase 0 0x100000 ; sf write 0x1000000 0 0x100000"
