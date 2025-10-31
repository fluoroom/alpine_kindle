#/usr/bin/env bash

# Ensure we are root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

REPO="http://dl-cdn.alpinelinux.org/alpine"
MOUNT_POINT="/mnt/alpine"
IMAGE="./alpine.ext4"
IMAGESIZE=2048 # Megabytes


if [ -n "$1" ]; then
  ARCH="$1"
else
  echo "Usage: $0 <architecture>"
  echo "<architecture> is any architecture that Alpine Linux supports"
  exit 1
fi

# Grab the prebuilt minirootfs
wget "$REPO/edge/releases/$ARCH/latest-releases.yaml"
MINIROOTFS_FILE=$(grep "file: alpine-minirootfs-.*-$ARCH.tar.gz" latest-releases.yaml | awk '{print $2}')
wget "$REPO/edge/releases/$ARCH/$MINIROOTFS_FILE" -O minirootfs.tar.gz

# Prepare the disk image
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMAGESIZE"
mkfs.ext4 -F "$IMAGE"
tune2fs -i 0 -c 0 -O ^has_journal "$IMAGE"

# Mount the image
mkdir -p "$MOUNT_POINT"
mount -o loop "$IMAGE" "$MOUNT_POINT"

# Extract the minirootfs
tar -xzvf minirootfs.tar.gz -C "$MOUNT_POINT"

# Preconfig the image
echo "kindle" > "$MOUNT_POINT/etc/hostname"
echo "nameserver 1.1.1.1" > "$MOUNT_POINT/etc/resolv.conf"
mkdir ${MOUNT_POINT}/run/dbus
echo "Preconfig done."

#Copy the GUI installers
cp ./addons/base_gui_packages.sh "$MOUNT_POINT/usr/local/bin/base_gui_packages.sh"
chmod +x "$MOUNT_POINT/usr/local/bin/base_gui_packages.sh"
echo "Copied base GUI packages list to image."

cp ./addons/gui_install_lxqt.sh "$MOUNT_POINT/usr/local/bin/gui_install_lxqt"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_install_lxqt"
echo "Copied LXQt installer to image."

cp ./addons/gui_install_xfce.sh "$MOUNT_POINT/usr/local/bin/gui_install_xfce"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_install_xfce"
echo "Copied XFCE installer to image."

cp ./addons/gui_install_mate.sh "$MOUNT_POINT/usr/local/bin/gui_install_mate"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_install_mate"
echo "Copied MATE installer to image."

cp  ./addons/gui_installer.sh "$MOUNT_POINT/usr/local/bin/gui_installer"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_installer"
echo "Copied GUI installer script to image."

# Copy qemu-[arch] binaries
  cp $(which qemu-arm-static) "$MOUNT_POINT/usr/bin/"
  echo "Copied qemu-arm-static to image."




# check if the customize_image.sh exists
if [ -f "./customize_image.sh" ]; then
  # Copy the customize script
  cp ./customize_image.sh "$MOUNT_POINT/root/customize_image.sh"
  chmod +x "$MOUNT_POINT/root/customize_image.sh"
  echo "Copied customize_image.sh to image."

  # Run the customize script
  echo "Starting customization inside chroot..."
  chroot "$MOUNT_POINT" /usr/bin/qemu-arm-static /bin/sh /root/customize_image.sh
  echo "Customization done."

  rm "$MOUNT_POINT/root/customize_image.sh"
  echo "Removed customize_image.sh from image."
  rm "$MOUNT_POINT/usr/bin/qemu-arm-static"
  echo "Removed qemu-arm-static from image."
fi


# Unmount the image
sync
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT"
