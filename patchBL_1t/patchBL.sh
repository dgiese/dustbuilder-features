#!/bin/sh


set -e
trap '[ $? -eq 0 ] && exit 0 || print_error' EXIT

print_error() {
  echo "An error occurred during patchBL"
  echo "DO NOT REBOOT THE DEVICE. It might not boot again"

  exit 1
}

if [ ! -e "./patchBL.conf" ]; then
    echo "patchBL: Configuration file not found! Aborting"

    exit 1
fi

source ./patchBL.conf

if [ -z "$expected_uboot_version" ]; then
  echo "patchBL: Missing expected uboot version. Aborting for safety"
  exit 1
fi

if [ -z "$expected_boot_normal_cmd" ]; then
  echo "patchBL: Missing expected boot_normal cmd. Aborting for safety"
  exit 1
fi


current_uboot_version=$(cat /proc/cmdline | grep -o 'uboot_message=[^ ]*' | cut -d'=' -f2)
current_boot_normal_cmd=$(fw_printenv boot_normal)

if [ -z "$current_uboot_version" ]; then
  echo "patchBL: Unable to determine current uboot version. Aborting for safety"
  exit 1
fi

if ! echo "$current_boot_normal_cmd" | grep -q "$expected_boot_normal_cmd"; then
    echo "patchBL: boot_normal does not contain expected uboot patch"
    echo "patchBL: Adding uboot patch"

    fw_setenv boot_normal "$expected_boot_normal_cmd"
    fw_setenv boot_normal "$expected_boot_normal_cmd" #twice to also update env-redund
else
    echo "patchBL: boot_normal does contain the expected uboot patch"
fi

if ! [ "$current_uboot_version" == "$expected_uboot_version" ]; then
    echo "patchBL: Current uboot version does not match expected uboot version"

    echo "patchBL: Installing uboot version $expected_uboot_version"
    ota-burnuboot ./patchBL_toc1.img
else
    echo "patchBL: Current uboot version matches expected uboot version"
fi


