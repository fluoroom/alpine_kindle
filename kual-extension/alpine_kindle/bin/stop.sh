#!/bin/sh

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