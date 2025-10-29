#!/bin/sh

# Function to mount an ext4 image file to a mount point
# Usage: mount_image <image_file> <mount_point> [description]
mount_image() {
	local IMAGE_FILE="$1"
	local MOUNT_POINT="$2"
	local DESCRIPTION="${3:-filesystem}"
	
	if [ ! -f "$IMAGE_FILE" ]; then
		echo "ERROR: Image file not found: $IMAGE_FILE"
		return 1
	fi
	
	mkdir -p "$MOUNT_POINT"
	
	# Create additional loop device nodes if needed (silently)
	for i in 1 8 9 10 11 12 13 14 15; do
		if [ ! -e "/dev/loop$i" ]; then
			mknod "/dev/loop$i" b 7 $i 2>/dev/null || true
			chmod 660 "/dev/loop$i" 2>/dev/null || true
		fi
	done
	
	# Try direct mount first
	if mount -o loop,noatime -t ext4 "$IMAGE_FILE" "$MOUNT_POINT" 2>/dev/null; then
		return 0
	fi
	
	# If direct mount fails, try manual loop device allocation
	local LOOP_DEVICE=""
	for i in 1 8 9 10 11 12 13 14 15; do
		if [ -e "/dev/loop$i" ] && ! losetup "/dev/loop$i" >/dev/null 2>&1; then
			if losetup "/dev/loop$i" "$IMAGE_FILE" 2>/dev/null; then
				LOOP_DEVICE="/dev/loop$i"
				break
			fi
		fi
	done
	
	if [ -n "$LOOP_DEVICE" ]; then
		if mount -t ext4 "$LOOP_DEVICE" "$MOUNT_POINT" 2>/dev/null; then
			return 0
		else
			losetup -d "$LOOP_DEVICE" 2>/dev/null || true
		fi
	fi
	
	# Both methods failed
	return 1
}

umount_alpine() {
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
	LOOPDEV="$(mount | grep '/tmp/alpine ' | grep -o '/dev/loop[0-9]*' | head -1 || true)"

	# Unmount home filesystem first if it's mounted
	HOME_LOOPDEV=""
	if mount | grep -q "/tmp/alpine/home"; then
		echo "Unmounting home filesystem..."
		# Get the loop device for home before unmounting
		HOME_LOOPDEV="$(mount | grep '/tmp/alpine/home ' | grep -o '/dev/loop[0-9]*' | head -1 || true)"
		umount /tmp/alpine/home || echo "Warning: Failed to unmount /tmp/alpine/home"
	fi

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
		while mount | grep -q "/tmp/alpine" && [ $RETRY_COUNT -lt 10 ]
		do
			echo "Alpine is still mounted, trying again shortly.. (attempt $((RETRY_COUNT + 1))/10)"
			sleep 3
			umount /tmp/alpine || true
			RETRY_COUNT=$((RETRY_COUNT + 1))
		done

		if mount | grep -q "/tmp/alpine"; then
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

	# Clean up the loop devices if we found them and filesystems are unmounted
	if [ -n "$LOOPDEV" ] && ! mount | grep -q "/tmp/alpine"; then
		echo "Disassociating main loop device >>$LOOPDEV<<"
		if ! losetup -d "$LOOPDEV" 2>/dev/null; then
			echo "Warning: Failed to disassociate loop device $LOOPDEV"
			echo "You may need to run: losetup -d $LOOPDEV"
		fi
	elif [ -z "$LOOPDEV" ]; then
		# Nothing to do for main loop device
		:
	fi
	
	# Clean up home loop device if we found one
	if [ -n "$HOME_LOOPDEV" ] && ! mount | grep -q "/tmp/alpine/home"; then
		echo "Disassociating home loop device >>$HOME_LOOPDEV<<"
		if ! losetup -d "$HOME_LOOPDEV" 2>/dev/null; then
			echo "Warning: Failed to disassociate home loop device $HOME_LOOPDEV"
			echo "You may need to run: losetup -d $HOME_LOOPDEV"
		fi
	fi

	# Clean up the mount point
	rmdir /tmp/alpine 2>/dev/null || true

	echo "All done, you're now back at your kindle's shell."
}

