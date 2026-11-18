#!/bin/sh

read -p "Do you want to install an environment? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] ; then
    echo "Installation cancelled."
    exit 0
fi
read -p "Choose environment to install - XFCE (x), Fluxbox (f): " ENVCHOICE
case "$ENVCHOICE" in
    x|X) GUI_TYPE="xfce" ;;
    f|F) GUI_TYPE="fluxbox" ;;
    *)
        echo "Invalid choice. Installation cancelled."
        exit 1
        ;;
esac
echo ""
echo "=== Starting $GUI_TYPE Installation for Kindle ==="
echo ""
/usr/local/bin/gui_install_$GUI_TYPE
echo ""
echo "=== $GUI_TYPE Installation Script Finished ==="
echo ""
read -p "Press any key to continue..."
exit 0