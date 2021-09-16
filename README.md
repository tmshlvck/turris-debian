# turris-debian

Scripts that compile Debian image for Turris Omnia
and MOX boards / routers by CZ.NIC, z.s.p.o.
(https://www.turris.cz/en/).

Dependencies:

 * Vagrant
 * working Vagrant VM provider - Libvirt+KVM or VirtualBox

The scripts need space (~4 GB) and take some time to
complete - downloading and installing the Debian packages
by `debootstrap`.

## Images and usage

You can download ready-made images for **Turris Omnia**:

* Debian Bullseye for Turris Omnia: https://krtek.taaa.eu/~th/omnia-images/bullseye/
* (oldstable) Debian Buster for Turris Omnia: https://krtek.taaa.eu/~th/omnia-images/buster/

And the images for **Turris MOX** are here:

* Debian Bullseye for Turris MOX: https://krtek.taaa.eu/~th/mox-images/bullseye/
* (oldstable) Debian Buster for Turris MOX: https://krtek.taaa.eu/~th/mox-images/buster/

### Turris Omnia Installation

To install the image on the Omnia board instead of default TurrisOS / OpenWRT distro
just put created or donwloaded file `omnia-medkit-<date>.tar.gz` to a root of
an ext2/3/4 filesystem on the USB flash drive (other contents of the flash does not matter).
Then put the USB drive to Omnia and go to the reflash mode (hold reset button untill
4 LEDs are on) and then wait until the installation finishes. The board goes through MMC
reflash procedure that takes usually 3-5 minutes. The progress is indicated by the LEDs -
first all LEDs turn green to indicate the last chance to stop the reflash by reseting.
Then the LEDs turn red - from that point on the eMMC is erased and if you restart the board
there would not be a usable operating system, so you would need to do the reflash procedure
again to get a working system.

When installation finishes the board restarts, LEDs turn white and resume their normal
indication functions.

After installation the root password is set to "turris" and by default the LAN interfaces
are connected to a virtual bridge that has IP address 192.168.1.1/24. Please note: There
is no DHCP server running by default and the WAN interface (SFP and Ethernet) is turned
off after installation. You need to connect your computer to one of the Turris Omnia ports
and run the following to get to the Omnia SSH console (assuming your interface on the workstation
is `eth0`:

```
ip link set up dev eth0
ip addr add 192.168.1.20/24 dev eth0
ssh root@192.168.1.1
```
And then enter password: `turris`.

Please note:

* There the project Wiki: https://github.com/tmshlvck/turris-debian/wiki

* The Buster image uses a custom kernel which is distributed in a new board/image specific repo: http://krtek.taaa.eu/~th/omnia/ The definition and the trusted key is added to the new (02/2020) images. But you might need to add it to older image manually along with installing the kernel metapackage linux-kernel-omnia.

* The Bullseye images do not need any custom kernel and the abovementioned repo is therefore not addded to the images and will be eventually decomissioned.

* The Buster images can boot with old Omnia bootloader - U-Boot version <2019. New bootloaders that can
use bootscript `/boot/boot.scr` is supported in newer images (starting at 02/2020).

* The Bullseye images do not support booting with old bootlader. Please update U-Boot to the latest version if you want to use this medkit image. For flashing procedure refer to next section.

### Turris Omnia U-Boot update / reflash

Warning: This is an advanced topic. You may get into troubles if the U-Boot or rescue image
flashing procedure fails. However, there is not a dange of hard-bricking the device. You can
always boot the Omnia board over serial port, even if the U-Boot in SPI flash is damaged. Extra
tools needed for that are screwdrivers (for opening the enclosure) and a 3.3V USB to UART converter.

Refer to the Turris docs for the method and detailed bootloader flashig procedure:
https://docs.turris.cz/hw/omnia/serial-boot/

Short version - I used this method for re-flashing both U-Boot and rescue image:
```
wget https://repo.turris.cz/hbl/omnia/packages/turrispackages/omnia-uboot_2019-07.1-1_arm_cortex-a9_vfpv3-d16.ipk
tar xf omnia-uboot_2019-07.1-1_arm_cortex-a9_vfpv3-d16.ipk
tar xf data.tar.gz

wget https://repo.turris.cz/hbl/omnia/packages/turrispackages/rescue-image_3.6.1-1_arm_cortex-a9_vfpv3-d16.ipk
tar xf rescue-image_3.6.1-1_arm_cortex-a9_vfpv3-d16.ipk
tar xf data.tar.gz

flash_erase /dev/mtd1 0 0
nandwrite -p /dev/mtd1 usr/share/rescue-image/image.fit.lzma

flash_erase /dev/mtd0 0 0
nandwrite -p /dev/mtd0 usr/share/omnia/uboot-devel
```


## Turris MOX install

Created or downloaded file `mox-sdimg-<date>.tar.gz` has to be extracted and its contents copied to a newly formated SD card with either ext2/3/4 or btrfs. The extraction should be executed as root.

After unmounting the SD card it can be plugged into MOX and used as the boot disk.
  
Root password is "turris".

SD creation method (assuming that the SD card is accessible as /dev/mmcblk0):
```
# fdisk /dev/mmcblk0
```
With fdisk create partition table or delete all existing partitions and create one new 'Linux' partition over the entire disk as partition 1.

```
# mkfs.btrfs /dev/mmcblk0p1
# cd /tmp
# wget https://krtek.taaa.eu/~th/mox-images/mox-sdimg-20200130.tar.gz
# mount /dev/mmcblk0p1 /mnt
# cd /mnt
# tar xf /tmp/mox-sdimg-20200130.tar.gz
# cd /tmp
# rm /tmp/mox-sdimg-20200130.tar.gz
# umount /mnt
# sync
```

## Vagrant VM preparation

Clone this repositiry by
```
$ git clone https://github.com/tmshlvck/turris-debian
```

then launch the Vagrant VM and connect to the VM:
```
$ cd turris-debian
$ vagrant up
$ vagrant ssh
```

Inside the Vagrant VM there is the cloned repo directory mounted to
`/turris-debian`.

Just become root and go the the repo directory:

```
vagrant@debian10:~$ sudo su -
root@debian10:~# cd /turris-debian/
```

Now you are ready to create your own Turris Omnia image:

```
root@debian10:~# cd /turris-debian/omnia
./create-medkit.sh
```

After the script finishes the resulting image and the checksum files:
`omnia-medkit-<date>.tar.gz` and `omnia-medkit-<date>.tar.gz.md5` will be in the
same directory. This directory and therefore the images are accessible from the
physical host when you leave and shutdown the vagrant box (`vagrant halt`).

