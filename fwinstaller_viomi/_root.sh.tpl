#!/bin/sh

if [[ -f /mnt/UDISK/valetudo ]]; then
        VALETUDO_CONFIG_PATH=/mnt/UDISK/valetudo_config.json /mnt/UDISK/valetudo > /dev/null 2>&1 &
fi
