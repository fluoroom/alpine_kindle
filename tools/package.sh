#!/bin/sh
# Builds the distributable Illusion ZIP locally.
#
# Usage: tools/package.sh [output.zip]
#
# The ZIP layout matches what the in-app updater expects:
#   alpine_kindle/       (Mesquite app: HTML, CSS, JS, config.xml, scripts)
#   alpine_kindle.sh     (Illusion scriptlet)
#
# The canonical alpine.sh is copied into alpine_kindle/bin/alpine.sh so the
# launcher can keep the mount/chroot script in sync with the app.

set -e

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/alpine_kindle-dev.zip}"
case "$OUT" in
    /*) ;;
    *) OUT="$ROOT/$OUT" ;;
esac

cd "$ROOT"

if [ ! -d illusion/alpine_kindle ] || [ ! -f illusion/alpine_kindle.sh ]; then
    echo "error: illusion/alpine_kindle or illusion/alpine_kindle.sh is missing" >&2
    exit 1
fi

if [ ! -f alpine.sh ]; then
    echo "error: alpine.sh is missing" >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT INT TERM

cp -R illusion/alpine_kindle "$STAGE/"
cp illusion/alpine_kindle.sh "$STAGE/"
cp alpine.sh "$STAGE/alpine_kindle/bin/alpine.sh"

rm -f "$OUT"
( cd "$STAGE" && zip -r "$OUT" alpine_kindle/ alpine_kindle.sh )

echo "Created $OUT"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUT"
fi
