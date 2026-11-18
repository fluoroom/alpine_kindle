#!/bin/sh
# Shared helpers for the Alpine Linux Illusion app.
# This file is sourced by the launcher scripts; do not run it directly.

APP_ID="com.fluoroom.alpinekindle"
APP_VERSION="2.2.0"

# Overridable so the scripts can be exercised off-device.
APP_DIR="${ALPINE_APP_DIR:-/mnt/us/documents/alpine_kindle}"
DATA_DIR="${ALPINE_DATA_DIR:-/mnt/us/alpine}"
STATE_DIR="$DATA_DIR/illusion"
STATUS_FILE="$STATE_DIR/status.txt"
LOG_FILE="$STATE_DIR/action.log"
LOCK_DIR="${ALPINE_LOCK_DIR:-/tmp/alpine_kindle.lock}"
KTERM_OPTS="-k 1 -o U -s 7"
SCRIPTLET="${ALPINE_SCRIPTLET:-/mnt/us/documents/alpine_kindle.sh}"

ACTION_NAME=""
ACTION_DONE=0

# kterm can live in the classic extensions folder or be installed by KPM.
find_kterm() {
    if [ -n "$ALPINE_KTERM" ] && [ -x "$ALPINE_KTERM" ]; then
        echo "$ALPINE_KTERM"
        return 0
    fi
    for _candidate in \
        /mnt/us/extensions/kterm/bin/kterm \
        /mnt/us/kterm/bin/kterm \
        /mnt/us/kpm/packages/kterm/bin/kterm \
        /mnt/us/kpm/packages/bin/kterm \
        /mnt/us/kpm/packages/kterm/kterm
    do
        if [ -x "$_candidate" ]; then
            echo "$_candidate"
            return 0
        fi
    done
    _which="$(command -v kterm 2>/dev/null)"
    if [ -n "$_which" ] && [ -x "$_which" ]; then
        echo "$_which"
        return 0
    fi
    return 1
}

KTERM="$(find_kterm 2>/dev/null || true)"

# KPM's kterm package ships a launcher that sets TERM/TERMINFO and the
# correct keyboard layout. Prefer it when available.
find_kterm_launcher() {
    for _candidate in \
        /mnt/us/kpm/packages/kterm/launch.sh \
        /mnt/us/kpm/packages/bin/kterm-launch
    do
        if [ -f "$_candidate" ]; then
            echo "$_candidate"
            return 0
        fi
    done
    return 1
}

find_kpm() {
    if command -v kpm >/dev/null 2>&1; then
        command -v kpm
        return 0
    fi
    for _candidate in /usr/local/bin/kpm /mnt/us/kpm/packages/bin/kpm; do
        if [ -x "$_candidate" ]; then
            echo "$_candidate"
            return 0
        fi
    done
    return 1
}

# The scriptlet is named "alpine installer" until a root image exists, then
# "alpine" (and the app itself is "Alpine Manager").
set_scriptlet_name() {
    [ -f "$SCRIPTLET" ] || return 0
    if [ -f "$DATA_DIR/alpine.ext4" ]; then
        _wanted="alpine"
    else
        _wanted="alpine installer"
    fi
    _current="$(sed -n 's/^# Name: *//p' "$SCRIPTLET" 2>/dev/null | head -n 1)"
    [ "$_current" = "$_wanted" ] && return 0
    _tmp="$SCRIPTLET.tmp.$$"
    if grep -q '^# Name:' "$SCRIPTLET" 2>/dev/null; then
        sed "s/^# Name:.*/# Name: $_wanted/" "$SCRIPTLET" > "$_tmp" 2>/dev/null
    else
        # Also repair a scriptlet that lost its metadata line.
        awk -v name="$_wanted" 'NR == 1 { print; print "# Name: " name; next } { print }' \
            "$SCRIPTLET" > "$_tmp" 2>/dev/null
    fi
    if [ -s "$_tmp" ]; then
        mv "$_tmp" "$SCRIPTLET" 2>/dev/null || rm -f "$_tmp"
    else
        rm -f "$_tmp" 2>/dev/null || true
    fi
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR" 2>/dev/null || true
}

# Append one line both to the on-device log (read by the UI) and to stdout
# (which is useful when a script is run by hand or through kterm).
log() {
    ensure_state_dir
    printf '%s\n' "$*" >> "$LOG_FILE" 2>/dev/null || true
    printf '%s\n' "$*"
}

# Update a single key in the UI status file without touching the others.
status_set() {
    ensure_state_dir
    _key="$1"
    shift
    _value="$*"
    _tmp="$STATUS_FILE.tmp.$$"
    if [ -f "$STATUS_FILE" ]; then
        grep -v "^${_key}=" "$STATUS_FILE" > "$_tmp" 2>/dev/null || :
    else
        : > "$_tmp"
    fi
    printf '%s=%s\n' "$_key" "$_value" >> "$_tmp"
    mv "$_tmp" "$STATUS_FILE"
}

status_get() {
    [ -f "$STATUS_FILE" ] || return 1
    sed -n "s/^$1=//p" "$STATUS_FILE" 2>/dev/null | head -n 1
}

