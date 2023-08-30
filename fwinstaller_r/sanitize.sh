#!/bin/bash
echo "sanitizing R model"
if [ -z "$IMG_DIR" ]
then
     echo "no IMG_DIR set, exiting"
     exit 1
fi
echo "IMG_DIR: ${IMG_DIR}"
echo "Path: $(pwd)"
rm $IMG_DIR/etc/OTA_Key_pub.pem
rm $IMG_DIR/etc/adb_keys
rm $IMG_DIR/etc/publickey.pem
rm $IMG_DIR/usr/bin/autossh.sh
rm $IMG_DIR/usr/bin/backup_key.sh
rm $IMG_DIR/usr/bin/curl_download.sh
rm $IMG_DIR/usr/bin/curl_upload.sh
rm $IMG_DIR/usr/bin/packlog.sh
rm $IMG_DIR/usr/bin/mount_partition.sh
echo "" > $IMG_DIR/etc/mdev.conf
sed -i "s/dibEPK917k/Gi29djChze/" $IMG_DIR/etc/*

rm $IMG_DIR/etc/rc.d/create_agora_cert.sh
rm $IMG_DIR/etc/rc.d/video_streamer.sh
rm $IMG_DIR/etc/rc.d/monitor_video_streamer.sh
rm $IMG_DIR/usr/bin/license_activator
rm $IMG_DIR/usr/bin/video_monitor
rm -r $IMG_DIR/ava/conf/video_monitor

sed -i "/\/etc\/rc.d\/create_agora_cert.sh/d" $IMG_DIR/etc/rc.sysinit
sed -i "/\/etc\/rc.d\/monitor_video_streamer.sh/d" $IMG_DIR/etc/rc.sysinit
sed -i "/video_monitor/d" $IMG_DIR/etc/rc.d/ava.sh


