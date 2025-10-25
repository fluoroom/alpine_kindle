#!/bin/sh

MACHINE_ARCH=$(uname -m)

if [ "$MACHINE_ARCH" = "armv7l" ]; then
    IMAGE_ARCH="armhf"
else
    IMAGE_ARCH=$MACHINE_ARCH
fi

if [ -d /mnt/base-us/alpine ]; then
    echo "Alpine Linux appears to already exist."
    read -p "Press any key to continue..."
    exit 1
fi

cd /mnt/base-us
mkdir alpine
cd alpine

NIGHTLY_LINK="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs.yaml/pw6/alpine-rootfs-${IMAGE_ARCH}.zip"
curl -L -o "alpine.zip" "$NIGHTLY_LINK"

unzip alpine.zip
rm alpine.zip

echo "All done."
read -p "Press any key to continue..."