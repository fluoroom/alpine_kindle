#!/bin/sh

TMP=/tmp/alpine_kindle_pw6_kual
REPO="fluoroom/alpine_kindle"

# Clean and create temp directory
rm -rf "$TMP"
mkdir -p "$TMP"
cd "$TMP"

# Get latest release asset URL (the actual uploaded ZIP file)
echo "Fetching latest release..."
if command -v curl >/dev/null 2>&1; then
  URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url" | grep "\.zip" | head -n1 | cut -d '"' -f 4)
elif command -v wget >/dev/null 2>&1; then
  URL=$(wget -qO- "https://api.github.com/repos/$REPO/releases/latest" | grep "browser_download_url" | grep "\.zip" | head -n1 | cut -d '"' -f 4)
else
  echo "Error: neither curl nor wget found" >&2
  exit 1
fi

if [ -z "$URL" ]; then
  echo "Error: Could not fetch latest release URL" >&2
  exit 1
fi

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

# The release ZIP should contain alpine_kindle directory directly
src="alpine_kindle"
if [ ! -d "$src" ]; then
  echo "Error: Source directory not found: $src" >&2
  ls -la
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

# Cleanup
cd /
rm -rf "$TMP"
echo "Temporary files cleaned up."
echo "Press any key to continue..."
read -n 1 -s
