#!/bin/sh

rm /overlay/lib/modules/3.4.39/8189es.ko

rm /sbin/reboot

ln -s /bin/busybox /sbin/reboot
