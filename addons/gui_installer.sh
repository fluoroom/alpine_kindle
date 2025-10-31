#!/bin/sh

read -p "Do you want to install an environment? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] ; then
    echo "Installation cancelled."
    exit 0
fi
read -p "Choose environment to install - XFCE (x) LXQT (l) MATE (m): " ENVCHOICE
if [ "$ENVCHOICE" = "l" ] ; then
    GUI_TYPE="lxqt"
elif [ "$ENVCHOICE" = "x" ] ; then
    GUI_TYPE="xfce"
elif [ "$ENVCHOICE" = "m" ] ; then
    GUI_TYPE="mate"
else
    echo "Invalid choice. Installation cancelled."
    exit 1
fi
echo ""
echo "=== Starting $GUI_TYPE Installation for Kindle ==="
echo ""
/usr/local/bin/gui_install_$GUI_TYPE.sh
echo ""
echo "=== $GUI_TYPE Installation Script Finished ==="
echo ""
read -p "Press any key to continue..."
exit 0