#!/bin/sh

# Define base required packages
BASE_PACKAGES="xorg-server-xephyr xwininfo xdotool xinput dbus-x11 sudo bash nano git seatd xdg-desktop-portal-phosh phosh-wallpapers phosh-mobile-settings squeekboard phoc phosh-portalsconf phosh-mobile-settings-lang phosh-lang libphosh desktop-file-utils gtk-engines consolekit gtk-murrine-engine caja caja-extensions marco onboard chromium"

# Add all phosh-related packages (excluding dev, lang, doc)
PHOSH_PACKAGES=$(apk search phosh -q | grep -v '\-dev' | grep -v '\-lang' | grep -v '\-doc')

# Add all TTF font packages (excluding doc)
FONT_PACKAGES=$(apk search -q ttf- | grep -v '\-doc')

# Combine all packages
PACKAGES="$BASE_PACKAGES $PHOSH_PACKAGES $FONT_PACKAGES"

# Check which packages are missing and install only those
MISSING_PACKAGES=""
for pkg in $PACKAGES; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
    fi
done

# Install missing packages if any
if [ -n "$MISSING_PACKAGES" ]; then
    echo "Installing missing packages:$MISSING_PACKAGES"
    apk add --no-cache $MISSING_PACKAGES
else
    echo "All required packages are already installed."
fi

# Create a new user 'alpine' if it doesn't already exist
if ! id -u alpine >/dev/null 2>&1; then
    adduser -D alpine
    echo "alpine:alpine" | chpasswd
    adduser alpine wheel
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi