#!/bin/sh
# Deletes the Alpine root filesystem. The separate home.ext4 is preserved.
#
# Usage: delete.sh [--yes]

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

begin_action "Delete Alpine root" || exit 1
trim_log

if mount 2>/dev/null | grep -q "/tmp/alpine"; then
    fail_action "Alpine is still mounted. Stop it before deleting."
fi

if [ "$ASSUME_YES" != "1" ]; then
    printf "Delete the Alpine ROOT filesystem? User data in home.ext4 is kept. (y/N): "
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log "Deletion cancelled."
        status_set message "Deletion cancelled"
        finish_action
        exit 0
    fi
fi

if [ -f "$DATA_DIR/alpine.ext4" ]; then
    log "Deleting $DATA_DIR/alpine.ext4"
    status_set message "Deleting Alpine root filesystem..."
    rm -f "$DATA_DIR/alpine.ext4" || fail_action "Could not delete alpine.ext4"
fi

if [ -f "$DATA_DIR/alpine.sh" ]; then
    log "Deleting $DATA_DIR/alpine.sh"
    rm -f "$DATA_DIR/alpine.sh" 2>/dev/null || true
fi

if [ -f "$DATA_DIR/alpine.conf" ]; then
    log "Deleting $DATA_DIR/alpine.conf"
    rm -f "$DATA_DIR/alpine.conf" 2>/dev/null || true
fi

rm -f "$DATA_DIR/alpine.zip" 2>/dev/null || true

set_scriptlet_name

probe_status
status_set message "Alpine root deleted (home data kept)"
finish_action
log "Alpine root filesystem deleted."
exit 0
