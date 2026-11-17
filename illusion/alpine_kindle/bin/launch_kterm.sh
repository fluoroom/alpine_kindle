#!/bin/sh
# Opens kterm and runs one of the interactive session scripts inside it.
#
# Usage: launch_kterm.sh start.sh|xfce.sh|gui_installer.sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

SESSION="$1"

case "$SESSION" in
    start.sh|xfce.sh|gui_installer.sh) ;;
    *)
        log "ERROR: Unknown terminal session: $SESSION"
        status_set message "Unknown terminal session"
        exit 2
        ;;
esac

KTERM="$(find_kterm 2>/dev/null || true)"
KTERM_LAUNCHER="$(find_kterm_launcher 2>/dev/null || true)"
if [ -z "$KTERM" ]; then
    status_set message "kterm is not installed"
    log "ERROR: kterm not found."
    log "Install kterm from KPM (kpm -y install kterm) or manually."
    exit 1
fi

log "Opening kterm ($SESSION)..."
status_set action "Terminal"
status_set message "Opening terminal..."

if [ -n "$KTERM_LAUNCHER" ]; then
    log "Using KPM kterm launcher: $KTERM_LAUNCHER"
    DISPLAY=:0 nohup sh "$KTERM_LAUNCHER" -e "sh $APP_DIR/bin/$SESSION" $KTERM_OPTS >/dev/null 2>&1 &
else
    DISPLAY=:0 nohup "$KTERM" -e "sh $APP_DIR/bin/$SESSION" $KTERM_OPTS >/dev/null 2>&1 &
fi

sleep 1
if pgrep -f "$KTERM" >/dev/null 2>&1; then
    status_set message "Terminal opened"
    log "kterm launched."
    exit 0
fi

status_set message "Could not open kterm"
log "ERROR: kterm did not start."
exit 1