# Check for --gui flag
AUTO_GUI=false
if [ "$1" = "--gui" ]; then
    AUTO_GUI=true
    echo "GUI mode enabled - will start GUI after entering Alpine"
fi

# Determine the correct Alpine image file to use
ALPINE_IMAGE="/mnt/us/alpine/alpine.ext4"
if [ -f "/mnt/us/alpine/alpine.ext4" ]; then
	ALPINE_IMAGE="/mnt/us/alpine/alpine.ext4"
elif [ -f "/mnt/base-us/alpine/alpine.ext4" ]; then
	ALPINE_IMAGE="/mnt/base-us/alpine/alpine.ext4"
else
	echo "ERROR: Alpine image file not found!"
	echo "Looked for:"
	echo "  /mnt/us/alpine.ext4"
	echo "  /mnt/base-us/alpine/alpine.ext4"
	echo "Please ensure the Alpine image is properly installed."
	exit 1
fi

echo "Using Alpine image: $ALPINE_IMAGE"

# Determine home.ext4 location (same directory as Alpine image)
ALPINE_DIR="$(dirname "$ALPINE_IMAGE")"
HOME_IMAGE="$ALPINE_DIR/home.ext4"

# Check if home.ext4 exists, if not ask user to create it
if [ ! -f "$HOME_IMAGE" ]; then
	echo ""
	echo "Home filesystem (home.ext4) not found at: $HOME_IMAGE"
	printf "Do you want to create it? (y/n): "
	read -r CREATE_HOME
	
	if [ "$CREATE_HOME" = "y" ] || [ "$CREATE_HOME" = "Y" ]; then
		printf "Enter size for home filesystem in MB (default: 512): "
		read -r HOME_SIZE
		
		# Default to 512MB if no input
		if [ -z "$HOME_SIZE" ]; then
			HOME_SIZE=512
		fi
		
		# Validate input is a number
		if ! echo "$HOME_SIZE" | grep -q '^[0-9][0-9]*$'; then
			echo "ERROR: Size must be a positive number"
			exit 1
		fi
		
		echo "Creating home filesystem ($HOME_SIZE MB) at: $HOME_IMAGE"
		dd if=/dev/zero of="$HOME_IMAGE" bs=1M count="$HOME_SIZE" 2>/dev/null
		if ! mkfs.ext4 -F "$HOME_IMAGE" >/dev/null 2>&1; then
			echo "ERROR: Failed to create home filesystem"
			rm -f "$HOME_IMAGE"
			exit 1
		fi
		# Optimize the filesystem for embedded use
		tune2fs -i 0 -c 0 -O ^has_journal "$HOME_IMAGE" >/dev/null 2>&1
		echo "Home filesystem created successfully"
	else
		echo "Continuing without home filesystem..."
		HOME_IMAGE=""
	fi
else
	echo "Using home filesystem: $HOME_IMAGE"
fi

ALREADYMOUNTED="no"
if mount | grep -q "/tmp/alpine"; then
	ALREADYMOUNTED="yes"
	echo "ATTENTION! Alpine's rootfs is already mounted, thus you will be just dropped into it."
	echo "BE CAREFUL to leave this shell first, as there will be no umount either (To not disturb the other session)."
