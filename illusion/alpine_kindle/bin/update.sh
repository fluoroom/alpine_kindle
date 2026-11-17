#!/bin/sh
# Updates the Alpine Linux Illusion app to the latest GitHub release.
#
# The script replaces only the launcher (documents/alpine_kindle and
# documents/alpine_kindle.sh). The Alpine images in /mnt/us/alpine are left
# untouched.

# Replace the running copy of this script before the app directory is swapped,
# otherwise ash may read a half-replaced file.
if [ "$1" != "--detached" ]; then
    cp "$0" /tmp/alpine_kindle_update.sh 2>/dev/null || {
        echo "Could not copy updater to /tmp" >&2
        exit 1
    }
    exec sh /tmp/alpine_kindle_update.sh --detached
fi

SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    . "$SCRIPT_DIR/common.sh"
else
    . "${ALPINE_APP_DIR:-/mnt/us/documents/alpine_kindle}/bin/common.sh"
fi

REPO="fluoroom/alpine_kindle"
DOCS_DIR="${ALPINE_DOCS_DIR:-/mnt/us/documents}"
TMP_DIR="/tmp/alpine_kindle_update"
NEW_DIR="$DOCS_DIR/.alpine_kindle.new"
OLD_DIR="$DOCS_DIR/.alpine_kindle.old"
NEW_SCRIPT="$DOCS_DIR/.alpine_kindle.sh.new"

begin_action "Update Alpine Linux app" || exit 1
trim_log

rm -rf "$TMP_DIR" "$NEW_DIR" 2>/dev/null || true
mkdir -p "$TMP_DIR" || fail_action "Could not create temporary directory."

API_URL="https://api.github.com/repos/$REPO/releases/latest"
ZIP_URL=""

status_set message "Checking for the latest release..."
log "Fetching latest release information..."

if command -v curl >/dev/null 2>&1; then
    RELEASE_JSON="$(curl -fsSL -H 'User-Agent: alpine-kindle' "$API_URL" 2>/dev/null)"
elif command -v wget >/dev/null 2>&1; then
    RELEASE_JSON="$(wget -qO- --header='User-Agent: alpine-kindle' "$API_URL" 2>/dev/null)"
else
    fail_action "Neither curl nor wget is available."
fi

if [ -n "$RELEASE_JSON" ]; then
    ZIP_URL="$(printf '%s\n' "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.zip"' | head -n 1 | cut -d '"' -f 4)"
fi

if [ -z "$ZIP_URL" ]; then
    fail_action "Could not find a release ZIP. Check Wi-Fi and try again."
fi

log "Downloading $ZIP_URL"
status_set message "Downloading update..."
status_set progress 25

if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 2 --connect-timeout 20 -o "$TMP_DIR/update.zip" "$ZIP_URL" >/dev/null 2>&1 || fail_action "Download failed."
else
    wget -q -O "$TMP_DIR/update.zip" "$ZIP_URL" || fail_action "Download failed."
fi

status_set message "Extracting update..."
status_set progress 50

unzip -o "$TMP_DIR/update.zip" -d "$TMP_DIR" >/dev/null 2>&1 || fail_action "Could not unzip the update."

if [ ! -d "$TMP_DIR/alpine_kindle" ] || [ ! -f "$TMP_DIR/alpine_kindle/config.xml" ]; then
    fail_action "Release ZIP has an unexpected layout (missing alpine_kindle/)."
fi

if [ ! -f "$TMP_DIR/alpine_kindle.sh" ]; then
    fail_action "Release ZIP has an unexpected layout (missing alpine_kindle.sh)."
fi

if [ ! -f "$TMP_DIR/alpine_kindle/index.html" ]; then
    fail_action "Release ZIP has an unexpected layout (missing index.html)."
fi

NEW_ID="$(sed -n 's/.*<widget[^>]*id="\([^"]*\)".*/\1/p' "$TMP_DIR/alpine_kindle/config.xml" 2>/dev/null | head -n 1)"
if [ -n "$NEW_ID" ] && [ "$NEW_ID" != "$APP_ID" ]; then
    fail_action "Release app ID ($NEW_ID) does not match $APP_ID."
fi

NEW_VERSION="$(sed -n 's/.*<widget[^>]*version="\([^"]*\)".*/\1/p' "$TMP_DIR/alpine_kindle/config.xml" 2>/dev/null | head -n 1)"
[ -n "$NEW_VERSION" ] || NEW_VERSION="unknown"

status_set message "Installing version $NEW_VERSION..."
status_set progress 70

# Stage the new app next to the old one (same filesystem, atomic rename).
cp -a "$TMP_DIR/alpine_kindle" "$NEW_DIR" || fail_action "Could not stage the new app."
cp "$TMP_DIR/alpine_kindle.sh" "$NEW_SCRIPT" || fail_action "Could not stage the new scriptlet."

rm -rf "$OLD_DIR" 2>/dev/null || true
if [ -d "$APP_DIR" ]; then
    mv "$APP_DIR" "$OLD_DIR" || fail_action "Could not move the old app out of the way."
fi
if ! mv "$NEW_DIR" "$APP_DIR"; then
    [ -d "$OLD_DIR" ] && mv "$OLD_DIR" "$APP_DIR"
    fail_action "Could not install the new app."
fi

if ! mv "$NEW_SCRIPT" "$DOCS_DIR/alpine_kindle.sh"; then
    log "WARNING: Could not replace alpine_kindle.sh; copy it manually."
fi
rm -rf "$OLD_DIR" 2>/dev/null || true

# Refresh the running Mesquite copy as well, so a reload picks up the update.
status_set message "Refreshing Mesquite app..."
status_set progress 85

rm -rf "$MESQUITE_DIR" 2>/dev/null || true
mkdir -p "$MESQUITE_DIR" 2>/dev/null || true
if cp -a "$APP_DIR/." "$MESQUITE_DIR/" 2>/dev/null; then
    register_app_db 2>/dev/null || log "WARNING: Could not update appreg.db."
else
    log "WARNING: Could not refresh $MESQUITE_DIR."
fi

probe_status
status_set app_version "$NEW_VERSION"
status_set updated 1
status_set message "Updated to $NEW_VERSION. Tap Reload."
status_set progress 100
finish_action

rm -rf "$TMP_DIR" 2>/dev/null || true
log "Updated to version $NEW_VERSION."
log "Tap Reload in the app (or reopen it from your library)."
exit 0
