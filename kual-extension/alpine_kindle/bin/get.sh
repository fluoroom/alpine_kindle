#!/bin/sh

MACHINE_ARCH=$(uname -m)

if [ "$MACHINE_ARCH" = "armv7l" ]; then
    IMAGE_ARCH="armhf"
else
    IMAGE_ARCH=$MACHINE_ARCH
fi

if [ -f /mnt/us/alpine/alpine.ext4 ] || [ -f /mnt/us/alpine/alpine.sh ] || [ -f /mnt/us/alpine/alpine.conf ]; then
    echo "Alpine Linux appears to already exist."
    read -p "Press any key to continue..."
    exit 1
fi

cd /mnt/us
mkdir -p alpine
cd alpine

NIGHTLY_LINK="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs.yaml/pw6/alpine-rootfs-${IMAGE_ARCH}.zip"
curl -L -o "alpine.zip" "$NIGHTLY_LINK"

unzip alpine.zip
rm alpine.zip

mntroot rw
echo "Copying alpine.conf to /etc/upstart/"
cp alpine.conf /etc/upstart/
mntroot r

echo "All done."
read -p "Press any key to continue..."