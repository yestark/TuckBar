#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Override caches to allow builds in restricted local workspaces too.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release --disable-sandbox
BIN_DIR="$(swift build -c release --show-bin-path --disable-sandbox)"
APP_DIR="$PWD/dist/TuckBar.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/TuckBar" "$APP_DIR/Contents/MacOS/TuckBar"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/TuckBar.icns "$APP_DIR/Contents/Resources/TuckBar.icns"
# Finder / file-provider metadata can invalidate otherwise correct signatures.
xattr -cr "$APP_DIR"
codesign --force --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"
