#!/bin/sh
# Deletes the Alpine home filesystem (user data and settings).
#
# Usage: deletehome.sh [--yes]

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

begin_action "Delete Alpine home" || exit 1
trim_log

if mount 2>/dev/null | grep -q "/tmp/alpine"; then
    fail_action "Alpine is still mounted. Stop it before deleting home data."
fi

if [ "$ASSUME_YES" != "1" ]; then
    printf "Delete the Alpine HOME filesystem (all user data and settings)? This cannot be undone. (y/N): "
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log "Deletion cancelled."
        status_set message "Deletion cancelled"
        finish_action
        exit 0
    fi
fi

if [ -f "$DATA_DIR/home.ext4" ]; then
    log "Deleting $DATA_DIR/home.ext4"
    status_set message "Deleting Alpine home filesystem..."
    rm -f "$DATA_DIR/home.ext4" || fail_action "Could not delete home.ext4"
else
    log "home.ext4 does not exist."
fi

probe_status
status_set message "Alpine home data deleted"
finish_action
log "Alpine home filesystem deleted."
exit 0
