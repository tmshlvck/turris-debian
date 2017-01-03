FROM ubuntu
RUN apt-get update && apt-get -y install build-essential \
debootstrap \
qemu-user \
qemu-user-static \
git \
gcc-arm-linux-gnueabihf \
devscripts \
kernel-package \
binfmt-support \
qemu-user-binfmt \
libssl-dev

WORKDIR /root/omnia-debian
ENTRYPOINT /bin/bash

