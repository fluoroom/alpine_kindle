#!/bin/sh

# This script will run in the context of the chrooted environment 
# so you can install extra stuff easily here.

# busybox already ships `top`, so there is no package with that name.
apk add --no-cache vim git curl htop tmux fish sudo bash nano fastfetch
echo "✓ Successfully installed base packages"
