#!/bin/sh

# Force update package lists
echo "Updating package repositories..."
apk update

# Source base GUI packages
. /usr/local/bin/base_gui_packages.sh

# Define GUI-specific packages
GUI_PACKAGES="
    lxqt-session
    lxqt-desktop
    lximage-qt
    pavucontrol-qt
    font-dejavu
    arandr
    obconf-qt
    screengrab
    sddm
    adwaita-qt
    oxygen
    lxqt-policykit
    lxqt-panel
    lxqt-config
    lxqt-globalkeys
    lxqt-notificationd
    lxqt-runner
    pcmanfm-qt
    qterminal
    pulseaudio-ctl
"

# Combine base and GUI-specific packages
PACKAGES="$BASE_GUI_PACKAGES $GUI_PACKAGES"

echo "Installing LXQt desktop environment..."
echo "Package list: $PACKAGES"

# Install packages (apk will automatically skip already installed ones)
if apk add $PACKAGES; then
    echo "✓ Successfully installed LXQt desktop packages"
else
    echo "✗ Some packages failed to install. Trying individual installation..."
    for pkg in $PACKAGES; do
        # Skip empty lines
        [ -z "$pkg" ] && continue
        
        echo "Installing $pkg..."
        if ! apk add --no-cache "$pkg"; then
            echo "  ✗ Failed to install $pkg"
        else
            echo "  ✓ Installed $pkg"
        fi
    done
fi

# Create a new user 'alpine' if it doesn't already exist
if ! id -u alpine >/dev/null 2>&1; then
    echo "Creating user 'alpine'..."
    adduser -D alpine
    echo "alpine:alpine" | chpasswd
    adduser alpine wheel
    
    # Configure sudo access for wheel group
    if ! grep -q "^%wheel" /etc/sudoers; then
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    echo "✓ User 'alpine' created with sudo access"
else
    echo "✓ User 'alpine' already exists"
fi

# Create basic LXQt configuration
ALPINE_HOME="/home/alpine"
if [ -d "$ALPINE_HOME" ]; then
    echo "Setting up LXQt configuration..."
    
    # Create basic LXQt config directory
    mkdir -p "$ALPINE_HOME/.config/lxqt"
    
    # Set ownership to alpine user
    chown -R alpine:alpine "$ALPINE_HOME/.config"
    
    echo "✓ LXQt configuration created"
fi

echo ""
echo "=== LXQt Installation Complete for Kindle ==="
echo "GUI packages installed and configured for Xephyr environment."
echo "Use the 'gui' script to start the desktop environment."
echo ""
echo "User credentials: alpine / alpine"

# Copy the gui script
cp ./addons/gui_lxqt.sh "$MOUNT_POINT/usr/local/bin/gui"
chmod +x "$MOUNT_POINT/usr/local/bin/gui"
echo "Copied gui script to image."