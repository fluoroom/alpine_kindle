# Alpine Linux on Kindle Paperwhite 6 (PW6)

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fluoroom/alpine_kindle/create-rootfs.yaml?branch=pw6)](https://github.com/fluoroom/alpine_kindle/actions)

This fork provides a set of utilities to get [Alpine Linux](https://alpinelinux.org/) running on Kindle Paperwhite 6 and other compatible Kindles with improved stability, better mounting logic, and enhanced features.

This is based on [ohaiibuzzle's alpine_kindle](https://github.com/ohaiibuzzle/alpine_kindle) which itself is a fork of [schuhumi's alpine_kindle](https://github.com/schuhumi/alpine_kindle).

## Overview

Kindles run a Linux operating system with X11 support already on board. To make better use of that, you can utilize a full-blown Linux distribution including a proper desktop environment through chroot. Your Kindle stays fully functional for reading books and buying content.

## Key Features of This Fork (PW6 Branch)

- **Separate Home Partition**: User data and settings are stored in a separate `home.ext4` image for easier backups and clean reinstalls
- **KUAL Extension Enhancements**: 
  - One-click deployment of the latest Alpine release
  - CLI installer for easy XFCE installation
  - Separate delete options for root and home partitions
  - Self-updating extension from GitHub

## ⚠️ CRITICAL WARNING

**WHILE ALPINE IS RUNNING / THE IMAGE IS MOUNTED, DO NOT CONNECT YOUR KINDLE TO THE COMPUTER WITHOUT USBNETWORK ENABLED!**

The Alpine image resides in `/mnt/us`, which is your USB mass storage location. If both Alpine and your computer write to the userstore partition (partition 4) simultaneously, **it will be corrupted**, and you'll need to repair the partition to get your Kindle working again. **In the worst case, this could brick your Kindle!**

KUAL has an option to show the USBNetwork status - always check it before connecting via SSH while Alpine is running.

## Quick Start

### Prerequisites
1. **Jailbroken Kindle** - See [kindlemodding.org](https://kindlemodding.org) for jailbreaking instructions for your specific model and firmware
2. **KUAL Launcher** - See [Post Jailbreak kindlemodding.org](https://kindlemodding.org/jailbreaking/post-jailbreak/installing-kual-mrpi/)
3. **Kterm** - Download from [bfabiszewski's GitHub](https://github.com/bfabiszewski/kterm/releases) (required for running Alpine)
4. **USBNetwork** required if you'll be using your USB cable while running Alpine. Donwload from [MobileRead](https://www.mobileread.com/forums/showthread.php?t=369990)
5. **USBNetwork** or **KOReader** for SSH access (optional but recommended). [Download KOReader](https://github.com/koreader/koreader/releases)

### Installation Steps

1. **Install the KUAL extension**:
   - Download the latest `alpine_kindle-vX.X.X.zip` from the [Releases page](https://github.com/fluoroom/alpine_kindle/releases)
   - Extract the `alpine_kindle` folder to `/mnt/us/extensions/` on your Kindle
   
2. **Deploy Alpine Linux**:
   - Open KUAL on your Kindle
   - Navigate to "Alpine Linux PW6"
   - Select "Deploy newest release (clean install)"
   - Wait for the download and extraction to complete
   
3. **Start using Alpine**:
   - From KUAL, select "Drop into Alpine Linux shell" for command-line access
   - Or select "Start XFCE GUI session" for the graphical desktop (after installing GUI)

### Installing the Desktop Environment

1. From KUAL, select "GUI Installer"
2. Confirm installation (press `y`)
3. Choose XFCE environment (press `x`)
4. Wait for installation to complete
5. Return to KUAL and select "Start XFCE GUI session"

**Default credentials**: 
- Username: `alpine`
- Password: `alpine`

## KUAL Menu Options

- **Deploy newest release (clean install)**: Downloads and installs the latest Alpine rootfs from GitHub Actions
- **Drop into Alpine Linux shell**: Opens a terminal (kterm) shell inside Alpine
- **Start XFCE GUI session**: Launches the XFCE desktop environment
- **GUI Installer**: Interactive installer for desktop environments
- **Stop Alpine**: Safely unmounts Alpine and cleans up loop devices
- **Delete Alpine Linux Root**: Removes the Alpine root filesystem (alpine.ext4)
- **Delete Alpine HOME partition**: Removes HOME filesystem (user data and settings) (home.ext4)
- **Update this KUAL Extension**: Updates the KUAL extension from this GitHub repository

## Architecture

This setup uses:
- **alpine.ext4**: Main Alpine Linux root filesystem (2GB default)
- **home.ext4**: Separate home partition for user data (automatically created on first run)
- **alpine.sh**: Mounting script with improved loop device handling
- **alpine.conf**: Upstart service configuration (currently outdated, use alpine.sh instead)

## Compatibility

Tested on:
- Kindle Paperwhite 6 (PW6)

Should work on any touchscreen Kindle (not Kindle Fire) with:
- At least 2-3GB free space on `/mnt/us`
- At least 512MB RAM
- Touchscreen support

## Troubleshooting

### Alpine won't unmount
The `stop.sh` script includes retry logic. If it still fails:
```bash
# Check what's using Alpine
lsof /tmp/alpine/

# Kill processes manually
kill -9 <PID>

# Try unmounting again
umount /tmp/alpine
```

### Out of space
- Delete large packages you don't need: `apk del <package>`
- Clean package cache: `rm -rf /var/cache/apk/*`
- Create a larger image using `create_minimal_alpine_image.sh` with increased `IMAGESIZE`

### Loop device issues
If you see "no available loop devices":
```bash
# Create additional loop devices
for i in 8 9 10 11 12; do
  mknod /dev/loop$i b 7 $i
  chmod 660 /dev/loop$i
done
```

## Development

### Building Images with GitHub Actions

This repository uses GitHub Actions to automatically build Alpine rootfs images. Workflow runs on:
- Push to `pw6` branch
- Pull requests to `pw6` branch
- Manual workflow dispatch

Built images are available as artifacts from the Actions tab.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Credits

- Original project: [schuhumi/alpine_kindle](https://github.com/schuhumi/alpine_kindle)
- Previous fork: [ohaiibuzzle/alpine_kindle](https://github.com/ohaiibuzzle/alpine_kindle)
- This fork: [fluoroom/alpine_kindle](https://github.com/fluoroom/alpine_kindle)

## License

See [LICENSE](LICENSE) file for details.

---

## ⚠️ Final Reminder

**Always ensure USBNetwork is enabled before connecting your Kindle to a computer while Alpine is mounted!** Check the USBNetwork status in KUAL before connecting.
