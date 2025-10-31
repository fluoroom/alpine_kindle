#!/bin/sh

# This script will run in the context of the chrooted environment 
# so you can install extra stuff easily here.

apk add --no-cache vim git curl htop sudo bash nano
echo "✓ Successfully installed base packages"
