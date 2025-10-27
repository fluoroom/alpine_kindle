#!/bin/sh
read -p "Are you sure you want to delete the ROOT filesystem for Alpine Linux? This action cannot be undone. (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] ; then
    echo "Deletion cancelled."
    exit 0
fi

if [ "$(mount | grep /tmp/alpine)" ] ; then
    echo "ATTENTION! Alpine's rootfs is still mounted."
    echo "Please unmount it (Stop from KUAL) before deleting."
    exit 1
fi
if [ -f /mnt/us/alpine/alpine.ext4 ]; then
    echo "Deleting /mnt/us/alpine/alpine.ext4"
    rm /mnt/us/alpine/alpine.ext4
fi

if [ -f /mnt/us/alpine/alpine.sh ]; then
    echo "Deleting /mnt/us/alpine/alpine.sh"
    rm /mnt/us/alpine/alpine.sh
fi

if [ -f /mnt/us/alpine/alpine.conf ]; then
    echo "Deleting /mnt/us/alpine/alpine.conf"
    rm /mnt/us/alpine/alpine.conf
fi

read -p "Alpine Linux Root has been deleted. Press any key to continue..."