#!/bin/sh

TMP=/tmp/alpine_kindle_pw6_kual
URL="https://github.com/fluoroom/alpine_kindle/archive/refs/heads/pw6.zip"

# Clean and create temp directory
rm -rf "$TMP"
mkdir -p "$TMP"
cd "$TMP"

echo "Downloading $URL..."
if command -v curl >/dev/null 2>&1; then
  curl -L -o pw6.zip "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O pw6.zip "$URL"
else
  echo "Error: neither curl nor wget found" >&2
  exit 1
fi

echo "Unzipping..."
unzip -o pw6.zip >/dev/null

# Find extracted directory
extracted_dir=$(ls -d alpine_kindle-* 2>/dev/null | head -n1)
if [ -z "$extracted_dir" ]; then
  echo "Error: Could not find extracted directory" >&2
  ls -la
  exit 1
fi

# Verify source directory exists
src="$extracted_dir/kual-extension/alpine_kindle"
if [ ! -d "$src" ]; then
  echo "Error: Source directory not found: $src" >&2
  ls -la "$extracted_dir"
  exit 1
fi

# Replace target directory
TARGET=/mnt/us/extensions/alpine_kindle
echo "Replacing $TARGET with $src..."

if [ -d "$TARGET" ]; then
  rm -rf "$TARGET"
fi
cp -a "$src" "$TARGET"

echo "Update complete!"
ls -la "$TARGET"

# Cleanup
cd /
rm -rf "$TMP"
echo "Temporary files cleaned up."
echo "Press any key to continue..."
read -n 1 -s