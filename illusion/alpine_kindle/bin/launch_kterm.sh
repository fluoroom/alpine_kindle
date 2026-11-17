#!/bin/sh
# Opens kterm and runs one of the interactive session scripts inside it.
#
# Usage: launch_kterm.sh start.sh|xfce.sh|gui_installer.sh

SCRIPT_DIR="$(dirname "$0")"
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

if [ ! -x "$KTERM" ]; then
    status_set message "kterm is not installed"
    log "ERROR: kterm not found at $KTERM"
    log "Install kterm from https://github.com/bfabiszewski/kterm/releases"
    exit 1
fi

log "Opening kterm ($SESSION)..."
status_set action "Terminal"
status_set message "Opening terminal..."

DISPLAY=:0 nohup "$KTERM" -e "sh $APP_DIR/bin/$SESSION" $KTERM_OPTS >/dev/null 2>&1 &

sleep 1
if pgrep -f "$KTERM" >/dev/null 2>&1; then
    status_set message "Terminal opened"
    log "kterm launched."
    exit 0
fi

status_set message "Could not open kterm"
log "ERROR: kterm did not start."
exit 1
