#!/bin/sh

# Determine the correct Alpine image file to use
ALPINE_IMAGE=""
if [ -f "/mnt/us/alpine.ext4" ]; then
	ALPINE_IMAGE="/mnt/us/alpine.ext4"
elif [ -f "/mnt/us/alpine.ext3" ]; then
	ALPINE_IMAGE="/mnt/us/alpine.ext3"
elif [ -f "/mnt/base-us/alpine/alpine.ext4" ]; then
	ALPINE_IMAGE="/mnt/base-us/alpine/alpine.ext4"
else
	echo "ERROR: Alpine image file not found!"
	echo "Looked for:"
	echo "  /mnt/us/alpine.ext4"
	echo "  /mnt/us/alpine.ext3"
	echo "  /mnt/base-us/alpine/alpine.ext4"
	echo "Please ensure the Alpine image is properly installed."
	exit 1
fi

echo "Using Alpine image: $ALPINE_IMAGE"

ALREADYMOUNTED="no"
if [ "$(mount | grep /tmp/alpine)" ] ; then
	ALREADYMOUNTED="yes"
	echo "ATTENTION! Alpine's rootfs is already mounted, thus you will be just dropped into it."
	echo "BE CAREFUL to leave this shell first, as there will be no umount either (To not disturb the other session)."
   else	
	echo "Mounting Alpine rootfs"
	mkdir -p /tmp/alpine
	
	# Try to mount the Alpine image
	if ! mount -o loop,noatime -t ext4 "$ALPINE_IMAGE" /tmp/alpine; then
		echo "ERROR: Failed to mount Alpine image at $ALPINE_IMAGE"
		echo "This could be due to:"
		echo "  - File is corrupted or not a valid ext4 filesystem"
		echo "  - No available loop devices"
		echo "  - Insufficient permissions"
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	
	# Create necessary directories in Alpine rootfs if they don't exist
	mkdir -p /tmp/alpine/dev
	mkdir -p /tmp/alpine/dev/pts
	mkdir -p /tmp/alpine/proc
	mkdir -p /tmp/alpine/sys
	mkdir -p /tmp/alpine/etc
	
	# Bind mount virtual filesystems
	if ! mount -o bind /dev /tmp/alpine/dev; then
		echo "ERROR: Failed to bind mount /dev"
		umount /tmp/alpine 2>/dev/null
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	
	if ! mount -o bind /dev/pts /tmp/alpine/dev/pts; then
		echo "ERROR: Failed to bind mount /dev/pts"
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	
	if ! mount -o bind /proc /tmp/alpine/proc; then
		echo "ERROR: Failed to bind mount /proc"
		umount /tmp/alpine/dev/pts 2>/dev/null
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	
	if ! mount -o bind /sys /tmp/alpine/sys; then
		echo "ERROR: Failed to bind mount /sys"
		umount /tmp/alpine/proc 2>/dev/null
		umount /tmp/alpine/dev/pts 2>/dev/null
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	
	# mount -o bind /var/run/dbus/ /tmp/alpine/run/dbus/
	
	# Copy hosts file if it exists
	if [ -f /etc/hosts ]; then
		cp /etc/hosts /tmp/alpine/etc/hosts
	fi
	
	chmod a+w /dev/shm 2>/dev/null
fi

echo "You're now being dropped into Alpine's shell"
chroot /tmp/alpine /bin/sh

if [ $ALREADYMOUNTED = "yes" ] ; then
	echo "Umount is being skipped, as the rootfs was mounted already. You're now at your kindle's shell again."
else
	echo "You returned from Alpine, killing remaining processes"
	# Kill processes if they exist, but don't fail if they don't
	if pgrep Xephyr > /dev/null 2>&1; then
		kill $(pgrep Xephyr) 2>/dev/null || true
	fi
	
	# Kill processes using /tmp/alpine (corrected path)
	if command -v lsof > /dev/null 2>&1; then
		ALPINE_PROCS=$(lsof -t /tmp/alpine/ 2>/dev/null || true)
		if [ -n "$ALPINE_PROCS" ]; then
			kill -9 $ALPINE_PROCS 2>/dev/null || true
		fi
	fi

	echo "Unmounting Alpine rootfs"
	# Get the loop device associated with /tmp/alpine before unmounting
	LOOPDEV="$(mount | grep '/tmp/alpine ' | grep -o '/dev/loop[0-9]*' | head -1)"
	
	# umount /tmp/alpine/run/dbus/
	
	# Unmount in reverse order with error checking
	if mount | grep -q "/tmp/alpine/sys"; then
		umount /tmp/alpine/sys || echo "Warning: Failed to unmount /tmp/alpine/sys"
	fi
	sleep 1
	
	if mount | grep -q "/tmp/alpine/proc"; then
		umount /tmp/alpine/proc || echo "Warning: Failed to unmount /tmp/alpine/proc"
	fi
	
	if mount | grep -q "/tmp/alpine/dev/pts"; then
		umount /tmp/alpine/dev/pts || echo "Warning: Failed to unmount /tmp/alpine/dev/pts"
	fi
	
	if mount | grep -q "/tmp/alpine/dev"; then
		umount /tmp/alpine/dev || echo "Warning: Failed to unmount /tmp/alpine/dev"
	fi
	
	# Sync beforehand so umount doesn't fail due to the device being busy still
	sync
	
	# Unmount the main Alpine filesystem
	if mount | grep -q "/tmp/alpine"; then
		umount /tmp/alpine || echo "Warning: Initial unmount of /tmp/alpine failed"
		
		# Sometimes it fails and only works by trying again
		RETRY_COUNT=0
		while [ "$(mount | grep /tmp/alpine)" ] && [ $RETRY_COUNT -lt 10 ]
		do
			echo "Alpine is still mounted, trying again shortly.. (attempt $((RETRY_COUNT + 1))/10)"
			sleep 3
			umount /tmp/alpine || true
			RETRY_COUNT=$((RETRY_COUNT + 1))
		done
		
		if [ "$(mount | grep /tmp/alpine)" ]; then
			echo "ERROR: Failed to unmount Alpine after multiple attempts"
			echo "You may need to manually unmount /tmp/alpine and clean up the loop device"
			if [ -n "$LOOPDEV" ]; then
				echo "Loop device to clean up: $LOOPDEV"
			fi
		else
			echo "Alpine unmounted"
		fi
	else
		echo "Alpine was not mounted"
	fi
	
	# Clean up the loop device if we found one and Alpine is unmounted
	if [ -n "$LOOPDEV" ] && [ -z "$(mount | grep /tmp/alpine)" ]; then
		echo "Disassociating loop device >>$LOOPDEV<<"
		if ! losetup -d "$LOOPDEV" 2>/dev/null; then
			echo "Warning: Failed to disassociate loop device $LOOPDEV"
			echo "You may need to run: losetup -d $LOOPDEV"
		fi
	elif [ -z "$LOOPDEV" ]; then
		echo "No loop device found to disassociate"
	fi
	
	# Clean up the mount point
	rmdir /tmp/alpine 2>/dev/null || true
	
	echo "All done, you're now back at your kindle's shell."
fi

