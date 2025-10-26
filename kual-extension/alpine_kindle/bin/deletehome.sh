#!/bin/sh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if [ "$(mount | grep /tmp/alpine)" ] ; then
    echo "ATTENTION! Alpine's rootfs is still mounted."
    echo "Please unmount it (by stopping from Kual menu or running $SCRIPT_DIR/stop.sh)"
    exit 1
fi
if [ -f /mnt/us/alpine/home.ext4 ]; then
    echo "Deleting /mnt/us/alpine/home.ext4"
    rm /mnt/us/alpine/home.ext4
fi
if [ -f /mnt/us/alpine/home.ext3 ]; then
    echo "Deleting /mnt/us/alpine/home.ext3"
    rm /mnt/us/alpine/home.ext3
fi

read -p "Alpine Linux HOME has been deleted. Press any key to continue..."