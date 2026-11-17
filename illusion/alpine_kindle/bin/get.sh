#!/bin/sh
# Downloads and installs an Alpine root filesystem image.
#
# Usage: get.sh [--release|--nightly] [--yes]
#
# --yes is passed by the Illusion UI (which already asked for confirmation).

SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/common.sh"

NIGHTLY=0
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --nightly) NIGHTLY=1 ;;
        --release) NIGHTLY=0 ;;
        --yes|-y) ASSUME_YES=1 ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

if [ "$NIGHTLY" = "1" ]; then
    CHANNEL="nightly"
    ACTION_LABEL="Deploy Alpine (nightly)"
else
    CHANNEL="release"
    ACTION_LABEL="Deploy Alpine (release)"
fi

begin_action "$ACTION_LABEL" || exit 1
trim_log

log "Channel: $CHANNEL"
log "Architecture: $(detect_arch)"

if [ "$ASSUME_YES" != "1" ]; then
    printf "Download and install the latest %s build of Alpine Linux for Kindle? (y/N): " "$CHANNEL"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log "Installation cancelled."
        status_set message "Installation cancelled"
        finish_action
        exit 0
    fi
fi

if [ -f "$DATA_DIR/alpine.ext4" ]; then
    fail_action "Alpine is already installed. Delete the root filesystem first."
fi

mkdir -p "$DATA_DIR" || fail_action "Could not create $DATA_DIR"

ARCH="$(detect_arch)"
case "$ARCH" in
    armhf) IMAGE_ARCH="armhf" ;;
    armv7) IMAGE_ARCH="armv7" ;;
    *)
        fail_action "Unsupported architecture: $ARCH"
        ;;
esac

if [ "$NIGHTLY" = "1" ]; then
    URL="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs-nightly.yaml/pw6/alpine-rootfs-nightly-${IMAGE_ARCH}.zip"
else
    URL="https://nightly.link/fluoroom/alpine_kindle/workflows/create-rootfs.yaml/pw6/alpine-rootfs-${IMAGE_ARCH}.zip"
fi

cd "$DATA_DIR" || fail_action "Could not enter $DATA_DIR"

ZIP="$DATA_DIR/alpine.zip"
rm -f "$ZIP" 2>/dev/null || true

log "Downloading $URL"
status_set message "Downloading Alpine ($IMAGE_ARCH, $CHANNEL)..."
status_set progress 10

if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$ZIP" "$URL"; then
        rm -f "$ZIP" 2>/dev/null || true
        fail_action "Download failed. Check Wi-Fi and try again."
    fi
elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "$ZIP" "$URL"; then
        rm -f "$ZIP" 2>/dev/null || true
        fail_action "Download failed. Check Wi-Fi and try again."
    fi
else
    fail_action "Neither curl nor wget is available."
fi

if [ ! -s "$ZIP" ]; then
    rm -f "$ZIP" 2>/dev/null || true
    fail_action "Downloaded file is empty."
fi

log "Extracting Alpine image..."
status_set message "Extracting Alpine image..."
status_set progress 55

if ! unzip -o "$ZIP" >/dev/null 2>&1; then
    rm -f "$ZIP" 2>/dev/null || true
    fail_action "Could not unzip the Alpine image (corrupt download?)."
fi
rm -f "$ZIP" 2>/dev/null || true

if [ ! -f "$DATA_DIR/alpine.ext4" ]; then
    fail_action "Archive did not contain alpine.ext4."
fi

# alpine.conf is a legacy upstart unit and is no longer installed. The
# Illusion app launches Alpine directly, so only alpine.sh is needed here.

probe_status
status_set message "Alpine $CHANNEL installed successfully"
status_set progress 100
finish_action

log "Alpine installed."
log "Tap 'Alpine shell' to start it, or 'GUI Installer' to install XFCE."
exit 0