# Keep the log file from growing forever. Called at the start of an action.
trim_log() {
    [ -f "$LOG_FILE" ] || return 0
    if [ "$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')" -gt 300 ] 2>/dev/null; then
        tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

lock_acquire() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid" 2>/dev/null || true
        return 0
    fi

    # Recover a lock left behind by a killed process.
    _pid="$(cat "$LOCK_DIR/pid" 2>/dev/null)"
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        return 1
    fi
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo $$ > "$LOCK_DIR/pid" 2>/dev/null || true
        return 0
    fi
    return 1
}

lock_release() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# Marks the app as busy and claims the single-action lock.
begin_action() {
    ensure_state_dir
    ACTION_NAME="$1"
    ACTION_DONE=0

    if ! lock_acquire; then
        log "ERROR: Another Alpine action is already running."
        status_set message "Another action is already running"
        return 1
    fi

    trap 'action_abort' EXIT INT TERM HUP
    : > "$LOG_FILE" 2>/dev/null || true
    status_set busy 1
    status_set action "$ACTION_NAME"
    status_set message "Starting..."
    status_set progress 0
    status_set updated 0
    log "== $ACTION_NAME =="
    return 0
}

# Called automatically when a script exits before finish_action.
action_abort() {
    if [ "${ACTION_DONE:-0}" != "1" ]; then
        status_set busy 0
        status_set message "Action ended unexpectedly"
    fi
    lock_release
}

# Successful completion.
finish_action() {
    status_set busy 0
    status_set progress 100
    ACTION_DONE=1
    lock_release
}

# Friendly failure: records the reason, releases the lock and exits.
fail_action() {
    log "ERROR: $*"
    status_set busy 0
    status_set message "Error: $*"
    ACTION_DONE=1
    lock_release
    exit 1
}

detect_arch() {
    if [ -n "$ALPINE_ARCH" ]; then
        echo "$ALPINE_ARCH"
        return
    fi
    case "$(uname -m)" in
        armv7l)
            # Kindle firmware either uses the hard-float or the soft-float ABI.
            if [ -e /lib/ld-linux-armhf.so.3 ]; then
                echo armhf
            else
                echo armv7
            fi
            ;;
        *)
            uname -m
            ;;
    esac
}

require_image() {
    if [ ! -f "$DATA_DIR/alpine.ext4" ]; then
        fail_action "Alpine is not installed. Deploy it first."
    fi
}

require_kterm() {
    if [ -z "$(find_kterm)" ]; then
        fail_action "kterm is not installed. Install kterm (or KPM) to open a terminal."
    fi
}

utild_running() {
    lipc-get-prop com.kindlemodding.utild info >/dev/null 2>&1
}

# Registers the Mesquite application in appreg.db. The app files must already
# have been copied to MESQUITE_DIR.
MESQUITE_DIR="${ALPINE_MESQUITE_DIR:-/var/local/mesquite/alpine_kindle}"
APPREG_DB="${ALPINE_APPREG_DB:-/var/local/appreg.db}"

register_app_db() {
    sqlite3 "$APPREG_DB" <<EOF
INSERT OR IGNORE INTO interfaces(interface) VALUES('application');

INSERT OR IGNORE INTO handlerIds(handlerId) VALUES('$APP_ID');

INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','lipcId','$APP_ID');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','command','/usr/bin/mesquite -l $APP_ID -c file://$MESQUITE_DIR/');
INSERT OR REPLACE INTO properties(handlerId,name,value)
  VALUES('$APP_ID','supportedOrientation','U');
EOF
}

launch_app() {
    nohup lipc-set-prop com.lab126.appmgrd start "app://$APP_ID" >/dev/null 2>&1 &
}

# Refresh the hardware/data fields in the status file. Does not change
# busy/action/message, so it is safe to call while an action is running.
probe_status() {
    ensure_state_dir

    status_set app_version "$APP_VERSION"
    status_set arch "$(detect_arch)"

    if [ -n "$(find_kterm)" ]; then
        status_set kterm 1
    else
        status_set kterm 0
    fi

    if [ -n "$(find_kpm)" ]; then
        status_set kpm 1
    else
        status_set kpm 0
    fi

    if [ -f "$DATA_DIR/alpine.ext4" ]; then
        status_set alpine 1
    else
        status_set alpine 0
    fi

    if [ -f "$DATA_DIR/home.ext4" ]; then
        status_set home 1
    else
        status_set home 0
    fi

    if mount 2>/dev/null | grep -q "/tmp/alpine"; then
        status_set running 1
    else
        status_set running 0
    fi

    if utild_running; then
        status_set utild 1
        _info="$(lipc-get-prop com.kindlemodding.utild info 2>/dev/null | head -n 1)"
        status_set utild_info "$_info"
    else
        status_set utild 0
        status_set utild_info "not running"
    fi

    if [ -d /mnt/us/extensions/alpine_kindle ] || [ -f /mnt/us/documents/Alpine.sh ]; then
        status_set kual 1
    else
        status_set kual 0
    fi

    _free="$(df -m "$DATA_DIR" 2>/dev/null | awk 'NR==2 {print $4}')"
    status_set free_mb "${_free:-unknown}"
    status_set last_probe "$(date '+%Y-%m-%d %H:%M')"
}
