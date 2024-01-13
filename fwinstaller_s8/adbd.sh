#!/bin/sh
[ -d /sys/kernel/config/usb_gadget ] || {
	mount -t configfs none /sys/kernel/config
	mkdir /sys/kernel/config/usb_gadget/g1
	echo "0x18d1" > /sys/kernel/config/usb_gadget/g1/idVendor
	echo "0xD002" > /sys/kernel/config/usb_gadget/g1/idProduct
	mkdir /sys/kernel/config/usb_gadget/g1/strings/0x409
	echo "Allwinner" > /sys/kernel/config/usb_gadget/g1/strings/0x409/manufacturer
	echo "Tina" > /sys/kernel/config/usb_gadget/g1/strings/0x409/product
}
[ -d /sys/kernel/config/usb_gadget/g1/configs/c.1 ] || {
	mkdir /sys/kernel/config/usb_gadget/g1/configs/c.1
	echo 0xc0 > /sys/kernel/config/usb_gadget/g1/configs/c.1/bmAttributes
	echo 500 > /sys/kernel/config/usb_gadget/g1/configs/c.1/MaxPower
	mkdir /sys/kernel/config/usb_gadget/g1/configs/c.1/strings/0x409
}
[ -d /sys/kernel/config/usb_gadget/g1/functions/ffs.adb ] || {
	mkdir /sys/kernel/config/usb_gadget/g1/functions/ffs.adb
}
[ -e /sys/kernel/config/usb_gadget/g1/configs/c.1/ffs.adb ] || {
	ln -s /sys/kernel/config/usb_gadget/g1/functions/ffs.adb/ /sys/kernel/config/usb_gadget/g1/configs/c.1/ffs.adb
}
[ -d /dev/usb-ffs/adb ] || {
	mkdir /dev/usb-ffs
	mkdir /dev/usb-ffs/adb
	mount -o uid=2000,gid=2000 -t functionfs adb /dev/usb-ffs/adb/
}

for i in `seq 20`
do
	opt_mounted=`cat /proc/mounts | grep -c opt/rockrobo`
	data_mounted=`cat /proc/mounts | grep -c mnt/data`
	if [ $opt_mounted -eq 1 -a $data_mounted -eq 1 ]; then
		echo "opt, data part mounted..." > /dev/kmsg
		sleep 1
		break
	fi
	sleep 1
	echo "adbd wait for opt data part mount $i..." > /dev/kmsg
done

source /etc/profile
while true ; do
	mkdir -p /mnt/data/rockrobo/rrlog
	ls /sys/class/sunxi_dump/write > /tmp/adb_file
	#Improve sensitivity and drive capability
	echo 0x05100418 0x02043fe7 > /sys/class/sunxi_dump/write
	#echo 0x05100418 0x02743fe7 > /sys/class/sunxi_dump/write
	/sbin/adbd 2>&1
done
