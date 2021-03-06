#!/bin/sh
source /usr/bin/config
mkdir /tmp/.ssh

if [  ! -f /mnt/misc/authorized_keys ]; then
    cp /authorized_keys /mnt/misc/authorized_keys
fi
cp /mnt/misc/authorized_keys /tmp/.ssh/

# check if password login for ssh should be disabled
if [ -f /mnt/misc/ssh_disable_passwords ]; then
    dropbear -s &
else
    dropbear &
fi

