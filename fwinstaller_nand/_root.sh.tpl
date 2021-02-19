#!/bin/bash
if [[ -f /mnt/data/valetudo ]]; then
	ip addr add 203.0.113.1 dev lo
	VALETUDO_CONFIG_PATH=/mnt/data/valetudo_config.json /mnt/data/valetudo >> /tmp/valetudo.log 2>&1 &
fi

### It is strongly recommended that you put your changes inside the IF-statement above. In case your changes cause a problem, a factory reset will clean the data partition and disable your chances.
### Keep in mind that your robot model does not have a recovery partition. A bad script can brick your device!

