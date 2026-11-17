#!/bin/sh
# Re-detects device state (kterm, installed images, mount status, Utild) and
# writes it to the status file read by the Illusion UI.
#
# Usage: probe.sh [--clear-updated]

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

# Do not overwrite an in-progress action's message.
probe_status

# If a script was killed (for example by a reboot) the busy flag can survive
# without a lock. Refresh is an explicit user action and Utild is running, so
# it is safe to clear that stale state.
if [ "$(status_get busy)" = "1" ] && [ ! -d "$LOCK_DIR" ]; then
    status_set busy 0
    status_set message "Status refreshed"
fi

if [ "$1" = "--clear-updated" ]; then
    status_set updated 0
    log "State refreshed (update acknowledged)."
else
    if [ "$(status_get busy)" = "1" ]; then
        log "State refreshed (action in progress)."
    else
        log "State refreshed."
    fi
fi
