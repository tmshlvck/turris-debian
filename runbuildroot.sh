#!/bin/bash

ROOT=/var/lib/turris-debian
MAINREPO="https://github.com/tmshlvck/turris-debian.git"

export ROOT
create_all () {
	sudo mkdir $ROOT
	sudo debootstrap buster $ROOT
	{
	cat <<EOF
#!/bin/bash
apt-get -y update
apt-get -y install debootstrap qemu-user qemu-user-static git devscripts u-boot-tools git libssl-dev libncurses-dev bison flex bc rsync

wget -O /opt/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz https://releases.linaro.org/components/toolchain/binaries/7.4-2019.02/arm-linux-gnueabihf/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz

wget -O /opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz https://releases.linaro.org/components/toolchain/binaries/7.4-2019.02/aarch64-linux-gnu/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz

	cd /opt
	tar xf /opt/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz
	rm /opt/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf.tar.xz
	tar xf /opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz
	rm /opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu.tar.xz

	echo 'PATH=$PATH:/opt/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu/bin:/opt/gcc-linaro-7.4.1-2019.02-x86_64_arm-linux-gnueabihf/bin' >>/root/.bashrc
EOF
	} | sudo tee $ROOT/root/init.sh

	sudo chmod a+x $ROOT/root/init.sh

	sudo cp /etc/resolv.conf $ROOT/etc
	sudo cp ~/.gitconfig $ROOT/root/
 	echo "turris-debian" | sudo tee $ROOT/etc/hostname
 	echo "pts/0" | sudo tee -a $ROOT/etc/securetty
	sudo systemd-nspawn -D $ROOT /root/init.sh
}

if [ ! -d $ROOT ]; then
	create_all
fi

sudo systemd-nspawn -D $ROOT --bind `pwd`:/tmp/turris-debian /bin/bash

