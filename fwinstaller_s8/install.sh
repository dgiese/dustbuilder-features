#!/bin/bash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2022 by Dennis Giese
#
# Intended to work on a27,a51,a70,a46
#
DEVICEMODEL="CHANGEDEVICEMODELCHANGE"

echo "---------------------------------------------------------------------------"
echo " Roborock manual Firmware installer"
echo " Copyright 2020 by Dennis Giese [dgiese at dontvacuum.me]"
echo " Intended to work on a27,a51,a70,a46"
echo " Version: ${DEVICEMODEL}"
echo " Use at your own risk"
echo "---------------------------------------------------------------------------"

grep -xq "^model=${DEVICEMODEL}$" /mnt/default/device.conf
if [ $? -eq 1 ]; then
	echo "(!!!) It seems you are trying to run the installer on a $(sed -rn 's/model=(.*)/\1/p' /mnt/default/device.conf) instead of ${DEVICEMODEL}."
	exit 1
fi
rr_boot -g > /tmp/rr_boot 2>&1
if grep -q "rootA" /tmp/rr_boot; then
		echo "We are currently on rootfs1, will installing on rootfs2"
		BOOT_PART=/dev/by-name/boot_b
		ROOT_FS_PART=/dev/by-name/system_b
		OPT_FS_PART=/dev/mapper/opt_b
		OPT_RAW=/dev/by-name/opt_b
		OPT_current=opt_a
		OPT_next=opt_b
elif grep -q "rootB" /tmp/rr_boot; then
		echo "We are currently on rootfs2, will installing on rootfs1"
		BOOT_PART=/dev/by-name/boot_a
		ROOT_FS_PART=/dev/by-name/system_a
		OPT_FS_PART=/dev/mapper/opt_a
		OPT_RAW=/dev/by-name/opt_a
		OPT_current=opt_b
		OPT_next=opt_a
else
		echo "(!!!) unsupported boot configuration!"
		exit 1
fi

echo "check image file size"
maximumsize=26000000
minimumsize=20000000
# maxsizeplaceholder
# minsizeplaceholder
actualsize=$(wc -c < /mnt/data/rootfs.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash. Aborting the installation"
	exit 1
fi
if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation. Aborting the installation"
	exit 1
fi

if [[ -f /mnt/data/boot.img ]]; then
	if [[ -f /mnt/data/rootfs.img ]]; then
		if [[ -f /mnt/data/opt.img ]]; then
			echo "Checking integrity"
			/mnt/data/busybox2 md5sum -c firmware.md5sum
			if [ $? -ne 0 ]; then
				echo "(!!!) integrity check failed. Firmware files are damaged. Please re-download the firmware. Aborting the installation"
				exit 1
			fi
			echo "decrypting opt partition"
			/mnt/data/dmsetup table --showkey /dev/mapper/${OPT_current} | /mnt/data/busybox2 awk '{print$5}' | /mnt/data/busybox2 xxd -r -p -c 32 > /tmp/opt_key
			cryptsetup luksOpen ${OPT_RAW} ${OPT_next} --master-key-file /tmp/opt_key	
			cryptsetup status ${OPT_next} > /tmp/cryptsetup_status
			
			grep -q "${OPT_FS_PART} is active" /tmp/cryptsetup_status
			if [ $? -eq 1 ]; then
				echo "(!!!) Decrypting OPT failed, will copy OPT partition!"
				dd if=/dev/by-name/${OPT_current} of=/dev/by-name/${OPT_next}
				echo "(!!!) Retrying mounting OPT"
				cryptsetup luksOpen ${OPT_RAW} ${OPT_next} --master-key-file /tmp/opt_key	
				cryptsetup status ${OPT_next} > /tmp/cryptsetup_status
				grep -q "${OPT_FS_PART} is active" /tmp/cryptsetup_status
				if [ $? -eq 1 ]; then
					echo "(!!!) Decrypting OPT failed again, bailing out!"
					exit 1
				fi
			fi
			
			echo "Start installation ..."
			echo "Installing Kernel"
			dd if=/mnt/data/boot.img of=${BOOT_PART} bs=8192
			echo "Installing OS"
			dd if=/mnt/data/rootfs.img of=${ROOT_FS_PART} bs=8192

			echo "Trying to mount system"
			mkdir /tmp/system
			mount ${ROOT_FS_PART} /tmp/system
			if [ ! -f /tmp/system/build.txt ]; then
				echo "(!!!) Did not found marker in updated firmware or mount the partition (maybe XZ compressed?). Will try alternative method"
				dd if=${ROOT_FS_PART} of=/tmp/checkrootfs.img bs=1M
				./unsquashfs -d /tmp/squashfs-root/ /tmp/checkrootfs.img /build.txt
				if [ ! -f /tmp/squashfs-root/build.txt ]; then
					echo "(!!!) Did not found marker in updated firmware. Update likely failed, wont update system_a."
					exit 1
				fi
				echo "looks good, proceeding"
			fi

			echo "Installing OPT"
			dd if=/mnt/data/opt.img of=${OPT_FS_PART} bs=8192

			echo "Trying to mount opt"
			mkdir /tmp/opt
			mount ${OPT_FS_PART} /tmp/opt
			if [ ! -f /tmp/opt/signature ]; then
				echo "(!!!) Did not found marker in OPT, bailing out!"
				exit 1
			fi

			echo "looks good, switching boot partition"
			if grep -q "rootA" /tmp/rr_boot; then
				rr_boot -L b
			elif grep -q "rootB" /tmp/rr_boot; then
				rr_boot -L a
			else
					echo "(!!!) unsupported boot configuration!"
					exit 1
			fi
			echo "cleaning up"
			rm /mnt/data/opt.img
			rm /mnt/data/rootfs.img
			rm /mnt/data/boot.img
			rm /mnt/data/unsquashfs
			rm /mnt/data/dmsetup
			rm /mnt/data/busybox2
			rm /mnt/data/firmware.md5sum
			echo "----------------------------------------------------------------------------------"
			echo "Done, please reboot and check if the robot boots the new firmware"
			echo "Repeat installion after rebooting, if everything works"
			echo "Dont forget to delete the installer files after rebooting"
			echo "If you did not activate valetudo yet, you need to do this steps:"
			echo "copy valetudo binary to /mnt/data/valetudo (eg. via scp)"
			echo "chmod +x /mnt/data/valetudo"
			echo "cp /root/_root.sh.tpl /mnt/reserve/_root.sh"
			echo "chmod +x /mnt/reserve/_root.sh"
			echo "----------------------------------------------------------------------------------"
		else
			echo "(!!!) opt.img not found in /mnt/data"
		fi	
	else
		echo "(!!!) rootfs.img not found in /mnt/data"
	fi
else
	echo "(!!!) boot.img not found in /mnt/data"
fi
