#!/bin/sh
# Installs kterm through KPM when kterm is missing.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

begin_action "Install kterm" || exit 1
trim_log

CURRENT_KTERM="$(find_kterm 2>/dev/null || true)"
if [ -n "$CURRENT_KTERM" ]; then
    log "kterm is already installed at $CURRENT_KTERM"
    probe_status
    status_set message "kterm is already installed"
    finish_action
    exit 0
fi

KPM="$(find_kpm 2>/dev/null || true)"
if [ -z "$KPM" ]; then
    fail_action "KPM is not installed. Install kterm from the kterm releases page instead."
fi

log "Installing kterm with $KPM..."
status_set message "Installing kterm via KPM..."

if "$KPM" -y install kterm >> "$LOG_FILE" 2>&1; then
    log "KPM finished."
else
    log "KPM returned an error; checking whether kterm was installed anyway."
fi

if [ -z "$(find_kterm 2>/dev/null || true)" ]; then
    fail_action "kterm was not found after KPM finished. Check the Activity log."
fi

probe_status
status_set message "kterm installed"
finish_action
log "kterm is ready."
exit 0
