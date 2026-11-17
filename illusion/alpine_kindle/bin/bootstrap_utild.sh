#!/bin/sh
# Makes sure Utild (the LIPC command runner used by the Illusion UI) is
# available and running.
#
# Utild is not bundled with this project. If it is not already installed,
# this script downloads a pinned, checksum-verified build from the
# KindleForge project (GPL-3.0). See THIRD_PARTY_NOTICES.md.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

UTILD_DIR="/var/local/kmc"
UTILD_BIN="$UTILD_DIR/utild"
UTILD_REPO="https://raw.githubusercontent.com/KindleTweaks/KindleForge/64c8e264a01277f622c32340bc448c4f1f0e7822/KindleForge/KindleForge/binaries"

# Reported by lipc-get-prop; also keeps the UI honest.
report() {
    if utild_running; then
        status_set utild 1
        status_set utild_info "$(lipc-get-prop com.kindlemodding.utild info 2>/dev/null | head -n 1)"
        return 0
    fi
    status_set utild 0
    status_set utild_info "$1"
    return 1
}

start_utild() {
    _bin="$1"
    [ -x "$_bin" ] || return 1

    # The daemon detaches itself, so this returns almost immediately.
    "$_bin" >/dev/null 2>&1 &

    _i=0
    while [ "$_i" -lt 5 ]; do
        sleep 1
        if utild_running; then
            return 0
        fi
        _i=$((_i + 1))
    done
    return 1
}

# 1. Already running? Nothing to do.
if utild_running; then
    log "Utild already running."
    report "running"
    exit 0
fi

# 2. Try the copies that KindleForge or a previous run left behind.
for candidate in \
    "$UTILD_BIN" \
    "$UTILD_DIR/UtildHF" \
    "$UTILD_DIR/UtildSF" \
    /mnt/us/documents/KindleForge/binaries/UtildHF \
    /mnt/us/documents/KindleForge/binaries/UtildSF \
    "$DATA_DIR/utild/utild-hf" \
    "$DATA_DIR/utild/utild-sf" \
    "$DATA_DIR/utild/utild" \
    "$APP_DIR/bin/runtime/utild-hf" \
    "$APP_DIR/bin/runtime/utild-sf"
do
    if [ -x "$candidate" ]; then
        log "Starting Utild from $candidate"
        if start_utild "$candidate"; then
            # Keep a stable path for future launches.
            if [ "$candidate" != "$UTILD_BIN" ]; then
                cp "$candidate" "$UTILD_BIN" 2>/dev/null && chmod +x "$UTILD_BIN" 2>/dev/null || true
            fi
            log "Utild started."
            report "running"
            exit 0
        fi
    fi
done

# 3. Download the right ABI build.
if [ -e /lib/ld-linux-armhf.so.3 ]; then
    UTILD_FILE="UtildHF"
    UTILD_SHA="c939d37262ac7b324e8deaa463a9c8152e7ceb55004f01e0511005c8661854d9"
else
    UTILD_FILE="UtildSF"
    UTILD_SHA="a8a44e0f6c7f4869d0574197df9a304dbd25035d6fc45156f7431bcb8d72a9f8"
fi

mkdir -p "$UTILD_DIR" 2>/dev/null || true

if [ ! -d "$UTILD_DIR" ]; then
    log "ERROR: Cannot write to $UTILD_DIR."
    report "cannot write to $UTILD_DIR"
    exit 1
fi

log "Downloading Utild ($UTILD_FILE)..."
status_set message "Downloading terminal runtime..."

_tmp="$UTILD_DIR/$UTILD_FILE.download.$$"
_url="$UTILD_REPO/$UTILD_FILE"

if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 2 --connect-timeout 20 -o "$_tmp" "$_url" >/dev/null 2>&1
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$_tmp" "$_url" >/dev/null 2>&1
else
    log "ERROR: Neither curl nor wget is available; cannot download Utild."
    report "curl/wget missing"
    exit 1
fi

if [ ! -s "$_tmp" ]; then
    rm -f "$_tmp" 2>/dev/null || true
    log "ERROR: Could not download Utild. Connect Wi-Fi and open Alpine Linux again."
    report "download failed (connect Wi-Fi and retry)"
    exit 1
fi

# Verify the pinned build. If sha256sum is unavailable we still refuse an
# empty file (checked above), but warn instead of silently trusting it.
if command -v sha256sum >/dev/null 2>&1; then
    _actual="$(sha256sum "$_tmp" 2>/dev/null | cut -d ' ' -f 1)"
    if [ "$_actual" != "$UTILD_SHA" ]; then
        rm -f "$_tmp" 2>/dev/null || true
        log "ERROR: Utild checksum mismatch (got $_actual)."
        report "runtime checksum mismatch"
        exit 1
    fi
else
    log "WARNING: sha256sum not available; skipping Utild checksum."
fi

mv "$_tmp" "$UTILD_BIN" || {
    rm -f "$_tmp" 2>/dev/null || true
    log "ERROR: Could not install Utild to $UTILD_BIN."
    report "install failed"
    exit 1
}
chmod +x "$UTILD_BIN" 2>/dev/null || true

log "Starting Utild..."
if start_utild "$UTILD_BIN"; then
    log "Utild started."
    report "running"
    exit 0
fi

log "ERROR: Utild was installed but did not start."
report "failed to start"
exit 1