else
	echo "Mounting Alpine rootfs"
	
	if ! mount_image "$ALPINE_IMAGE" /tmp/alpine "Alpine rootfs"; then
		echo "ERROR: Failed to mount Alpine image at $ALPINE_IMAGE"
		echo "This could be due to:"
		echo "  - File is corrupted or not a valid ext4 filesystem"
		echo "  - No available loop devices or kernel lacks loop support"
		echo "  - Insufficient permissions"
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi
	echo "Alpine rootfs mounted successfully"

	# Create necessary directories in Alpine rootfs if they don't exist
	mkdir -p /tmp/alpine/dev
	mkdir -p /tmp/alpine/dev/pts
	mkdir -p /tmp/alpine/proc
	mkdir -p /tmp/alpine/sys
	mkdir -p /tmp/alpine/etc

	# Bind mount virtual filesystems (best-effort, fail cleanly)
	if ! mount -o bind /dev /tmp/alpine/dev; then
		echo "ERROR: Failed to bind mount /dev"
		umount /tmp/alpine 2>/dev/null
		[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi

	if ! mount -o bind /dev/pts /tmp/alpine/dev/pts; then
		echo "ERROR: Failed to bind mount /dev/pts"
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi

	if ! mount -o bind /proc /tmp/alpine/proc; then
		echo "ERROR: Failed to bind mount /proc"
		umount /tmp/alpine/dev/pts 2>/dev/null
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi

	if ! mount -o bind /sys /tmp/alpine/sys; then
		echo "ERROR: Failed to bind mount /sys"
		umount /tmp/alpine/proc 2>/dev/null
		umount /tmp/alpine/dev/pts 2>/dev/null
		umount /tmp/alpine/dev 2>/dev/null
		umount /tmp/alpine 2>/dev/null
		[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	fi

	# Copy hosts file if it exists
	if [ -f /etc/hosts ]; then
		cp /etc/hosts /tmp/alpine/etc/hosts
	fi

	chmod a+w /dev/shm 2>/dev/null || true

	# Mount home.ext4 if available
	if [ -n "$HOME_IMAGE" ] && [ -f "$HOME_IMAGE" ]; then
		echo "Mounting home filesystem..."
		
		# Check if there are existing contents in /home that need to be preserved
		if [ -d "/tmp/alpine/home" ] && [ "$(ls -A /tmp/alpine/home 2>/dev/null)" ]; then
			echo "Preserving existing /home contents..."
			
			# Create a temporary mount point for the home filesystem
			TEMP_HOME_MOUNT="/tmp/home_temp_$$"
			mkdir -p "$TEMP_HOME_MOUNT"
			
			# Mount home.ext4 to temporary location
			if mount_image "$HOME_IMAGE" "$TEMP_HOME_MOUNT" "home filesystem"; then
				# Copy existing /home contents to the home filesystem
				cp -a /tmp/alpine/home/* "$TEMP_HOME_MOUNT/" 2>/dev/null || true
				# Copy hidden files but exclude . and .. directories
				find /tmp/alpine/home -maxdepth 1 -name ".*" ! -name "." ! -name ".." -exec cp -a {} "$TEMP_HOME_MOUNT/" \; 2>/dev/null || true
				
				# Unmount from temporary location
				umount "$TEMP_HOME_MOUNT" 2>/dev/null
				rmdir "$TEMP_HOME_MOUNT" 2>/dev/null
				
				# Clear the original /home directory safely
				find /tmp/alpine/home -maxdepth 1 ! -path /tmp/alpine/home -delete 2>/dev/null || true
			else
				echo "WARNING: Could not mount home filesystem temporarily"
				rmdir "$TEMP_HOME_MOUNT" 2>/dev/null
				echo "WARNING: Could not mount home filesystem, continuing without it"
			fi
		fi
		
		# Now mount the home filesystem to its final location
		if mount_image "$HOME_IMAGE" /tmp/alpine/home "home filesystem"; then
			echo "Home filesystem mounted successfully"
		else
			echo "WARNING: Could not mount home filesystem, continuing without it"
		fi
	fi
fi


if [ "$AUTO_GUI" = "true" ]; then
    echo "Starting Alpine with GUI..."
    chroot /tmp/alpine /bin/sh -c "gui"
    echo "GUI session ended"
else
    echo "You're now being dropped into Alpine's shell"
    chroot /tmp/alpine /bin/sh
    echo "Exited Alpine's shell"
fi

if [ $ALREADYMOUNTED = "yes" ] ; then
	echo "Umount is being skipped, as the rootfs was mounted already. Do you want to force stop? (y/N*): "
	read -r FORCE_STOP
	if [ "$FORCE_STOP" = "y" ] || [ "$FORCE_STOP" = "Y" ]; then
		umount_alpine
	fi
else
	echo "Alpine will be unmounted as there was no previous mount. Do you want to keep it running? (y/N*): "
	read -r KEEP_RUNNING
	if [ "$KEEP_RUNNING" = "y" ] || [ "$KEEP_RUNNING" = "Y" ]; then
		echo "Keeping Alpine running"
	else
		umount_alpine
	fi
fi

