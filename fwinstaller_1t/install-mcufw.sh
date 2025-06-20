#!/bin/ash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on dreame devices
#

if [[ -f /mcu.bin ]]; then
	mkdir -p /tmp/update
	cp /mcu.bin /tmp/update
	if [[ -f /UI.bin ]]; then
		cp /UI.bin /tmp/update/
	fi
	if [[ -f /UIMA.bin ]]; then
		cp /UI*.bin /tmp/update/
	fi
	echo 1 > /tmp/update/only_update_mcu_mark

        /etc/rc.d/ava.sh "ota"
        sleep 5

	avacmd ota  '{"type": "ota", "cmd": "report_upgrade_status", "status": "AVA_UNPACK_OK", "result": "ok"}'
else
	echo "(!!!) mcu.bin not found"
fi
