#!/bin/sh

cp /opt/8821cs/8821cs_patched.ko /lib/modules/3.4.39/8189es.ko

rm /sbin/reboot

echo "#!/bin/sh" > /sbin/reboot
echo "rmmod 8189es 2>&1 > /dev/null" >> /sbin/reboot
echo "/bin/busybox reboot" >> /sbin/reboot

chmod +x /sbin/reboot
