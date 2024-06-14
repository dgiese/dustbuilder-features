#!/bin/bash -x
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
# loudspeakerservice.json needs to stay intact for sound to work on the l10spuh
rm $IMG_DIR/ava/conf/video_monitor/cedar* $IMG_DIR/ava/conf/video_monitor/recorder* $IMG_DIR/ava/conf/video_monitor/video_* $IMG_DIR/ava/conf/video_monitor/microphone*

sed -i "/\/etc\/rc.d\/create_agora_cert.sh/d" $IMG_DIR/etc/rc.sysinit
sed -i "/\/etc\/rc.d\/monitor_video_streamer.sh/d" $IMG_DIR/etc/rc.sysinit
sed -i "/video_monitor/d" $IMG_DIR/etc/rc.d/ava.sh


rm -r $IMG_DIR/bdspeech
rm -r $IMG_DIR/speech
rm $IMG_DIR/usr/bin/speech_switch_type.sh
rm $IMG_DIR/usr/bin/reboot_monitor_bdspeech.sh
echo -e "#!/bin/sh\nexit 0" > $IMG_DIR/usr/bin/speech_monitor.sh

sed -i "/\/usr\/bin\/speech_switch_type.sh/d" $IMG_DIR/etc/rc.sysinit
sed -i 's/\(.*MIC.*\) [0-9]*/\1 0/g' $IMG_DIR/etc/init.d/audio.sh


ava_confs=("$IMG_DIR/ava/conf"/r*.conf)
if [ ${#ava_confs[@]} -gt 0 ]; then
	ava_conf_filename="${ava_confs[0]}"

	mv "$ava_conf_filename" "$ava_conf_filename.bak"
	jq 'del(.nodes[] | select(.ID == "AvaNodeImpfileUpload"))' "$ava_conf_filename.bak" > $ava_conf_filename
        rm "$ava_conf_filename.bak"
fi
sed -i 's/"upload_flag": true/"upload_flag": false/g' $IMG_DIR/ava/conf/bduploadfreq.json
