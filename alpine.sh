#!/bin/sh
# Alpine Linux wrapper for Kindle
# Inspired by KOReader's framework handling and cleanup measures

# NOTE: Copy script to tmpfs to avoid issues with vfat+fuse during execution
if [ "$(dirname "${0}")" != "/var/tmp" ]; then
	cp -pf "${0}" /var/tmp/alpine.sh
	chmod 777 /var/tmp/alpine.sh
	exec /var/tmp/alpine.sh "$@"
fi

export LC_ALL="en_US.UTF-8"

# Unlock keypad and fiveway if available
PROC_KEYPAD="/proc/keypad"
PROC_FIVEWAY="/proc/fiveway"
[ -e "${PROC_KEYPAD}" ] && echo unlock >"${PROC_KEYPAD}"
[ -e "${PROC_FIVEWAY}" ] && echo unlock >"${PROC_FIVEWAY}"

# Detect init system (upstart or sysv)
if [ -d "/etc/upstart" ]; then
	INIT_TYPE="upstart"
else
	INIT_TYPE="sysv"
fi

# Logging helper
logmsg() {
	echo "[Alpine] ${1}"
}

# Keep track of what we've modified
STOP_FRAMEWORK="no"
AWESOME_STOPPED="no"
CVM_STOPPED="no"
VOLUMD_STOPPED="no"
PILLOW_HARD_DISABLED="no"
PILLOW_SOFT_DISABLED="no"

# List of services to stop for RAM reclamation (from KOReader)
TOGGLED_SERVICES="webreader kfxreader kfxview todo tmd rcm archive scanner otav3 otaupd"

# Normalize a version string for easy numeric comparisons
version() { echo "$@" | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }'; }

# Try to find an unused loop device manually and attach image
try_manual_loop_allocation() {
	local image_file="$1"
	local LOOP=""
	
	echo "Scanning for available loop devices..." >&2
	
	for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
		if [ -e "/dev/loop$i" ]; then
			# Check if loop device is in use
			if losetup "/dev/loop$i" >/dev/null 2>&1; then
				# Device is busy, show what it's mounting
				# Kindle losetup format: /dev/loopX: offset backing_file
				# Example: /dev/loop0: 8192 /dev/mmcblk0p10
				LOOP_OUTPUT=$(losetup "/dev/loop$i" 2>/dev/null)
				
				# Extract the backing file (third field)
				BACKING_FILE=$(echo "$LOOP_OUTPUT" | awk '{print $3}')
				
				echo "  /dev/loop$i: BUSY (mounting: ${BACKING_FILE:-unknown})" >&2
			else
				# Device appears to be free, try to allocate it
				echo "  /dev/loop$i: available, attempting to allocate..." >&2
				if losetup "/dev/loop$i" "$image_file" 2>/dev/null; then
					LOOP="/dev/loop$i"
					echo "Successfully allocated loop device: $LOOP" >&2
					break
				else
					echo "  /dev/loop$i: allocation failed" >&2
				fi
			fi
		fi
	done
	
	if [ -z "$LOOP" ]; then
		echo "No available loop devices found!" >&2
	fi
	
	echo "$LOOP"
}

# Unified function to mount ext4 filesystem images
# Returns: loop device used (or empty if mount -o loop was used)
mount_filesystem_image() {
	local image_file="$1"
	local mount_point="$2"
	local fs_name="$3"  # e.g., "Alpine rootfs" or "home filesystem"
	
	echo "Mounting $fs_name..."
	mkdir -p "$mount_point"
	
	# First try: simple mount -o loop (let kernel handle loop device)
	if mount -o loop,noatime -t ext4 "$image_file" "$mount_point" 2>/dev/null; then
		echo "$fs_name mounted at $mount_point via mount -o loop"
		echo ""  # Return empty string (no explicit loop device to track)
		return 0
	fi
	
	# If that failed, try manual loop device allocation
	echo "Direct mount failed, trying manual loop device allocation..."
	if command -v losetup >/dev/null 2>&1; then
		local ALLOCATED_LOOP="$(try_manual_loop_allocation "$image_file")"
		
		if [ -n "$ALLOCATED_LOOP" ]; then
			if mount -t ext4 "$ALLOCATED_LOOP" "$mount_point" 2>/dev/null; then
				echo "$fs_name mounted at $mount_point using $ALLOCATED_LOOP"
				echo "$ALLOCATED_LOOP"  # Return the loop device so caller can track it
				return 0
			else
				echo "Failed to mount $fs_name using loop device $ALLOCATED_LOOP"
				losetup -d "$ALLOCATED_LOOP" 2>/dev/null || true
			fi
		else
			echo "Could not allocate a loop device for $fs_name"
		fi
	fi
	
	# Mount failed
	echo "WARNING: Failed to mount $fs_name at $image_file"
	return 1
}

