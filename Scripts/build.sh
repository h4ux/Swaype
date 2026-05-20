#!/usr/bin/env bash
# Build Swaype.app and Swaype.dmg.
#
# Outputs:
#   build/Swaype.app   — runnable menu-bar app bundle
#   build/Swaype.dmg   — installer DMG with custom background and Applications symlink
#
# Requires: full Xcode (for the macOS SDK + iconutil + hdiutil).

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Swaype.app"
DMG_STAGE="$BUILD/dmg-stage"
DMG_RW="$BUILD/Swaype-rw.dmg"
DMG_OUT="$BUILD/Swaype.dmg"

# Use full Xcode toolchain (Command Line Tools alone can't link against XCTest etc).
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "==> Cleaning previous build artifacts"
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Detect arch. For wider distribution change to: --arch arm64 --arch x86_64
ARCH_FLAGS=()
if [[ "$(uname -m)" == "arm64" ]]; then
    ARCH_FLAGS=(--arch arm64)
else
    ARCH_FLAGS=(--arch x86_64)
fi

echo "==> Building release binary (${ARCH_FLAGS[*]})"
xcrun swift build -c release "${ARCH_FLAGS[@]}"

# Resolve the binary path (single-arch builds land in .build/<triple>/release;
# multi-arch builds land in .build/apple/Products/Release).
BIN=""
for candidate in \
    "$ROOT/.build/apple/Products/Release/Swaype" \
    "$ROOT/.build/arm64-apple-macosx/release/Swaype" \
    "$ROOT/.build/x86_64-apple-macosx/release/Swaype" \
    "$ROOT/.build/release/Swaype"
do
    if [[ -f "$candidate" ]]; then
        BIN="$candidate"
        break
    fi
done
if [[ -z "$BIN" ]]; then
    echo "Could not find built Swaype binary under .build/" >&2
    exit 1
fi
echo "    binary: $BIN"

echo "==> Generating app icon"
xcrun swift "$ROOT/Scripts/MakeIcon.swift" "$BUILD/AppIcon.iconset"
iconutil -c icns -o "$BUILD/AppIcon.icns" "$BUILD/AppIcon.iconset"

echo "==> Generating menu bar icon"
xcrun swift "$ROOT/Scripts/MakeMenuBarIcon.swift" "$BUILD/menubar"

echo "==> Assembling Swaype.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Swaype"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD/menubar/"MenuBarIcon*.png "$APP/Contents/Resources/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Copy KeyboardShortcuts resource bundle if SPM produced one.
SHORTCUTS_BUNDLE="$(dirname "$BIN")/KeyboardShortcuts_KeyboardShortcuts.bundle"
if [[ -d "$SHORTCUTS_BUNDLE" ]]; then
    cp -R "$SHORTCUTS_BUNDLE" "$APP/Contents/Resources/"
fi

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "==> Generating DMG background"
xcrun swift "$ROOT/Scripts/MakeDMGBackground.swift" "$BUILD/dmg-background.png"

echo "==> Staging DMG contents"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE/.background"
cp -R "$APP" "$DMG_STAGE/Swaype.app"
ln -s /Applications "$DMG_STAGE/Applications"
cp "$BUILD/dmg-background.png" "$DMG_STAGE/.background/background.png"
cp "$BUILD/dmg-background@2x.png" "$DMG_STAGE/.background/background@2x.png" 2>/dev/null || true

echo "==> Creating writable DMG"
rm -f "$DMG_RW" "$DMG_OUT"
hdiutil create \
    -volname "Swaype" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$DMG_RW" >/dev/null

echo "==> Mounting and customizing window"
# Detach any stale Swaype volumes from previous builds so the new mount
# gets the plain "/Volumes/Swaype" path (not "/Volumes/Swaype 1").
for stale in /Volumes/Swaype /Volumes/Swaype\ *; do
    if [[ -d "$stale" ]]; then
        hdiutil detach "$stale" -force >/dev/null 2>&1 || true
    fi
done

ATTACH_OUTPUT="$(hdiutil attach "$DMG_RW" -noautoopen -nobrowse -readwrite)"
MOUNT_DIR="$(echo "$ATTACH_OUTPUT" | grep -E '/Volumes/' | head -1 | awk '{$1=""; $2=""; sub(/^  */,""); print}')"
if [[ -z "$MOUNT_DIR" ]]; then
    echo "Could not determine mount point. hdiutil said:" >&2
    echo "$ATTACH_OUTPUT" >&2
    exit 1
fi
VOL_NAME="$(basename "$MOUNT_DIR")"
echo "    mounted at: $MOUNT_DIR (volume: $VOL_NAME)"

# Finder needs a moment after attach before the disk shows up.
sleep 2
osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "Swaype.app" of container window to {175, 185}
        set position of item "Applications" of container window to {425, 185}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" >/dev/null

echo "==> Compressing final DMG"
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" >/dev/null
rm -f "$DMG_RW"

echo
echo "Done."
echo "  App: $APP"
echo "  DMG: $DMG_OUT"
