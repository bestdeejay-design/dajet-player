#!/bin/bash
# Assembles a double-clickable .app around the SwiftPM binary.
#
#   ./build.sh                 release build, ad-hoc signed: runs here
#   ./build.sh debug           a debug build, for a crash report you can read
#
#   DAJET_ARCH=x86_64 ./build.sh
#                              the same for Intel Macs, into build/intel/
#
# Same shape as the script next door (dajet-browser/build.sh): SwiftPM builds
# the executable, and a macOS app bundle is just a folder with a plist and the
# binary in the right place.
#
# This one stops at the app. The disk image, the ZIP and the appcast an updater
# reads are the release wave's business, and the icon comes with the design
# waves; until then the app wears the plain one macOS gives it.
set -euo pipefail

cd "$(dirname "$0")"
CONFIG="${1:-release}"
ARCH="${DAJET_ARCH:-$(uname -m)}"
case "$ARCH" in
  arm64) OUT="build" ;;
  x86_64) OUT="build/intel" ;;
  *) echo "DAJET_ARCH is arm64 or x86_64, not “$ARCH”" >&2; exit 1 ;;
esac
# The bundle keeps the target's name, DajetPlayer.app; the name people see is
# the plist's, and that one has the space in it.
APP="$OUT/DajetPlayer.app"
NAME="Dajet Player"
EXEC="dajet-player"
VERSION="$(tr -d '[:space:]' < VERSION)"
# A build number that only ever goes up, so a later wave's updater can tell
# newer from older without parsing version strings.
BUILD="$(date +%Y%m%d%H%M)"
# The oldest macOS this runs on — in the plist now, and in the appcast when
# there is one, so an older Mac is never handed a build it can't open.
MINIMUM="14.0"

# -Osize for a release, as in the browser: a smaller binary at the same speed.
SWIFTFLAGS=(-c "$CONFIG" --arch "$ARCH")
[ "$CONFIG" = "release" ] && SWIFTFLAGS+=(-Xswiftc -Osize)
swift build "${SWIFTFLAGS[@]}"
BINARY="$(swift build "${SWIFTFLAGS[@]}" --show-bin-path)/DajetPlayer"
[ "$(lipo -archs "$BINARY")" = "$ARCH" ] || { echo "$BINARY is not a $ARCH binary" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXEC"

# Symbols stay out of the app. The linker leaves every function's name and a
# map back to the source in the binary, more than half of what it weighs, and
# nothing the app reads while it runs. They are kept beside the build instead,
# as a dSYM that turns the addresses in a crash report back into names
# (Console, or atos -o build/DajetPlayer.app.dSYM/Contents/Resources/DWARF/DajetPlayer).
if [ "$CONFIG" = "release" ]; then
  rm -rf "$APP.dSYM"
  dsymutil "$BINARY" -o "$APP.dSYM" 2>/dev/null || echo "no dSYM this time" >&2
  strip -x "$APP/Contents/MacOS/$EXEC"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$EXEC</string>
  <key>CFBundleIdentifier</key><string>ru.dajet.player</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>$MINIMUM</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHumanReadableCopyright</key><string>© Dajet</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Signing. A Developer ID certificate, when there is one, with the hardened
# runtime Gatekeeper asks of anything notarised — the release wave notarises;
# otherwise ad-hoc, which is enough for the app to run on the machine that
# built it.
IDENTITY="${DAJET_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"' || true)}"
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --timestamp --options runtime --sign "$IDENTITY" "$APP"
  echo "signed as: $IDENTITY"
else
  # A build that cannot sign at all is not a build, so nothing here swallows a
  # failure: set -e stops it, with codesign's own words above.
  codesign --force --deep --sign - "$APP"
fi

echo "built: $APP ($VERSION, $ARCH, build $BUILD)"
