#!/bin/bash
if [[ -f /data/valetudo ]]; then
	ip addr add 203.0.113.1 dev lo
	VALETUDO_CONFIG_PATH=/data/valetudo_config.json /data/valetudo >> /tmp/valetudo.log 2>&1 &
fi