#!/bin/sh

# Force update package lists
echo "Updating package repositories..."
apk update

# Source base GUI packages
. /usr/local/bin/base_gui_packages.sh

# Define GUI-specific packages
GUI_PACKAGES="
    mate
    mate-desktop
    mate-session-manager
    caja
    marco
    mate-terminal
    mate-panel
    atril
    pluma
    mate-control-center
    mate-power-manager
    mate-screensaver
    mate-notification-daemon
"

# Combine base and GUI-specific packages
PACKAGES="$BASE_GUI_PACKAGES $GUI_PACKAGES"

echo "Installing Mate desktop environment..."
echo "Package list: $PACKAGES"

# Install packages (apk will automatically skip already installed ones)
if apk add $PACKAGES; then
    echo "✓ Successfully installed Mate desktop packages"
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

# Create basic MATE configuration
ALPINE_HOME="/home/alpine"
if [ -d "$ALPINE_HOME" ]; then
    echo "Setting up MATE configuration..."
    
    # Create basic MATE config directory
    mkdir -p "$ALPINE_HOME/.config/mate"
    
    # Set ownership to alpine user
    chown -R alpine:alpine "$ALPINE_HOME/.config"
    
    echo "✓ MATE configuration created"
fi

echo ""
echo "=== MATE Installation Complete for Kindle ==="
echo "GUI packages installed and configured for Xephyr environment."
echo "Use the 'gui_mate' script to start the desktop environment."
echo ""
echo "User credentials: alpine / alpine"

# Copy the gui script
cp ./addons/gui_mate.sh "$MOUNT_POINT/usr/local/bin/gui_mate"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_mate"
echo "Copied gui script to image."