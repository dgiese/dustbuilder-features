#!/bin/ash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#

echo "---------------------------------------------------------------------------"
echo " Viomi manual Firmware installer"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on v7"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

if [ -f /tmp/rootfs.img ]; then
	echo "check image file size"

	maximumsize=26000000
	minimumsize=20000000
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
			echo "After the reboot, you will have to reconfigure your Wi-Fi credentials"
			cp /bin/busybox /tmp/
			
			if [[ -f /boot/uImage_verity ]]; then
				echo "Verity device, need to patch boot"
				umount /boot
				/tmp/busybox dd if=/tmp/boot.img of=/dev/by-name/boot
				mount -o rw /dev/by-name/boot /boot
				mv /boot/uImage /boot/uImage_verity
			else
				umount /boot
				/tmp/busybox dd if=/tmp/boot.img of=/dev/by-name/boot
			fi

			rm -rf /overlay/*
			/tmp/busybox dd if=/tmp/rootfs.img of=/dev/by-name/rootfs

			/tmp/busybox sync
			/tmp/busybox reboot

			echo "Install finished. Rebooting..."
			echo "!!! Don't forget to unplug the Micro USB cable to allow it to reboot !!!"
		else
			echo "(!!!) rootfs.img not found"
		fi
	else
		echo "(!!!) boot.img not found"
	fi
else
	echo "We are not in /tmp. Aborting"
fi
