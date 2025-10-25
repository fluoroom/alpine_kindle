#!/bin/sh

# This script can only be run as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Install GUI packages
/usr/local/bin/gui_install

# Make dang sure Xephyr isn't already running
if [ "$(pgrep Xephyr)" ] ; then
    echo "Xephyr is already running. Killing it..."
    kill $(pgrep Xephyr)
    sleep 2
fi

WINDOW_GEOMETRY=$(xwininfo -root -display :0 | egrep "geometry" | cut -d " "  -f4)
DISPLAY=:0 Xephyr :1 -title "L:D_N:application_ID:xephyr" -ac -br -screen $WINDOW_GEOMETRY -cc 4 -reset -terminate &
sleep 2

# Drop into the Alpine user session
su - alpine -c "
export DISPLAY=:1

# MATE settings commented out for Phosh 
# if [ ! -f /home/alpine/.runonce ]; then
#     echo 'Running first-time setup...'
#     touch /home/alpine/.runonce
#     gsettings set org.mate.interface window-scaling-factor 2
#     gsettings set org.mate.interface window-scaling-factor-qt-sync true

#     sleep 2
# fi

dbus-run-session phosh-session
" > /dev/null 2>&1

# Cleanup:
echo "Killing Xephyr..."
kill $(pgrep Xephyr)
sleep 2
