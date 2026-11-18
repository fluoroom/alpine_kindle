#!/usr/bin/env bash
#
# Build a minimal Alpine Linux rootfs image for the Kindle.
#
# Populating the image means running ARM binaries on the x86 build host. That
# works either with a qemu-arm-static binary (copied into the image) or with a
# registered binfmt_misc handler (CI installs one with
# docker/setup-qemu-action). Both paths are supported here.

set -euo pipefail

REPO="http://dl-cdn.alpinelinux.org/alpine"
MOUNT_POINT="/mnt/alpine"
IMAGE="./alpine.ext4"
IMAGESIZE=2048 # Megabytes
ARCH="${1:-}"

# Ensure we are root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ -z "$ARCH" ]; then
  echo "Usage: $0 <architecture>"
  echo "<architecture> is any architecture that Alpine Linux supports"
  exit 1
fi

# Prefer the host binary when it exists (works when binfmt is unavailable),
# otherwise the chroot below relies on binfmt_misc emulation.
QEMU_STATIC=""
if command -v qemu-arm-static >/dev/null 2>&1; then
  QEMU_STATIC="$(command -v qemu-arm-static)"
  echo "Using host $QEMU_STATIC for the chroot."
else
  echo "No qemu-arm-static found; expecting a binfmt_misc handler for ARM."
fi

cleanup() {
  if mountpoint -q "$MOUNT_POINT"; then
    sync || true
    umount "$MOUNT_POINT" || true
  fi
  rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# Grab the prebuilt minirootfs
echo "Fetching Alpine edge release metadata for $ARCH..."
wget -q "$REPO/edge/releases/$ARCH/latest-releases.yaml" -O latest-releases.yaml
MINIROOTFS_FILE=$(grep "file: alpine-minirootfs-.*-$ARCH.tar.gz" latest-releases.yaml | awk '{print $2}' | head -n1)
if [ -z "$MINIROOTFS_FILE" ]; then
  echo "Could not find a minirootfs for architecture '$ARCH'" 1>&2
  exit 1
fi
echo "Downloading $MINIROOTFS_FILE..."
wget -q "$REPO/edge/releases/$ARCH/$MINIROOTFS_FILE" -O minirootfs.tar.gz

# Prepare the disk image
rm -f "$IMAGE"
dd if=/dev/zero of="$IMAGE" bs=1M count="$IMAGESIZE"
mkfs.ext4 -F "$IMAGE"
tune2fs -i 0 -c 0 -O ^has_journal "$IMAGE"

# Mount the image
mkdir -p "$MOUNT_POINT"
mount -o loop "$IMAGE" "$MOUNT_POINT"

# Extract the minirootfs
tar -xzf minirootfs.tar.gz -C "$MOUNT_POINT"

# Preconfig the image
printf 'kindle\n' > "$MOUNT_POINT/etc/hostname"
printf 'nameserver 1.1.1.1\n' > "$MOUNT_POINT/etc/resolv.conf"
mkdir -p "$MOUNT_POINT/run/dbus"
echo "Preconfig done."

# Copy the GUI installers
cp ./addons/base_gui_packages.sh "$MOUNT_POINT/usr/local/bin/base_gui_packages.sh"
chmod +x "$MOUNT_POINT/usr/local/bin/base_gui_packages.sh"
echo "Copied base GUI packages list to image."

cp ./addons/gui_install_xfce.sh "$MOUNT_POINT/usr/local/bin/gui_install_xfce"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_install_xfce"
echo "Copied XFCE installer to image."
cp ./addons/gui_xfce.sh "$MOUNT_POINT/usr/local/bin/gui_xfce"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_xfce"
echo "Copied XFCE gui script to image."

cp ./addons/gui_install_fluxbox.sh "$MOUNT_POINT/usr/local/bin/gui_install_fluxbox"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_install_fluxbox"
echo "Copied Fluxbox installer to image."
cp ./addons/gui_fluxbox.sh "$MOUNT_POINT/usr/local/bin/gui_fluxbox"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_fluxbox"
echo "Copied Fluxbox gui script to image."

cp ./addons/gui_installer.sh "$MOUNT_POINT/usr/local/bin/gui_installer"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_installer"
echo "Copied GUI installer script to image."

# Make ARM binaries runnable inside the chroot
if [ -n "$QEMU_STATIC" ]; then
  cp "$QEMU_STATIC" "$MOUNT_POINT/usr/bin/qemu-arm-static"
  echo "Copied qemu-arm-static to image."
else
  if ! chroot "$MOUNT_POINT" /bin/sh -c true; then
    echo "ARM emulation is not available: install qemu-arm-static or register a binfmt_misc handler." 1>&2
    exit 1
  fi
  echo "Verified binfmt_misc ARM emulation inside the chroot."
fi

# check if the customize_image.sh exists
if [ -f "./customize_image.sh" ]; then
  # Copy the customize script
  cp ./customize_image.sh "$MOUNT_POINT/root/customize_image.sh"
  chmod +x "$MOUNT_POINT/root/customize_image.sh"
  echo "Copied customize_image.sh to image."

  # Run the customize script
  echo "Starting customization inside chroot..."
  if [ -n "$QEMU_STATIC" ]; then
    chroot "$MOUNT_POINT" /usr/bin/qemu-arm-static /bin/sh /root/customize_image.sh
  else
    chroot "$MOUNT_POINT" /bin/sh /root/customize_image.sh
  fi
  echo "Customization done."

  rm -f "$MOUNT_POINT/root/customize_image.sh"
  echo "Removed customize_image.sh from image."
  if [ -n "$QEMU_STATIC" ]; then
    rm -f "$MOUNT_POINT/usr/bin/qemu-arm-static"
    echo "Removed qemu-arm-static from image."
  fi
fi

# Unmount the image
sync
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"
trap - EXIT

rm -f latest-releases.yaml minirootfs.tar.gz
echo "Image written to $IMAGE"