# Cleanup function for bind mount failures
cleanup_and_fail() {
	echo "ERROR: $1"
	umount /tmp/alpine/dev/pts 2>/dev/null || true
	umount /tmp/alpine/dev 2>/dev/null || true
	umount /tmp/alpine 2>/dev/null
	[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
	rmdir /tmp/alpine 2>/dev/null
	exit 1
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
	# Try to find it from mount output first
	LOOPDEV="$(mount | grep '/tmp/alpine ' | grep -o '/dev/loop[0-9]\+' | head -1 || true)"
	
	# If not found in mount, try losetup -a to find which loop device has our image
	if [ -z "$LOOPDEV" ] && command -v losetup >/dev/null 2>&1; then
		LOOPDEV="$(losetup -a 2>/dev/null | grep "$ALPINE_IMAGE" | cut -d: -f1 || true)"
	fi

	# Unmount home filesystem first if it's mounted
	HOME_LOOPDEV=""
	if mount | grep -q "/tmp/alpine/home"; then
		echo "Unmounting home filesystem..."
		# Get the loop device for home before unmounting
		HOME_LOOPDEV="$(mount | grep '/tmp/alpine/home ' | grep -o '/dev/loop[0-9]\+' | head -1 || true)"
		
		# If not found in mount, try losetup -a
		if [ -z "$HOME_LOOPDEV" ] && [ -n "$HOME_IMAGE" ] && command -v losetup >/dev/null 2>&1; then
			HOME_LOOPDEV="$(losetup -a 2>/dev/null | grep "$HOME_IMAGE" | cut -d: -f1 || true)"
		fi
		
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

	echo "All done, Alpine filesystems unmounted."
}


# Parse command line parameters
KEEP_RUNNING=false

while [ $# -gt 0 ]; do
	case "$1" in
		--keep-running)
			KEEP_RUNNING=true
			logmsg "Keep-running mode enabled - Alpine will stay mounted after logout"
			;;
		--stop-framework)
			STOP_FRAMEWORK="yes"
			logmsg "Framework stop requested - will stop Amazon framework"
			;;
		--help|-h)
			echo "Usage: $0 [OPTIONS]"
			echo ""
			echo "Alpine Linux wrapper - manages Alpine GUI via upstart service"
			echo ""
			echo "Options:"
			echo "  --keep-running     Keep Alpine mounted after logout (skip prompt)"
			echo "  --stop-framework   Stop Amazon framework before entering Alpine"
			echo "  --help, -h         Show this help message"
			echo ""
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			echo "Use --help for usage information"
			exit 1
			;;
	esac
	shift
done

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
	echo "  /mnt/us/alpine.ext3"
	echo "  /mnt/base-us/alpine/alpine.ext4"
	echo "Please ensure the Alpine image is properly installed."
	exit 1
fi

echo "Using Alpine image: $ALPINE_IMAGE"

# Determine home.ext4 location (same directory as Alpine image)
ALPINE_DIR="$(dirname "$ALPINE_IMAGE")"
HOME_IMAGE="$ALPINE_DIR/home.ext4"

# ===== FRAMEWORK HANDLING (adapted from KOReader) =====

# Check if we need to stop the framework
if [ "${STOP_FRAMEWORK}" = "yes" ]; then
	logmsg "Stopping the Amazon framework..."
	
	# Dump framebuffer so we can restore something useful on exit
	cat /dev/fb0 >/var/tmp/alpine-fb.dump
	
	# Stop the framework (method depends on init system)
	if [ "${INIT_TYPE}" = "sysv" ]; then
		/etc/init.d/framework stop
	else
		# Upstart: trap SIGTERM so we don't get killed
		trap "" TERM
		stop lab126_gui
		# Let framework teardown finish
		usleep 1250000
		# Remove the trap
		trap - TERM
	fi
fi

