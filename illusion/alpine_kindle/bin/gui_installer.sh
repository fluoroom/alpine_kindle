#!/bin/sh
# Interactive desktop-environment installer. Runs inside kterm, launched by
# launch_kterm.sh.

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

status_set busy 0
status_set action "GUI installer"
status_set message "GUI installer is open"
probe_status
status_set action "GUI installer"
status_set message "GUI installer is open"

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

log "Starting GUI installer..."
sh "$DATA_DIR/alpine.sh" --gui-installer
RC=$?

probe_status
status_set busy 0
if [ "$RC" = "0" ]; then
    status_set message "GUI installer closed"
else
    status_set message "GUI installer exited with code $RC"
fi
log "GUI installer exited (code $RC)."
exit "$RC"
