#!/bin/bash
# Assembles a double-clickable .app around the SwiftPM binary — and, when
# asked, the disk image people install it from and the ZIP the updater fetches.
#
#   ./build.sh                 release build, ad-hoc signed: runs here
#   ./build.sh debug           a debug build, for a crash report you can read
#   ./build.sh release dmg     + build/Dajet Player.dmg, build/Dajet Player.zip
#                                and build/appcast.json
#
#   DAJET_ARCH=x86_64 ./build.sh
#                              the same for Intel Macs, into build/intel/
#
# Same shape as the script next door (dajet-browser/build.sh): SwiftPM builds
# the executable, and a macOS app bundle is just a folder with a plist and the
# binary in the right place.
#
# This one goes one step further than the browser at "app": the icon is drawn
# from Icon/icon.swift (the brand canon's wave, no image asset in the repo),
# and "dmg" packs the disk image and the ZIP and writes the appcast the feed
# serves. There is no "ship" step yet: the player is ad-hoc signed, and
# notarisation is the release wave's business when there is a Developer ID to
# sign with.
set -euo pipefail

cd "$(dirname "$0")"
CONFIG="${1:-release}"
STEP="${2:-app}"
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

# The icon, drawn fresh each time — it is the brand canon's wave, in code
# (Icon/icon.swift), not an asset to keep in step with anything. The generator
# writes the .icns itself, PNG-only (see Icon/icon.swift), so no iconutil step.
ICONSET="build/AppIcon.iconset"
ICONDOC="build/AppIcon.icon"
rm -rf "$ICONSET" "$ICONDOC"
mkdir -p "$APP/Contents/Resources"
swift Icon/icon.swift "$ICONSET" "$ICONDOC" > /dev/null
cp "build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" "build/AppIcon.icns"
# macOS 26's Dark, Clear and Tinted Dock styles read the icon from an asset
# catalog compiled from the Icon Composer document; without one the Dock
# darkens the flat image and the mark can go muddy. actool comes with Xcode
# 26 — with anything older, or only the command-line tools, the app keeps the
# .icns alone. Only Assets.car is kept, not actool's own .icns: the one above
# goes on being the disk image's icon and the fallback.
ICONNAME=""
ICONCAR="build/AppIcon.car"
rm -rf "$ICONCAR"
mkdir -p "$ICONCAR"
# Full paths: actool hands the document to a helper that runs elsewhere, and
# with "build/…" it finds nothing ("Icon export exited with status 255").
if xcrun actool "$PWD/$ICONDOC" --compile "$PWD/$ICONCAR" --platform macosx \
     --minimum-deployment-target "$MINIMUM" --app-icon AppIcon --optimization space \
     --output-partial-info-plist "$PWD/$ICONCAR/partial.plist" > /dev/null 2>&1 \
   && [ -f "$ICONCAR/Assets.car" ]; then
  cp "$ICONCAR/Assets.car" "$APP/Contents/Resources/Assets.car"
  ICONNAME="<key>CFBundleIconName</key><string>AppIcon</string>"
else
  echo "note: actool from Xcode 26 didn't compile the icon — no Dark or Tinted style this time" >&2
fi
rm -rf "$ICONCAR" "$ICONDOC"

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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  $ICONNAME
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
  [ "$STEP" != "app" ] && echo "no Developer ID certificate found — the DMG will only open on this Mac" >&2
fi

echo "built: $APP ($VERSION, $ARCH, build $BUILD)"
[ "$STEP" = "app" ] && exit 0

# The disk image: the app beside a shortcut to Applications, on a white window
# with an arrow between them — drawn by Installer/background.swift and laid out
# by Installer/dmg.py through dmgbuild, which writes the Finder's layout file
# itself, so no Finder is scripted and no window opens mid-build. dmgbuild is
# installed into .build the first time, and needs Python 3 and a network then;
# without it the image is the plain one it always was.
DMG="$OUT/$NAME.dmg"
ART="build/installer"
rm -rf "$ART" "$DMG"
DMGBUILD=".build/dmgbuild/bin/dmgbuild"
if [ ! -x "$DMGBUILD" ]; then
  { python3 -m venv .build/dmgbuild && .build/dmgbuild/bin/pip install --quiet "dmgbuild==1.6.7"; } >/dev/null 2>&1 || true
fi
if [ -x "$DMGBUILD" ] \
  && swift Installer/background.swift "$ART" >/dev/null \
  && tiffutil -cathidpicheck "$ART/background.png" "$ART/background@2x.png" -out "$ART/background.tiff" >/dev/null 2>&1
then
  "$DMGBUILD" -s Installer/dmg.py \
    -D app="$APP" -D background="$ART/background.tiff" -D icon="$APP/Contents/Resources/AppIcon.icns" \
    "$NAME" "$DMG" >/dev/null
else
  echo "note: no dmgbuild — a plain disk image, without its window laid out" >&2
  STAGE="build/dmg"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
  rm -rf "$STAGE"
fi
rm -rf "$ART"
[ -n "$IDENTITY" ] && codesign --force --timestamp --sign "$IDENTITY" "$DMG"
echo "packed: $DMG"

# The ZIP is what the updater fetches, and its hash is what the updater checks
# before opening it.
ZIP="$OUT/$NAME.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "packed: $ZIP"

# What the updater reads. The first paragraph of NOTES.md, with the two
# characters JSON minds escaped, is the line under the version in Settings.
# The stable URL of the latest release's assets, so the feed names where the
# updater and people fetch from. DAJET_DOWNLOAD_URL overrides it for a test
# run or a feed with no GitHub release behind it.
BASE="${DAJET_DOWNLOAD_URL:-https://github.com/bestdeejay-design/dajet-player/releases/latest/download}"
NOTES=""
if [ -f NOTES.md ]; then
  NOTES="$(awk 'NF { printf "%s%s", (n++ ? " " : ""), $0; next } n { exit }' NOTES.md \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
fi
DMGSHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
cat > "$OUT/appcast.json" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "url": "$BASE/$NAME.zip",
  "dmg": "$BASE/$NAME.dmg",
  "sha256": "$SHA",
  "dmgSha256": "$DMGSHA",
  "notes": "$NOTES",
  "minimumSystemVersion": "$MINIMUM"
}
JSON
echo "wrote: $OUT/appcast.json ($VERSION, $ARCH, build $BUILD)"

echo "packed: $DMG, $ZIP and $OUT/appcast.json"
