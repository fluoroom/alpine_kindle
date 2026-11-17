#!/bin/sh
# Builds the distributable Illusion ZIP locally.
#
# Usage: tools/package.sh [output.zip]
#
# The ZIP layout matches what the in-app updater expects:
#   alpine_kindle/       (Mesquite app: HTML, CSS, JS, config.xml, scripts)
#   alpine_kindle.sh     (Illusion scriptlet)

set -e

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/alpine_kindle-dev.zip}"

cd "$ROOT/illusion"

if [ ! -d alpine_kindle ] || [ ! -f alpine_kindle.sh ]; then
    echo "error: illusion/alpine_kindle or illusion/alpine_kindle.sh is missing" >&2
    exit 1
fi

rm -f "$OUT"
zip -r "$OUT" alpine_kindle/ alpine_kindle.sh

echo "Created $OUT"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$OUT"
fi
