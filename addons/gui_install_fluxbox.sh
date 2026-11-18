#!/bin/sh
# Installs Fluxbox inside Alpine. Runs in the chroot, invoked by gui_installer.

# Force update package lists
echo "Updating package repositories..."
apk update

# Source base GUI packages
. /usr/local/bin/base_gui_packages.sh

# Fluxbox is deliberately small: a window manager, a terminal and a couple of
# lightweight browsers (the browsers come from base_gui_packages.sh).
GUI_PACKAGES="
    fluxbox
    xterm
"

PACKAGES="$BASE_GUI_PACKAGES $GUI_PACKAGES"

echo "Installing Fluxbox desktop environment..."
echo "Package list: $PACKAGES"

# Install packages (apk will automatically skip already installed ones)
if apk add $PACKAGES; then
    echo "✓ Successfully installed Fluxbox desktop packages"
else
    echo "✗ Some packages failed to install. Trying individual installation..."
    for pkg in $PACKAGES; do
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

# Create a small Fluxbox menu and configuration so the first session is usable
# without a keyboard/mouse setup step.
ALPINE_HOME="/home/alpine"
if [ -d "$ALPINE_HOME" ]; then
    echo "Setting up Fluxbox configuration..."

    mkdir -p "$ALPINE_HOME/.fluxbox"

    cat > "$ALPINE_HOME/.fluxbox/menu" <<'EOF'
[begin] (Fluxbox)
  [exec] (Terminal) {xterm} <f1>
  [exec] (Dillo browser) {dillo} <f2>
  [exec] (Vimb browser) {vimb} <f3>
  [separator]
  [exit] (Exit Fluxbox)
[end]
EOF

    cat > "$ALPINE_HOME/.fluxbox/init" <<'EOF'
session.screen0.workspaces: 1
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: BottomCenter
session.screen0.focusModel: ClickToFocus
session.screen0.autoRaise: true
EOF

    chown -R alpine:alpine "$ALPINE_HOME/.fluxbox"
    echo "✓ Fluxbox configuration created"
fi

echo ""
echo "=== Fluxbox Installation Complete for Kindle ==="
echo "GUI packages installed and configured for Xephyr environment."
echo "Use the Fluxbox desktop button to start the session."
echo ""
echo "User credentials: alpine / alpine"

echo "Installed Fluxbox desktop environment successfully."
