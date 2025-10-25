#!/bin/sh

# Force update package lists
echo "Updating package repositories..."
apk update

# Function to check if a package exists in repositories
package_exists() {
    apk search -q "$1" | grep -q "^$1-[0-9]"
}

# Function to add package to list if it exists
add_if_exists() {
    local pkg="$1"
    local list_var="$2"
    
    if package_exists "$pkg"; then
        eval "$list_var=\"\$$list_var $pkg\""
    else
        echo "Package '$pkg' not found in repositories, skipping..."
    fi
}

# Initialize package lists
CORE_PACKAGES=""
GUI_PACKAGES=""
BROWSER_PACKAGES=""
PHOSH_PACKAGES=""
FONT_PACKAGES=""

# Core system packages (most likely to exist)
for pkg in xorg-server-xephyr xwininfo xdotool xinput dbus-x11 sudo bash nano git desktop-file-utils gtk-engines; do
    add_if_exists "$pkg" "CORE_PACKAGES"
done

# GUI/Desktop packages
for pkg in seatd gtk-murrine-engine caja caja-extensions marco onboard; do
    add_if_exists "$pkg" "GUI_PACKAGES"
done

# Browser alternatives (try multiple options)
for pkg in firefox-esr chromium midori epiphany; do
    add_if_exists "$pkg" "BROWSER_PACKAGES"
    [ -n "$BROWSER_PACKAGES" ] && break  # Use first available browser
done

# Phosh packages (mobile desktop environment)
for pkg in phosh phoc squeekboard phosh-wallpapers; do
    add_if_exists "$pkg" "PHOSH_PACKAGES"
done

# Try to add desktop portal packages
for pkg in xdg-desktop-portal xdg-desktop-portal-gtk; do
    add_if_exists "$pkg" "GUI_PACKAGES"
done

# Add available phosh-related packages dynamically
echo "Searching for additional phosh packages..."
for pkg in $(apk search phosh -q | grep -v '\-dev' | grep -v '\-doc' | cut -d'-' -f1-2 | sort -u); do
    if [ -n "$pkg" ] && package_exists "$pkg"; then
        case "$PHOSH_PACKAGES" in
            *"$pkg"*) ;;  # Already added
            *) PHOSH_PACKAGES="$PHOSH_PACKAGES $pkg" ;;
        esac
    fi
done

# Add some essential TTF fonts (not all, to avoid overwhelming the system)
echo "Adding essential font packages..."
for pkg in ttf-dejavu ttf-liberation ttf-opensans; do
    add_if_exists "$pkg" "FONT_PACKAGES"
done

# Combine all packages
ALL_PACKAGES="$CORE_PACKAGES $GUI_PACKAGES $BROWSER_PACKAGES $PHOSH_PACKAGES $FONT_PACKAGES"

# Clean up the package list (remove duplicates and empty entries)
PACKAGES=$(echo $ALL_PACKAGES | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')

echo "Final package list: $PACKAGES"

# Check which packages are not installed and install only those
MISSING_PACKAGES=""
for pkg in $PACKAGES; do
    if ! apk info -e "$pkg" >/dev/null 2>&1; then
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
    fi
done

# Install missing packages if any
if [ -n "$MISSING_PACKAGES" ]; then
    echo "Installing missing packages:$MISSING_PACKAGES"
    if ! apk add --no-cache $MISSING_PACKAGES; then
        echo "Some packages failed to install. Trying to install them individually..."
        for pkg in $MISSING_PACKAGES; do
            echo "Installing $pkg..."
            if ! apk add --no-cache "$pkg"; then
                echo "Failed to install $pkg, skipping..."
            fi
        done
    fi
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