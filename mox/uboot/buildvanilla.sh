#!/bin/bash

R=`pwd`

cd mox-u-boot
make clean
make turris_mox_defconfig
CROSS_COMPILE=aarch64-linux-gnu- make -j8
cd ..

cd atf-marvell
rm -rf build
make \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_CM3=arm-linux-gnueabihf- \
BL33=../mox-u-boot/u-boot.bin \
DEBUG=0 \
LOG_LEVEL=0 \
USE_COHERENT_MEM=0 \
DDR_TOPOLOGY=0 \
CLOCKSPRESET=CPU_1000_DDR_800 \
PLAT=a3700 \
WTP=../A3700-utils-marvell \
WTMI_IMG=../A3700-utils-marvell/wtmi/build/wtmi.bin \
all fip


cd build/a3700/release/uart-images
#$R/A3700-utils-marvell/wtptp/linux/WtpDownload_linux -V -P UART -C 0 -R 115200 -B TIM_ATF.bin -I boot-image_h.bin -I wtmi_h.bin -E
