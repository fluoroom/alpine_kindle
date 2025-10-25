#!/bin/sh

# Force update package lists
echo "Updating package repositories..."
apk update

# Define essential packages for a minimal Fluxbox desktop on Kindle
PACKAGES="
    xorg-server
    xorg-server-xephyr
    xinit
    xwininfo
    fluxbox
    xterm
    dbus
    sudo
    bash
    nano
    firefox-esr
    ttf-dejavu
"

echo "Installing Fluxbox desktop environment..."
echo "Package list: $PACKAGES"

# Install packages (apk will automatically skip already installed ones)
if apk add --no-cache $PACKAGES; then
    echo "✓ Successfully installed Fluxbox desktop packages"
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

# Create basic Fluxbox configuration
ALPINE_HOME="/home/alpine"
if [ -d "$ALPINE_HOME" ]; then
    echo "Setting up Fluxbox configuration..."
    
    # Create .fluxbox directory
    mkdir -p "$ALPINE_HOME/.fluxbox"
    
    # Create a basic startup script for applications to run with Fluxbox
    cat > "$ALPINE_HOME/.fluxbox/startup" << 'EOF'
#!/bin/sh
# Fluxbox startup script for Kindle

# Start a terminal in the background for easy access
xterm &

# Keep Fluxbox running
exec fluxbox
EOF
    
    # Make startup script executable
    chmod +x "$ALPINE_HOME/.fluxbox/startup"
    
    # Create .xinitrc for the alpine user (for use with startx)
    cat > "$ALPINE_HOME/.xinitrc" << 'EOF'
#!/bin/sh
# X11 startup script for Kindle

# Start Fluxbox (dbus will be handled by the parent script)
exec fluxbox
EOF
    
    chmod +x "$ALPINE_HOME/.xinitrc"
    
    # Set ownership to alpine user
    chown -R alpine:alpine "$ALPINE_HOME/.fluxbox" "$ALPINE_HOME/.xinitrc"
    
    echo "✓ Fluxbox configuration created"
fi

echo ""
echo "=== Fluxbox Installation Complete for Kindle ==="
echo "GUI packages installed and configured for Xephyr environment."
echo "Use the 'gui' script to start the desktop environment."
echo ""
echo "User credentials: alpine / alpine"