# Get firmware version if on upstart (for version-specific handling)
if [ "${INIT_TYPE}" = "upstart" ]; then
	FW_VERSION="$(grep '^Kindle 5' /etc/prettyversion.txt 2>&1 | sed -n -r 's/^(Kindle)([[:blank:]]*)([[:digit:]\.]*)(.*?)$/\3/p')"
	
	# On newer firmwares, disable pillow to prevent status bar interference
	if [ -n "${FW_VERSION}" ]; then
		if [ "$(version "${FW_VERSION}")" -ge "$(version "5.6.5")" ]; then
			logmsg "Disabling pillow (FW >= 5.6.5)..."
			cat /dev/fb0 >/var/tmp/alpine-fb.dump
			lipc-set-prop com.lab126.pillow disableEnablePillow disable
			PILLOW_HARD_DISABLED="yes"
			
			# On FW >= 5.7.2, also stop awesome to prevent clock refreshes
			if [ "$(version "${FW_VERSION}")" -ge "$(version "5.7.2")" ]; then
				logmsg "Stopping awesome window manager..."
				killall -STOP awesome
				AWESOME_STOPPED="yes"
			fi
		elif [ "$(version "${FW_VERSION}")" -ge "$(version "5.0.0")" ]; then
			logmsg "Hiding status bar (soft method)..."
			cat /dev/fb0 >/var/tmp/alpine-fb.dump
			lipc-set-prop com.lab126.pillow interrogatePillow '{"pillowId": "default_status_bar", "function": "nativeBridge.hideMe();"}'
			PILLOW_SOFT_DISABLED="yes"
		fi
	fi
	
	# Murder some services to reclaim RAM
	logmsg "Stopping background services to reclaim RAM..."
	for job in ${TOGGLED_SERVICES}; do
		stop "${job}" 2>/dev/null || true
	done
fi

# Stop cvm on sysv systems
if [ "${STOP_FRAMEWORK}" = "no" ] && [ "${INIT_TYPE}" = "sysv" ]; then
	logmsg "Stopping cvm..."
	killall -STOP cvm
	CVM_STOPPED="yes"
fi

# SIGSTOP volumd to inhibit USBMS
if [ -e "/etc/init.d/volumd" ] || [ -e "/etc/upstart/volumd.conf" ]; then
	logmsg "Stopping volumd (inhibit USB mass storage)..."
	killall -STOP volumd
	VOLUMD_STOPPED="yes"
fi

# ===== HOME FILESYSTEM SETUP =====

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
	# Ensure loop support: try modprobe (may fail quietly)
	if command -v modprobe >/dev/null 2>&1; then
		modprobe loop 2>/dev/null || true
	fi

	# Mount Alpine rootfs using unified function
	LOOP=$(mount_filesystem_image "$ALPINE_IMAGE" "/tmp/alpine" "Alpine rootfs")
	
	# Check if mount succeeded
	if ! mount | grep -q "/tmp/alpine"; then
		echo ""
		echo "ERROR: Failed to mount Alpine image at $ALPINE_IMAGE"
		echo "This could be due to:"
		echo "  - File is corrupted or not a valid ext4 filesystem"
		echo "  - No available loop devices"
		echo "  - Insufficient permissions"
		exit 1
	fi

	# Create necessary directories in Alpine rootfs if they don't exist
	mkdir -p /tmp/alpine/dev
	mkdir -p /tmp/alpine/dev/pts
	mkdir -p /tmp/alpine/proc
	mkdir -p /tmp/alpine/sys
	mkdir -p /tmp/alpine/etc

	# Bind mount virtual filesystems (best-effort, fail cleanly)
	if ! mount -o bind /dev /tmp/alpine/dev; then
		cleanup_and_fail "Failed to bind mount /dev"
	fi

	if ! mount -o bind /dev/pts /tmp/alpine/dev/pts; then
		cleanup_and_fail "Failed to bind mount /dev/pts"
	fi

	if ! mount -o bind /proc /tmp/alpine/proc; then
		cleanup_and_fail "Failed to bind mount /proc"
	fi

	if ! mount -o bind /sys /tmp/alpine/sys; then
		cleanup_and_fail "Failed to bind mount /sys"
	fi

	# Copy hosts file if it exists
	if [ -f /etc/hosts ]; then
		cp /etc/hosts /tmp/alpine/etc/hosts
	fi

	chmod a+w /dev/shm 2>/dev/null || true

	# Mount home.ext4 if available
	if [ -n "$HOME_IMAGE" ] && [ -f "$HOME_IMAGE" ]; then
		HOME_LOOP=$(mount_filesystem_image "$HOME_IMAGE" "/tmp/alpine/home" "home filesystem")
		
		# Check if home mount succeeded
		if ! mount | grep -q "/tmp/alpine/home"; then
			echo "WARNING: Failed to mount home filesystem at $HOME_IMAGE"
			echo "Continuing without separate home filesystem..."
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

