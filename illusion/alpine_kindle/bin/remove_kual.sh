#!/bin/sh
# Removes the old KUAL extension and its library shortcut. Alpine data in
# /mnt/us/alpine is not touched.

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

begin_action "Remove old KUAL extension" || exit 1
trim_log

if [ -d /mnt/us/extensions/alpine_kindle ]; then
    log "Deleting /mnt/us/extensions/alpine_kindle"
    rm -rf /mnt/us/extensions/alpine_kindle || fail_action "Could not delete the old extension."
else
    log "Old KUAL extension not found."
fi

if [ -f /mnt/us/documents/Alpine.sh ]; then
    log "Deleting /mnt/us/documents/Alpine.sh"
    rm -f /mnt/us/documents/Alpine.sh 2>/dev/null || true
fi

# The old installer copied an outdated upstart unit into the system partition.
if [ -f /etc/upstart/alpine.conf ]; then
    log "Removing legacy /etc/upstart/alpine.conf"
    if mntroot rw 2>/dev/null; then
        rm -f /etc/upstart/alpine.conf 2>/dev/null || true
        mntroot r 2>/dev/null || true
    else
        log "WARNING: could not remount / read-write; upstart unit left in place."
    fi
fi

probe_status
status_set message "Old KUAL extension removed"
finish_action
log "Old KUAL extension removed."
exit 0
