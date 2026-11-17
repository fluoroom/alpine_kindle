#!/bin/sh
# Installs fish inside the Alpine image and makes it the default shell for
# root and (if present) the "alpine" user.
#
# Usage: fish.sh [--yes]
#
# Alpine must be stopped; the image is mounted temporarily.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

begin_action "Install fish shell" || exit 1
trim_log
require_image

if mount 2>/dev/null | grep -q "/tmp/alpine"; then
    fail_action "Alpine is running. Stop it before installing fish."
fi

if [ "$ASSUME_YES" != "1" ]; then
    printf "Install fish in Alpine and set it as the default shell? (y/N): "
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log "fish installation cancelled."
        status_set message "fish installation cancelled"
        finish_action
        exit 0
    fi
fi

MOUNT_POINT="/tmp/alpine"
ROOT_MOUNTED=0
DEV_BIND=0
PROC_BIND=0
SYS_BIND=0

cleanup_fish() {
    if [ "$SYS_BIND" = "1" ]; then
        umount "$MOUNT_POINT/sys" 2>/dev/null || true
        SYS_BIND=0
    fi
    if [ "$PROC_BIND" = "1" ]; then
        umount "$MOUNT_POINT/proc" 2>/dev/null || true
        PROC_BIND=0
    fi
    if [ "$DEV_BIND" = "1" ]; then
        umount "$MOUNT_POINT/dev" 2>/dev/null || true
        DEV_BIND=0
    fi
    if [ "$ROOT_MOUNTED" = "1" ]; then
        sync
        umount "$MOUNT_POINT" 2>/dev/null || {
            sleep 2
            umount "$MOUNT_POINT" 2>/dev/null || true
        }
        ROOT_MOUNTED=0
        rmdir "$MOUNT_POINT" 2>/dev/null || true
    fi
}

trap 'cleanup_fish; action_abort' EXIT INT TERM HUP

mkdir -p "$MOUNT_POINT" || fail_action "Could not create $MOUNT_POINT"

status_set message "Mounting Alpine image..."
status_set progress 10
if ! mount -o loop,noatime -t ext4 "$DATA_DIR/alpine.ext4" "$MOUNT_POINT"; then
    fail_action "Could not mount alpine.ext4."
fi
ROOT_MOUNTED=1

mkdir -p "$MOUNT_POINT/dev" "$MOUNT_POINT/proc" "$MOUNT_POINT/sys" "$MOUNT_POINT/etc"
mount -o bind /dev "$MOUNT_POINT/dev" 2>/dev/null && DEV_BIND=1
mount -o bind /proc "$MOUNT_POINT/proc" 2>/dev/null && PROC_BIND=1
mount -o bind /sys "$MOUNT_POINT/sys" 2>/dev/null && SYS_BIND=1

if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf" 2>/dev/null || true
fi

status_set message "Installing fish inside Alpine..."
status_set progress 35

if chroot "$MOUNT_POINT" /bin/sh -c '[ -x /usr/bin/fish ]' 2>/dev/null; then
    log "fish is already installed."
else
    log "Running apk add fish..."
    if ! chroot "$MOUNT_POINT" /bin/sh -c '
        apk update
        apk add --no-cache fish
    ' >> "$LOG_FILE" 2>&1; then
        fail_action "Could not install fish. Check Wi-Fi and the Activity log."
    fi
fi

status_set message "Configuring the default shell..."
status_set progress 70

if ! chroot "$MOUNT_POINT" /bin/sh -c '
    [ -x /usr/bin/fish ] || exit 1

    if ! id -u alpine >/dev/null 2>&1; then
        adduser -D alpine
        echo "alpine:alpine" | chpasswd
        adduser alpine wheel 2>/dev/null || true
        if [ -f /etc/sudoers ] && ! grep -q "^%wheel" /etc/sudoers; then
            echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        fi
    fi

    for u in root alpine; do
        if grep -q "^$u:" /etc/passwd; then
            sed -i "s|^$u:\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):.*|$u:\1:\2:\3:\4:\5:/usr/bin/fish|" /etc/passwd
        fi
    done
' >> "$LOG_FILE" 2>&1; then
    fail_action "fish was installed but the default shell could not be set."
fi

cleanup_fish

# Make sure the deployed mount script knows how to start fish.
if [ -f "$APP_DIR/bin/alpine.sh" ]; then
    cp "$APP_DIR/bin/alpine.sh" "$DATA_DIR/alpine.sh" 2>/dev/null || true
fi

if mount 2>/dev/null | grep -q "/tmp/alpine"; then
    probe_status
    status_set message "fish installed, but Alpine could not be unmounted"
    finish_action
    log "WARNING: /tmp/alpine is still mounted. Use Stop Alpine to clean it up."
    exit 0
fi

probe_status
status_set message "fish installed as the default shell"
finish_action
log "fish installed. Default shell set for root and alpine."
exit 0
