#!/bin/sh

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
elif [ -f "/mnt/us/alpine/alpine.ext3" ]; then
	ALPINE_IMAGE="/mnt/us/alpine/alpine.ext3"
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
	mkdir -p /tmp/alpine

	# Helper: cleanup and exit on mount failure
	_fail_mount() {
		echo "ERROR: Failed to mount Alpine image at $ALPINE_IMAGE"
		echo "This could be due to:"
		echo "  - File is corrupted or not a valid ext4 filesystem"
		echo "  - No available loop devices or kernel lacks loop support"
		echo "  - Image contains partitions (use losetup -P or mount with offset)"
		echo "  - Insufficient permissions"
		rmdir /tmp/alpine 2>/dev/null
		exit 1
	}

	# Ensure loop support: try modprobe (may fail quietly)
	if command -v modprobe >/dev/null 2>&1; then
		modprobe loop 2>/dev/null || true
	fi

	# Create /dev/loop* nodes if none exist (helpful on minimal systems)
	if [ ! -e /dev/loop0 ]; then
		# attempt to create a reasonable number of nodes (0-7)
		if command -v mknod >/dev/null 2>&1; then
			for i in 0 1 2 3 4 5 6 7; do
				if [ ! -e /dev/loop$i ]; then
					mknod -m660 /dev/loop$i b 7 $i 2>/dev/null || true
				fi
			done
		fi
	fi

	LOOP=""    # the loop device we attached (if any)
	PART=""    # the device or partition we will try to mount

	# Prefer losetup if available
	if command -v losetup >/dev/null 2>&1; then
		# First try the standard approach
		LOOP="$(losetup -f --show "$ALPINE_IMAGE" 2>/dev/null || true)"
		
		# If that failed, try to find an unused loop device manually
		if [ -z "$LOOP" ]; then
			echo "Standard loop device allocation failed, trying manual approach..."
			for i in 1 8 9 10 11 12 13 14 15 16; do
				if [ -e "/dev/loop$i" ] && ! losetup "/dev/loop$i" >/dev/null 2>&1; then
					# This loop device exists and appears to be free
					if losetup "/dev/loop$i" "$ALPINE_IMAGE" 2>/dev/null; then
						LOOP="/dev/loop$i"
						echo "Successfully allocated loop device: $LOOP"
						break
					fi
				fi
			done
		fi
		
		if [ -n "$LOOP" ]; then
			# If kernel created partition nodes, prefer first partition
			if [ -e "${LOOP}p1" ]; then
				PART="${LOOP}p1"
			else
				# Some kernels don't create p1 but image might be raw fs
				PART="$LOOP"
			fi
		fi
	fi

	# If losetup didn't succeed or isn't available, try mount -o loop directly
	if [ -z "$PART" ]; then
		if mount -o loop,noatime -t ext4 "$ALPINE_IMAGE" /tmp/alpine 2>/dev/null; then
			echo "Mounted $ALPINE_IMAGE at /tmp/alpine via mount -o loop"
			# mark LOOP empty to indicate mount done (no losetup tracking needed)
			LOOP=""
			PART="/tmp/alpine"
		else
			# mount -o loop failed. Try to detect partition and use offset approach.
			:
		fi
	fi

	# If we have a losetup device, try mounting PART (loop or loopXp1)
	if [ -n "$LOOP" ] && [ -n "$PART" ] && [ "$PART" != "/tmp/alpine" ]; then
		if mount -t ext4 "$PART" /tmp/alpine 2>/dev/null; then
			echo "Mounted $PART at /tmp/alpine"
		else
			# mounting partition failed -> detach and fallback to offset method
			losetup -d "$LOOP" 2>/dev/null || true
			LOOP=""
			PART=""
		fi
	fi

	# If still not mounted, try partition offset detection (fdisk/parted) if present
	if [ -z "$PART" ] || [ "$PART" = "" ]; then
		# Try fdisk first
		START_SECTOR=""
		if command -v fdisk >/dev/null 2>&1; then
			# fdisk output varies; try to find the "Start" of first partition
			# Use a different approach to avoid awk pattern issues with paths containing slashes
			START_SECTOR=$(fdisk -l "$ALPINE_IMAGE" 2>/dev/null | awk 'BEGIN{found=0} /^Device.*Start/ {found=1; next} found && /^[^[:space:]]/ && /[0-9]+/ {print $2; exit}')
			# fallback: look for any partition line with numeric start
			if [ -z "$START_SECTOR" ]; then
				START_SECTOR=$(fdisk -l "$ALPINE_IMAGE" 2>/dev/null | awk '/^[^[:space:]].*[0-9]+.*[0-9]+.*[0-9]+/ {print $2; exit}')
			fi
		fi

		# Try parted if fdisk not available or fdisk didn't help
		if [ -z "$START_SECTOR" ] && command -v parted >/dev/null 2>&1; then
			# parted prints sectors if unit s is set
			START_SECTOR=$(parted -s "$ALPINE_IMAGE" unit s print 2>/dev/null | awk '/^ 1/ {gsub("s","",$2); print $2; exit}')
		fi

		if [ -n "$START_SECTOR" ] && echo "$START_SECTOR" | grep -q '^[0-9][0-9]*$'; then
			OFFSET=$((START_SECTOR * 512))
			if mount -o loop,offset=$OFFSET,noatime -t ext4 "$ALPINE_IMAGE" /tmp/alpine 2>/dev/null; then
				echo "Mounted $ALPINE_IMAGE (offset=$OFFSET) at /tmp/alpine"
				PART="/tmp/alpine"
			else
				echo "Offset mount failed (offset=$OFFSET)"
			fi
		fi
	fi

	# Last resort: if we still don't have a mounted part, try one more manual approach
	if [ -z "$PART" ] && command -v losetup >/dev/null 2>&1; then
		echo "Trying last resort manual loop device approach..."
		LOOP="$(losetup -f --show "$ALPINE_IMAGE" 2>/dev/null || true)"
		
		# If standard approach still fails, try manual loop device allocation again
		if [ -z "$LOOP" ]; then
			for i in 1 8 9 10 11 12 13 14 15 16; do
				if [ -e "/dev/loop$i" ] && ! losetup "/dev/loop$i" >/dev/null 2>&1; then
					if losetup "/dev/loop$i" "$ALPINE_IMAGE" 2>/dev/null; then
						LOOP="/dev/loop$i"
						echo "Last resort: Successfully allocated loop device: $LOOP"
						break
					fi
				fi
			done
		fi
		
		if [ -n "$LOOP" ]; then
			if [ -e "${LOOP}p1" ]; then
				if mount -t ext4 "${LOOP}p1" /tmp/alpine 2>/dev/null; then
					echo "Mounted ${LOOP}p1 at /tmp/alpine"
					PART="${LOOP}p1"
				fi
			else
				if mount -t ext4 "$LOOP" /tmp/alpine 2>/dev/null; then
					echo "Mounted $LOOP at /tmp/alpine"
					PART="$LOOP"
				fi
			fi
		fi
	fi

	# If nothing succeeded, show diagnostics and fail
	if ! mount | grep -q "/tmp/alpine"; then
		# cleanup any loop we attached
		[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true

		# extra diagnostics for user
		echo ""
		echo "Detailed diagnostics (if available):"
		
		# Check if the image file is accessible and what type it is
		if [ -f "$ALPINE_IMAGE" ]; then
			echo "Image file exists and is accessible: $ALPINE_IMAGE"
			echo "Image file size: $(ls -lh "$ALPINE_IMAGE" 2>/dev/null | awk '{print $5}' || echo 'unknown')"
			if command -v file >/dev/null 2>&1; then
				echo "File type: $(file "$ALPINE_IMAGE" 2>/dev/null || echo 'unknown')"
			fi
			
			# Try to check filesystem integrity if fsck is available
			if command -v fsck.ext4 >/dev/null 2>&1; then
				echo "Checking filesystem integrity..."
				if fsck.ext4 -n "$ALPINE_IMAGE" >/dev/null 2>&1; then
					echo "Filesystem check: PASSED"
				else
					echo "Filesystem check: FAILED (filesystem may be corrupted)"
				fi
			fi
		else
			echo "ERROR: Image file not accessible: $ALPINE_IMAGE"
		fi
		
		# Check available loop devices
		if command -v losetup >/dev/null 2>&1; then
			echo ""
			echo "losetup -a output:"
			losetup -a 2>/dev/null || true
			echo "Available loop devices:"
			ls -la /dev/loop* 2>/dev/null || echo "No loop devices found in /dev/"
		fi
		
		# Check if we can try manual mount as a test
		echo ""
		echo "Testing direct mount capability..."
		if command -v mount >/dev/null 2>&1; then
			# Try a quick test mount in read-only mode to see what the error is
			TEST_DIR="/tmp/alpine_test_$$"
			mkdir -p "$TEST_DIR" 2>/dev/null
			
			echo "Attempting direct mount test..."
			MOUNT_ERROR=$(mount -o loop,ro -t ext4 "$ALPINE_IMAGE" "$TEST_DIR" 2>&1)
			MOUNT_RESULT=$?
			
			if [ $MOUNT_RESULT -eq 0 ]; then
				echo "Direct mount test: SUCCESS (unmounting now)"
				umount "$TEST_DIR" 2>/dev/null || true
			else
				echo "Direct mount test: FAILED"
				echo "Mount error details: $MOUNT_ERROR"
				
				# Try to see if it's a loop device issue specifically
				if echo "$MOUNT_ERROR" | grep -q "loop device"; then
					echo "This appears to be a loop device allocation problem."
					echo "Checking which loop devices might be available..."
					for i in 1 8 9 10 11 12 13 14 15 16; do
						if [ -e "/dev/loop$i" ]; then
							if losetup "/dev/loop$i" >/dev/null 2>&1; then
								echo "/dev/loop$i: BUSY"
							else
								echo "/dev/loop$i: potentially available"
							fi
						fi
					done
				fi
			fi
			rmdir "$TEST_DIR" 2>/dev/null || true
		fi
		
		if command -v dmesg >/dev/null 2>&1; then
			echo ""
			echo "dmesg tail:"
			dmesg | tail -n 30 2>/dev/null || true
		fi
		_fail_mount
	fi

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
		mkdir -p /tmp/alpine/home
		
		# Try to mount the home filesystem
		if ! mount -o loop,noatime -t ext4 "$HOME_IMAGE" /tmp/alpine/home 2>/dev/null; then
			echo "WARNING: Failed to mount home filesystem at $HOME_IMAGE"
			echo "Continuing without separate home filesystem..."
		else
			echo "Home filesystem mounted at /tmp/alpine/home"
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
	LOOPDEV="$(mount | grep '/tmp/alpine ' | grep -o '/dev/loop[0-9]*' | head -1 || true)"

	# Unmount home filesystem first if it's mounted
	if mount | grep -q "/tmp/alpine/home"; then
		echo "Unmounting home filesystem..."
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

	# Clean up the loop device if we found one and Alpine is unmounted
	if [ -n "$LOOPDEV" ] && ! mount | grep -q "/tmp/alpine"; then
		echo "Disassociating loop device >>$LOOPDEV<<"
		if ! losetup -d "$LOOPDEV" 2>/dev/null; then
			echo "Warning: Failed to disassociate loop device $LOOPDEV"
			echo "You may need to run: losetup -d $LOOPDEV"
		fi
	elif [ -z "$LOOPDEV" ]; then
		# Nothing to do
		:
	fi

	# Clean up the mount point
	rmdir /tmp/alpine 2>/dev/null || true

	echo "All done, you're now back at your kindle's shell."
fi