#!/bin/bash
# One command, the whole release: build the app, put the disk image and the ZIP
# in a GitHub Release, and keep the feed where it belongs.
#
#   ./release.sh                 # arm64, build + GitHub Release
#   DAJET_ARCH=x86_64 ./release.sh
#
# What it does:
#   1. ./build.sh release dmg — DajetPlayer.app, "Dajet Player.dmg",
#      "Dajet Player.zip" and appcast.json.
#   2. Creates or refreshes the GitHub Release v<VERSION>-dajet, whose "latest"
#      URL is what the feed names — so the file is only offered after its
#      release exists.
#
# The player has no site feed of its own yet: appcast.json is plain, and the
# GitHub Release is what serves the two files. When there is a feed address,
# the copy-and-push of appcast.json goes here, the way dajet-browser does it.
#
# NOTES.md, next to this script, is what's new. Its first paragraph goes into
# the feed (and the release notes).
#
# This is the release wave's business and it is run by hand, not by CI: it
# publishes a public release and, unlike the browser, the player is ad-hoc
# signed, so anyone downloading it meets Gatekeeper's "unidentified developer"
# once. Run it only when the owner says the release is ready.
set -euo pipefail

cd "$(dirname "$0")"
REPO="bestdeejay-design/dajet-player"
VERSION="$(tr -d '[:space:]' < VERSION)"
TAG="v${VERSION}-dajet"
NOTES="$(head -1 NOTES.md)"

./build.sh release dmg

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "release: refreshing $TAG"
  gh release edit "$TAG" --repo "$REPO" --title "Dajet Player ${VERSION}" --notes "$NOTES"
  gh release upload "$TAG" --repo "$REPO" --clobber "build/Dajet Player.dmg" "build/Dajet Player.zip"
else
  echo "release: creating $TAG"
  gh release create "$TAG" "build/Dajet Player.dmg" "build/Dajet Player.zip" --repo "$REPO" \
    --title "Dajet Player ${VERSION}" --notes "$NOTES"
fi

echo "released: https://github.com/$REPO/releases/tag/$TAG"
