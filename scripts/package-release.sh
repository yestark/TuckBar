#!/bin/bash
# Build a universal, locally signed release archive and its SHA-256 checksum.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release --arch arm64 --disable-sandbox
swift build -c release --arch x86_64 --disable-sandbox
ARM_DIR="$(swift build -c release --arch arm64 --show-bin-path --disable-sandbox)"
INTEL_DIR="$(swift build -c release --arch x86_64 --show-bin-path --disable-sandbox)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tuckbar-release.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_DIR="$STAGING_DIR/TuckBar.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PWD/dist"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/TuckBar.icns "$APP_DIR/Contents/Resources/TuckBar.icns"
lipo -create "$ARM_DIR/TuckBar" "$INTEL_DIR/TuckBar" -output "$APP_DIR/Contents/MacOS/TuckBar"
lipo "$APP_DIR/Contents/MacOS/TuckBar" -verify_arch arm64 x86_64
xattr -cr "$APP_DIR"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ARCHIVE="TuckBar-v${VERSION}-universal.zip"
ditto -c -k --norsrc --keepParent "$APP_DIR" "$PWD/dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > "TuckBar-v${VERSION}-SHA256SUMS.txt")
echo "Packaged: dist/$ARCHIVE"
