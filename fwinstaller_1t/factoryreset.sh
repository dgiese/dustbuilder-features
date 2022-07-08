#!/bin/ash
# Author: Dennis Giese [dgiese at dontvacuum.me]
# Copyright 2020 by Dennis Giese
#
# Intended to work on mc1808,p2008,p2009,p2041
#
cp /data/_root_postboot.sh /tmp/_root_postboot.sh
cp /data/valetudo /tmp/valetudo

killall ava
rm -rf /data/*
tar xjf /misc/data.tar.bz2 -C /data/

cp /tmp/_root_postboot.sh /data/_root_postboot.sh
cp /tmp/valetudo /data/valetudo
chmod +x /data/_root_postboot.sh
chmod +x /data/valetudo
reboot