# ===== CLEANUP AND RESTORATION (adapted from KOReader) =====

logmsg "Alpine session ended, cleaning up..."

# Kill any stray Alpine processes
if pgrep Xephyr > /dev/null 2>&1; then
	logmsg "Killing Xephyr processes..."
	killall -TERM Xephyr 2>/dev/null || true
fi

if command -v lsof > /dev/null 2>&1; then
	ALPINE_PROCS=$(lsof -t /tmp/alpine/ 2>/dev/null || true)
	if [ -n "$ALPINE_PROCS" ]; then
		logmsg "Killing processes using Alpine filesystem..."
		kill -9 $ALPINE_PROCS 2>/dev/null || true
	fi
fi

# Resume volumd if we stopped it
if [ "${VOLUMD_STOPPED}" = "yes" ]; then
	logmsg "Resuming volumd..."
	killall -CONT volumd
fi

# Resume cvm if we stopped it (sysv only)
if [ "${CVM_STOPPED}" = "yes" ]; then
	logmsg "Resuming cvm..."
	killall -CONT cvm
	# Trigger screen refresh on Kindle 3
	echo 'send 139' >/proc/keypad
	echo 'send 139' >/proc/keypad
fi

# Restart framework if we stopped it
if [ "${STOP_FRAMEWORK}" = "yes" ]; then
	logmsg "Restarting Amazon framework..."
	if [ "${INIT_TYPE}" = "sysv" ]; then
		cd / && /etc/init.d/framework start
	else
		cd / && start lab126_gui
	fi
fi

# Restore pillow and services on upstart systems
if [ "${INIT_TYPE}" = "upstart" ]; then
	# Resume awesome if we stopped it
	if [ "${AWESOME_STOPPED}" = "yes" ]; then
		logmsg "Resuming awesome window manager..."
		killall -CONT awesome
	fi
	
	# Re-enable pillow if we disabled it
	if [ "${PILLOW_HARD_DISABLED}" = "yes" ]; then
		logmsg "Re-enabling pillow..."
		# Restore framebuffer content
		cat /var/tmp/alpine-fb.dump >/dev/fb0
		rm -f /var/tmp/alpine-fb.dump
		lipc-set-prop com.lab126.pillow disableEnablePillow enable
		lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home
	fi
	
	# Restore status bar if we hid it
	if [ "${PILLOW_SOFT_DISABLED}" = "yes" ]; then
		logmsg "Restoring status bar..."
		# Restore framebuffer content
		cat /var/tmp/alpine-fb.dump >/dev/fb0
		rm -f /var/tmp/alpine-fb.dump
		lipc-set-prop com.lab126.pillow interrogatePillow '{"pillowId": "default_status_bar", "function": "nativeBridge.showMe();"}'
		lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home
	fi
	
	# Resume the services we stopped
	logmsg "Resuming background services..."
	for job in ${TOGGLED_SERVICES}; do
		start "${job}" 2>/dev/null || true
	done
fi

# Unmount Alpine filesystems
# Unmount Alpine filesystems
if [ $ALREADYMOUNTED = "yes" ] ; then
	logmsg "Alpine was already mounted, skipping unmount to avoid disturbing other sessions"
	printf "Do you want to force stop? (y/N): "
	read -r FORCE_STOP
	if [ "$FORCE_STOP" = "y" ] || [ "$FORCE_STOP" = "Y" ]; then
		umount_alpine
	fi
else
	if [ "${KEEP_RUNNING}" = "true" ]; then
		logmsg "Keeping Alpine mounted (--keep-running mode)"
	else
		printf "Do you want to keep Alpine running in background? (y/N): "
		read -r KEEP_ANSWER
		
		if [ "$KEEP_ANSWER" = "y" ] || [ "$KEEP_ANSWER" = "Y" ]; then
			logmsg "Keeping Alpine mounted in background"
		else
			umount_alpine
		fi
	fi
fi

# Cleanup: remove temporary copy of this script
rm -f /var/tmp/alpine.sh /var/tmp/alpine-fb.dump

logmsg "Done. Goodbye!"

