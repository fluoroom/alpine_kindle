#!/bin/sh
# Re-detects device state (kterm, installed images, mount status, Utild) and
# writes it to the status file read by the Illusion UI.
#
# Usage: probe.sh [--clear-updated]

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

# Do not overwrite an in-progress action's message.
probe_status

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
