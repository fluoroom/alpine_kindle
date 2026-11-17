# Alpine Linux on Kindle (Illusion Edition)

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fluoroom/alpine_kindle/create-rootfs.yaml?branch=pw6)](https://github.com/fluoroom/alpine_kindle/actions)

This fork provides utilities to run [Alpine Linux](https://alpinelinux.org/) on the
Kindle Paperwhite 6 and other compatible Kindles, with a separate home partition,
improved mounting logic and an XFCE desktop option.

This branch replaces the old **KUAL extension** with a modern
**[Illusion](https://kindlemodshelf.me/illusion)** app: a real Mesquite application
with a touch UI, in-app updates and a built-in status/log view. The app is called
**Alpine Manager**; its library launcher starts as **alpine installer** and is renamed
to **alpine** once a root image has been deployed.

Based on [ohaiibuzzle's alpine_kindle](https://github.com/ohaiibuzzle/alpine_kindle),
which itself is a fork of [schuhumi's alpine_kindle](https://github.com/schuhumi/alpine_kindle).

> **Migrating from the KUAL version?**
> Copy the new `alpine_kindle/` folder and `alpine_kindle.sh` scriptlet to
> `/mnt/us/documents/`, then tap **alpine installer** in your Library. The app can
> remove the old KUAL extension for you from its **Maintenance** section. Your Alpine
> images in `/mnt/us/alpine` are reused.

## ⚠️ Critical warning

**While Alpine is running / the image is mounted, do NOT connect the Kindle to a
computer unless USBNetwork is enabled.**

The Alpine image lives in `/mnt/us`, which is the USB mass-storage partition. If both
Alpine and your computer write to it at the same time, the partition can be corrupted
and, in the worst case, the Kindle can be bricked.

Check the USBNetwork status before connecting a cable while Alpine is running.

## What changed from KUAL?

| Old KUAL setup | New Illusion setup |
| --- | --- |
| `kual-extension/alpine_kindle/` | `illusion/alpine_kindle/` |
| KUAL menu (`menu.json`) | Touch UI (`index.html`, `script.js`) |
| Every action opens kterm | Background actions via [Utild](https://github.com/KindleModding/utild); kterm only for interactive sessions |
| Prompts typed in kterm | Confirmation dialogs in the app |
| Manual zip updates | **Update this app** button + **Reload** |
| Shortcut in `/mnt/us/documents` | Scriptlet in `/mnt/us/documents` that registers the Mesquite app |
| Name "Alpine" | "alpine installer" → "alpine" scriptlet, app named "Alpine Manager" |

kterm is still required for the interactive Alpine shell, the XFCE session and the GUI
installer. If kterm is missing, the app can install it through **KPM** (`kpm -y install
kterm`). The launcher itself no longer needs KUAL.

## Requirements

1. **Jailbroken Kindle** with the Universal Hotfix / scriptlet support.
   See [kindlemodding.org](https://kindlemodding.org).
2. **Illusion-compatible firmware** (Mesquite apps). No KUAL installation is needed.
3. **kterm** for terminal and desktop sessions:
   [bfabiszewski/kterm releases](https://github.com/bfabiszewski/kterm/releases), or
   [KPM](https://github.com/KindleModding/KPM) so the app can install kterm for you.
4. **Wi-Fi** for deploying Alpine and for app updates.
5. About **2–3 GB free** on `/mnt/us`.
6. **USBNetwork** or **KOReader** if you want SSH while Alpine is running (optional).

**Fish is optional.** Tick **Install fish as the default shell** before deploying, or
use the **Install fish shell** button later. Fish is installed inside the image with
`apk`, and the Alpine shell automatically starts fish when it is present.

The Utild command runner is installed automatically on first launch. It is downloaded
from a pinned KindleForge build with a SHA-256 check; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). If the Kindle is offline during first
launch, the app still opens and tells you to reconnect Wi-Fi and tap the Alpine item
again.

## Installation

1. Download `alpine_kindle-vX.X.X.zip` from the
   [Releases page](https://github.com/fluoroom/alpine_kindle/releases) (or build it
   yourself with `tools/package.sh`).
2. Extract it. You should see:
   - `alpine_kindle/` (the Illusion app)
   - `alpine_kindle.sh` (the scriptlet)
3. Copy **both** items to `/mnt/us/documents/` on the Kindle.
   Do **not** put them in `/mnt/us/extensions/` — that is the old KUAL location.
4. Eject the Kindle safely.
5. Open the Library and tap **alpine installer**. If it is not there yet, refresh the
   library or reboot once; scriptlets are indexed like books.

The first tap:

- copies the app to `/var/local/mesquite/alpine_kindle`,
- registers it in `/var/local/appreg.db`,
- installs/starts Utild,
- opens the **Alpine Manager** app.

After that, launch **alpine** from the Library whenever you want the UI. Tapping the
library item always re-runs the scriptlet, which also repairs/refreshes the app. The
scriptlet renames itself to **alpine** after the first successful deploy, and back to
**alpine installer** if you delete the root image. If the Library still shows the old
name, refresh the Library or reboot so it re-indexes the scriptlet.

## First run

1. Tap **Deploy Alpine** and confirm. This downloads the latest release image
   (`armhf` or `armv7`), unzips it into `/mnt/us/alpine` and creates `alpine.ext4`.
   The download can take several minutes; the progress bar and Activity log update as
   it goes. Tick **Install fish as the default shell** first if you want fish; the
   deploy then continues with the fish install.
2. Tap **Alpine shell** for a terminal inside Alpine.
3. Optional: tap **GUI installer**, choose XFCE (`x`) and wait for `apk` to finish.
4. Tap **XFCE desktop** to start the graphical session.

Default credentials:

- Username: `alpine`
- Password: `alpine`

## Using the app

| Button | What it does |
| --- | --- |
| **Deploy Alpine** | Downloads the latest release rootfs (clean install; only when no root exists). |
| **Deploy nightly build** | Same, from the nightly workflow. May be unstable. |
| **Install fish as the default shell** | Checkbox: after a successful deploy, install fish with `apk` and set it as root/alpine's shell. |
| **Alpine shell** | Opens kterm and drops into Alpine. |
| **XFCE desktop** | Opens kterm, starts Xephyr and the XFCE session. |
| **GUI installer** | Opens kterm and runs the interactive desktop installer. |
| **Install kterm** | Shows when kterm is missing; runs `kpm -y install kterm`. |
| **Install fish shell** | Mounts the stopped image, installs fish and sets the default shell. |
| **Stop Alpine** | Unmounts everything and detaches loop devices. |
| **Delete Alpine root** | Deletes `alpine.ext4`; keeps `home.ext4`. |
| **Delete home data** | Deletes `home.ext4` (all user data/settings). |
| **Update this app** | Downloads the latest launcher release from GitHub. |
| **Remove old KUAL extension** | Deletes `/mnt/us/extensions/alpine_kindle` and the old library shortcut. |
| **Refresh status** | Re-detects kterm, Utild, images and mount state. |
| **Reload** | Reloads the Mesquite app after an update. |

The status card shows whether Alpine is installed, mounted, and whether the runtime and
kterm are available. The Activity panel shows the last action's output, and the free
space indicator helps before deploying.

## How it works

```
/mnt/us/documents/
├── alpine_kindle/              # Illusion app source (HTML/CSS/JS + scripts)
│   ├── config.xml              # Mesquite app manifest, id com.fluoroom.alpinekindle
│   ├── index.html
│   ├── style.css
│   ├── script.js
│   └── bin/                    # shell implementation
│       └── alpine.sh           # canonical mount/chroot script (packaged copy)
└── alpine_kindle.sh            # scriptlet: install + register + launch

/var/local/mesquite/alpine_kindle/   # copy Mesquite actually runs
/var/local/appreg.db                 # app registration
/var/local/kmc/utild                 # LIPC command runner (auto-installed)

/mnt/us/alpine/
├── alpine.ext4                 # Alpine root filesystem
├── home.ext4                   # persistent home (created on first Alpine start)
├── alpine.sh                   # mount/chroot script from the image
└── illusion/
    ├── status.txt              # key=value state file read by the app
    ├── action.log              # output of the last action
    └── install.log             # scriptlet / runtime bootstrap log
```

The UI cannot execute shell commands directly. It sends commands to
`com.kindlemodding.utild` over LIPC (`kindle.messaging.sendStringMessage`), and Utild
runs the matching script in `bin/`. Scripts write progress to `status.txt` and output
to `action.log`; the app reads both with a hidden `file://` iframe. That is the same
pattern used by other Illusion apps.

The canonical mount/chroot logic lives in the repo's `alpine.sh`. Release builds copy
it into `alpine_kindle/bin/alpine.sh`; the deploy/update scripts copy it to
`/mnt/us/alpine/alpine.sh`, so launcher updates also refresh the mount script. That
script now starts fish instead of `/bin/sh` when fish is installed.

## Updating

### Launcher / app

Use **Update this app** in the Maintenance section, then tap **Reload**. The updater
replaces only `documents/alpine_kindle` and `documents/alpine_kindle.sh`, refreshes the
Mesquite copy, and leaves `/mnt/us/alpine` alone.

You can also update manually by copying new `alpine_kindle/` and `alpine_kindle.sh`
files over the old ones and tapping the library item again.

### Alpine itself

1. Delete the root filesystem (keeps home data).
2. Deploy again.
3. Or switch between release and nightly the same way.

## Troubleshooting

### The Alpine item is not in the Library

- Scriptlets require the Universal Hotfix/scriptlet support. Reinstall the latest
  hotfix.
- Confirm that `alpine_kindle.sh` is directly in `/mnt/us/documents/` (not in a
  subfolder).
- Refresh the library or reboot.

### "Application Error" when opening the item

Usually means the hotfix is missing/outdated, or the app was not copied correctly.
Check `/mnt/us/alpine/illusion/install.log` on the Kindle.

### The app says "Runtime offline"

Utild is not running. Connect Wi-Fi, close the app, and tap the Alpine item in the
Library again. The scriptlet downloads/restarts it. The pinned source is the KindleForge
repository; if that is unavailable, place a compatible Utild binary at
`/mnt/us/alpine/utild/utild` (or `/var/local/kmc/utild`, `UtildHF`/`UtildSF`) manually.

### Shell/XFCE buttons are disabled

kterm is missing or Alpine is not installed. Tap **Install kterm** if KPM is available
(the app runs `kpm -y install kterm`), or install kterm manually from
[bfabiszewski/kterm](https://github.com/bfabiszewski/kterm/releases) and tap
**Refresh status**.

### fish install fails

The fish install mounts the image and runs `apk`, so it needs Wi-Fi inside Alpine and a
stopped Alpine. Check the Activity log; the image is unmounted on failure and you can
retry from **Install fish shell**.

### Alpine won't unmount

The Stop action already retries. If it still fails, reboot the Kindle and try again.
From a root shell you can inspect with `lsof /tmp/alpine/` and `losetup -a`.

### Out of space

- Remove packages inside Alpine: `apk del <package>`
- Clean the package cache: `rm -rf /var/cache/apk/*`
- Build a larger image with `create_minimal_alpine_image.sh` (increase `IMAGESIZE`).

### Loop device issues

```sh
for i in 8 9 10 11 12; do
  mknod /dev/loop$i b 7 $i
  chmod 660 /dev/loop$i
done
```

## Architecture notes

- **`alpine.ext4`** — Alpine root filesystem (2 GB default).
- **`home.ext4`** — separate home partition, created on first Alpine start.
- **`alpine.sh`** — mount, bind-mount, chroot and GUI/fish bootstrap logic (packaged
  with the launcher and copied into `/mnt/us/alpine`).
  by the launcher.

Tested on:

- Kindle Paperwhite 6 (PW6)

Should work on other touchscreen Kindles supported by Illusion with at least 2–3 GB
free and 512 MB RAM.

## Development

### Local packaging

```sh
./tools/package.sh
```

This creates `alpine_kindle-dev.zip` with the layout the in-app updater expects,
including the canonical `alpine.sh` under `alpine_kindle/bin/`.

### Syntax checks

```sh
# Shell scripts (POSIX sh / busybox ash)
for f in illusion/alpine_kindle.sh illusion/alpine_kindle/bin/*.sh tools/*.sh; do
  sh -n "$f" || exit 1
done

# JavaScript (ES5)
node --check illusion/alpine_kindle/script.js

# XML
xmllint --noout illusion/alpine_kindle/config.xml
```

### Releases

Push a `v*` tag. The `Create Release` workflow zips
`illusion/alpine_kindle/` + `illusion/alpine_kindle.sh` and uploads it together with a
SHA-256 file. The rootfs workflows are unchanged.

## Credits

- Original project: [schuhumi/alpine_kindle](https://github.com/schuhumi/alpine_kindle)
- Previous fork: [ohaiibuzzle/alpine_kindle](https://github.com/ohaiibuzzle/alpine_kindle)
- This fork: [fluoroom/alpine_kindle](https://github.com/fluoroom/alpine_kindle)
- Illusion by [Penguins184](https://github.com/penguins184/Penguins-Kindle-Wiki):
  [Illusion Guide](https://github.com/penguins184/Penguins-Kindle-Wiki/blob/main/Illusion-Guide.md)
  and [kindlemodshelf.me/illusion](https://kindlemodshelf.me/illusion)
- Utild by [KindleModding](https://github.com/KindleModding/utild)
- kterm by [bfabiszewski](https://github.com/bfabiszewski/kterm)

## License

See [LICENSE](LICENSE). Third-party components are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

**Final reminder:** always make sure USBNetwork is enabled before connecting the Kindle
to a computer while Alpine is mounted.
