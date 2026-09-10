#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$PROJECT_DIR/dist/MacFold Duo Animation.app"
MODULE_CACHE="$BUILD_DIR/module-cache"

mkdir -p "$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

cd "$PROJECT_DIR"
swift build -c release --disable-sandbox --scratch-path "$BUILD_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/release/MacFoldDuoAnimation" "$APP_DIR/Contents/MacOS/"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
# A stable designated requirement keeps macOS Screen Recording permission
# attached to this local development app across rebuilds.
codesign --force --deep --sign - \
  --requirements '=designated => identifier "app.macfold.duo-animation"' \
  "$APP_DIR"
echo "Built: $APP_DIR"
