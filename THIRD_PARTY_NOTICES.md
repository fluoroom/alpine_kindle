# Third-party notices

This project builds on work from the Kindle modding community. The components below
are not part of the Alpine Linux root filesystem and are not covered by this
repository's GPL-3.0 license unless stated otherwise.

## Utild

- Project: [KindleModding/utild](https://github.com/KindleModding/utild)
- Purpose: a small LIPC service that executes shell commands for Mesquite apps.
- How it is used here: the app sends `runCMD` messages to `com.kindlemodding.utild`.
- How it is obtained: `illusion/alpine_kindle/bin/bootstrap_utild.sh` looks for an
  existing copy (`/var/local/kmc/utild`, `UtildHF`, `UtildSF`, or KindleForge's
  `binaries/` folder). If none is found, it downloads a pinned build from the
  KindleForge repository and verifies its SHA-256 before running it.

Pinned builds (from KindleForge commit
`64c8e264a01277f622c32340bc448c4f1f0e7822`):

| ABI | File | SHA-256 |
| --- | --- | --- |
| hard-float (`/lib/ld-linux-armhf.so.3`) | `UtildHF` | `c939d37262ac7b324e8deaa463a9c8152e7ceb55004f01e0511005c8661854d9` |
| soft-float | `UtildSF` | `a8a44e0f6c7f4869d0574197df9a304dbd25035d6fc45156f7431bcb8d72a9f8` |

The Utild source repository does not currently ship a license file. It is downloaded
at the user's request on-device rather than redistributed in this repository's release
ZIP. If you redistribute a build, check with the upstream authors first.

KindleForge, which currently publishes these builds, is licensed under GPL-3.0:
<https://github.com/KindleTweaks/KindleForge>.

## Illusion

- Guide: [Penguins184/Penguins-Kindle-Wiki - Illusion Guide](https://github.com/penguins184/Penguins-Kindle-Wiki/blob/main/Illusion-Guide.md)
- Site: <https://kindlemodshelf.me/illusion>

The scriptlet layout (`config.xml` + app folder + `.sh` installer, app registration in
`appreg.db`) follows the patterns documented by the Illusion project. The app in this
repository is an independent implementation for Alpine Linux.

## kterm

- Project: [bfabiszewski/kterm](https://github.com/bfabiszewski/kterm)
- License: GPL-3.0 (see upstream)
- How it is used here: kterm is **not** bundled. It is detected at
  `/mnt/us/extensions/kterm/bin/kterm` and only used for interactive sessions
  (Alpine shell, XFCE/Fluxbox sessions, GUI installer).

## KPM (Kindle Package Manager)

- Project: [KindleModding/KPM](https://github.com/KindleModding/KPM)
- License: GPL-3.0 (CLI components are CC0)
- How it is used here: optional. If kterm is missing and `kpm` is installed, the
  **Install kterm** action runs `kpm -y install kterm`. KPM itself is not bundled.

## Fish shell

- Project: <https://fishshell.com/>
- License: GPL-2.0
- How it is used here: optional. The **Install fish shell** action runs
  `apk add fish` inside the user's Alpine image and changes the root/alpine login
  shell. Fish is installed from Alpine's repositories on the device.

## Alpine Linux

- Site: <https://alpinelinux.org/>
- The root filesystem images are built from Alpine's official minirootfs archives by
  this repository's GitHub Actions workflows. Alpine's licensing applies to those
  images.
