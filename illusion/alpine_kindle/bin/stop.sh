#!/bin/sh
# Stops Alpine and cleans up mounts, loop devices and leftover processes.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

begin_action "Stop Alpine" || exit 1
trim_log

if ! mount 2>/dev/null | grep -q "/tmp/alpine"; then
    log "Alpine was not mounted."
    probe_status
    status_set message "Alpine was not running"
    finish_action
    exit 0
fi

# Kill anything still using the Alpine tree.
if pgrep Xephyr >/dev/null 2>&1; then
    log "Stopping Xephyr..."
    kill $(pgrep Xephyr) 2>/dev/null || true
fi

if command -v lsof >/dev/null 2>&1; then
    ALPINE_PROCS="$(lsof -t /tmp/alpine/ 2>/dev/null || true)"
    if [ -n "$ALPINE_PROCS" ]; then
        log "Killing processes using /tmp/alpine..."
        kill -9 $ALPINE_PROCS 2>/dev/null || true
    fi
fi

LOOPDEV="$(mount 2>/dev/null | grep '/tmp/alpine ' | grep -o '/dev/loop[0-9]*' | head -n 1 || true)"
HOME_LOOPDEV=""

if mount 2>/dev/null | grep -q "/tmp/alpine/home"; then
    log "Unmounting home filesystem..."
    HOME_LOOPDEV="$(mount 2>/dev/null | grep '/tmp/alpine/home ' | grep -o '/dev/loop[0-9]*' | head -n 1 || true)"
    umount /tmp/alpine/home 2>/dev/null || log "Warning: could not unmount /tmp/alpine/home"
fi

for mountpoint in /tmp/alpine/sys /tmp/alpine/proc /tmp/alpine/dev/pts /tmp/alpine/dev; do
    if mount 2>/dev/null | grep -q "$mountpoint"; then
        log "Unmounting $mountpoint..."
        umount "$mountpoint" 2>/dev/null || log "Warning: could not unmount $mountpoint"
        sleep 1
    fi
done

sync

status_set message "Unmounting Alpine..."
RETRY_COUNT=0
umount /tmp/alpine 2>/dev/null || true

while mount 2>/dev/null | grep -q "/tmp/alpine" && [ "$RETRY_COUNT" -lt 10 ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "Alpine is still mounted, retrying ($RETRY_COUNT/10)..."
    status_set message "Unmounting Alpine (attempt $((RETRY_COUNT + 1))/10)..."
    sleep 3
    umount /tmp/alpine 2>/dev/null || true
done

if mount 2>/dev/null | grep -q "/tmp/alpine"; then
    log "ERROR: Failed to unmount Alpine after $RETRY_COUNT attempts."
    [ -n "$LOOPDEV" ] && log "Loop device still in use: $LOOPDEV"
    probe_status
    fail_action "Could not unmount Alpine. Reboot the Kindle and try again."
fi

if [ -n "$LOOPDEV" ]; then
    log "Disassociating main loop device $LOOPDEV..."
    losetup -d "$LOOPDEV" 2>/dev/null || log "Warning: could not detach $LOOPDEV"
fi

if [ -n "$HOME_LOOPDEV" ]; then
    log "Disassociating home loop device $HOME_LOOPDEV..."
    losetup -d "$HOME_LOOPDEV" 2>/dev/null || log "Warning: could not detach $HOME_LOOPDEV"
fi

rmdir /tmp/alpine 2>/dev/null || true

probe_status
status_set message "Alpine stopped"
finish_action
log "Alpine stopped."
exit 0
