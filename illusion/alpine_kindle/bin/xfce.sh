#!/bin/sh
# XFCE desktop session. Runs inside kterm, launched by launch_kterm.sh.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

status_set busy 0
status_set action "XFCE desktop"
status_set message "Starting XFCE desktop"
probe_status
status_set action "XFCE desktop"
status_set message "Starting XFCE desktop"

if [ ! -f "$DATA_DIR/alpine.ext4" ]; then
    log "ERROR: Alpine is not installed."
    status_set message "Alpine is not installed"
    sleep 4
    exit 1
fi

if [ ! -f "$DATA_DIR/alpine.sh" ]; then
    log "ERROR: $DATA_DIR/alpine.sh is missing. Re-deploy Alpine."
    status_set message "alpine.sh is missing"
    sleep 4
    exit 1
fi

log "Starting XFCE desktop..."
sh "$DATA_DIR/alpine.sh" --xfce
RC=$?

probe_status
status_set busy 0
if [ "$RC" = "0" ]; then
    status_set message "XFCE desktop closed"
else
    status_set message "XFCE exited with code $RC"
fi
log "XFCE session exited (code $RC)."
launch_app
exit "$RC"
