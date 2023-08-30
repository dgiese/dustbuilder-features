#!/bin/ash -e 
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on p2114,r2216,r2228,r2250
#
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Dreame manual Firmware installer"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on p2114,r2216,r2228,r2240,r2250"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

grep "model=${DEVICEMODEL}" /data/config/miio/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) It seems you are trying to run the installer on a $(sed -rn 's/model=(.*)/\1/p' /data/config/miio/device.conf) instead of ${DEVICEMODEL}."
	echo "(!!!) Aborting installation. DO NOT TRY to modify the installer to install the firmware anyway. You will likely brick your device!"
	exit 1
fi

if [[ ! "$PWD" == /tmp ]]; then
	echo "wrong directory. script must run in /tmp directory."
	exit 1
fi

echo "current firmware:"
cat /etc/os-release
echo "check image file size"
maximumsize=60000000
minimumsize=20000000
# maxsizeplaceholder
# minsizeplaceholder
actualsize=$(wc -c < /tmp/rootfs.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash. Aborting the installation"
	exit 1
fi
if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation. Aborting the installation"
	exit 1
fi

if [[ -f /tmp/boot.img ]]; then
	if [[ -f /tmp/rootfs.img ]]; then
		echo "Checking integrity"
		md5sum -c firmware.md5sum
		if [ $? -ne 0 ]; then
			echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
			exit 1
		fi

		echo "Start installation ... the robot will automatically reboot after the installation is complete"

		echo "Will install on rootfs1"
		BOOT_PART=/dev/by-name/boot1
		BOOT2_PART=/dev/by-name/boot2
		ROOT_FS_PART=/dev/by-name/rootfs1
		BOOT_PARTITION=boot1
		ROOT_PARTITION=rootfs1

		echo "Preparing"
		cp /bin/busybox /tmp/
		chmod +x /tmp/busybox
		if [[ ! -f /tmp/busybox ]]; then
			echo "(!!!) Busybox binary missing. Aborting the installation"
			exit 1
		fi
		/tmp/busybox sync
		/tmp/busybox sleep 1
		/tmp/busybox echo "s" > /proc/sysrq-trigger
		/tmp/busybox sleep 3
		/tmp/busybox echo "u" > /proc/sysrq-trigger
		/tmp/busybox sleep 3

		echo "Installing Kernel"
		/tmp/busybox dd if=/tmp/boot.img of=${BOOT_PART} bs=8192
		/tmp/busybox dd if=/tmp/boot.img of=${BOOT2_PART} bs=8192
		echo "Installing OS"
		/tmp/busybox dd if=/tmp/rootfs.img of=${ROOT_FS_PART} bs=8192
		/tmp/busybox sleep 5
		/tmp/busybox sync
		/tmp/busybox sleep 10
		/tmp/busybox echo "b" > /proc/sysrq-trigger

	else
		echo "(!!!) rootfs.img not found"
	fi
else
	echo "(!!!) boot.img not found"
fi
