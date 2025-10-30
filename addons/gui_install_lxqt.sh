#!/bin/sh

# Force update package lists
echo "Updating package repositories..."
apk update

# Define essential packages for LXQt desktop on Kindle
PACKAGES="
    xorg-server-xephyr
    xinit
    xwininfo
    lxqt-desktop
    lximage-qt
    pavucontrol-qt
    font-dejavu
    arandr
    obconf-qt
    screengrab
    sddm
    adwaita-qt
    breeze
    oxygen
    lxqt-policykit
    dbus
    sudo
    bash
    nano
    onboard
    dillo
    vimb
"

echo "Installing LXQt desktop environment..."
echo "Package list: $PACKAGES"

# Install packages (apk will automatically skip already installed ones)
if apk add --no-cache $PACKAGES; then
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
    
    # Create .xinitrc for the alpine user (for use with startx)
    cat > "$ALPINE_HOME/.xinitrc" << 'EOF'
#!/bin/sh
# X11 startup script for LXQt on Kindle

# Start LXQt session (dbus will be handled by the parent script)
exec startlxqt
EOF
    
    chmod +x "$ALPINE_HOME/.xinitrc"
    
    # Create basic LXQt config directory
    mkdir -p "$ALPINE_HOME/.config/lxqt"
    
    # Set ownership to alpine user
    chown -R alpine:alpine "$ALPINE_HOME/.xinitrc" "$ALPINE_HOME/.config"
    
    echo "✓ LXQt configuration created"
fi

echo ""
echo "=== LXQt Installation Complete for Kindle ==="
echo "GUI packages installed and configured for Xephyr environment."
echo "Use the 'gui' script to start the desktop environment."
echo ""
echo "User credentials: alpine / alpine"

# Copy the gui script
cp ./addons/gui_lxqt.sh "$MOUNT_POINT/usr/local/bin/gui_lxqt"
chmod +x "$MOUNT_POINT/usr/local/bin/gui_lxqt"
echo "Copied gui script to image."