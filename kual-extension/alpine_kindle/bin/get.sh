#!/bin/sh

if [ $1 = "--nightly" ]; then
    NIGHTLY=true
else
    NIGHTLY=false
fi

if [ "$NIGHTLY" = true ]; then
    read -p "This will download and install the latest NIGHTLY build of Alpine Linux for Kindle. Continue? (y/N): " CONFIRM
else
    read -p "This will download and install the latest RELEASE build of Alpine Linux for Kindle. Continue? (y/N): " CONFIRM
fi

if [ "$CONFIRM" != "y" ] ; then
    echo "Installation cancelled."
    exit 0
fi

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

if [ "$NIGHTLY" = true ]; then
    echo "Downloading latest NIGHTLY build..."
    NIGHTLY_LINK="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs-nightly.yaml/pw6/alpine-rootfs-nightly-${IMAGE_ARCH}.zip"
else        
    echo "Downloading latest RELEASE build..."
    RELEASE_LINK="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs.yaml/pw6/alpine-rootfs-${IMAGE_ARCH}.zip"
fi

curl -L -o "alpine.zip" "$RELEASE_LINK"

echo "Unzipping Alpine Linux files..."
unzip alpine.zip
rm alpine.zip

mntroot rw
echo "Copying alpine.conf to /etc/upstart/"
cp alpine.conf /etc/upstart/
mntroot r

echo "All done."
read -p "Press any key to continue..."
