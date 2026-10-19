#!/bin/bash
# Points Homebrew at the version just released: the cask in
# github.com/bestdeejay-design/homebrew-tap gets this version and the checksums
# of the disk images on its GitHub release, so that
#
#   brew install --cask bestdeejay-design/tap/dajet-player
#
# installs it, and brew upgrade brings it. Run it once the release is on GitHub
# (tag v<version>-dajet, "Dajet Player.dmg" attached); it reads the version from
# VERSION and computes the checksum from the file on this machine, so there is
# no second download to keep in step.
#
# The player is Apple Silicon only for now; when there is an Intel disk image
# (DAJET_ARCH=x86_64), the cask grows the arch stanza the browser's has.
set -euo pipefail

cd "$(dirname "$0")"
VERSION="$(tr -d '[:space:]' < VERSION)"
DMG="build/Dajet Player.dmg"
[ -f "$DMG" ] || { echo "$DMG is missing — run ./build.sh release dmg first" >&2; exit 1; }
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone -q https://github.com/bestdeejay-design/homebrew-tap.git "$WORK/tap"
CASK="$WORK/tap/Casks/dajet-player.rb"
[ -f "$CASK" ] || { echo "the tap has no Casks/dajet-player.rb yet — make it first, by hand or from dajet-browser's" >&2; exit 1; }

# Everything between the cask line and the name stanza — the version, the
# checksum and the address they fill in — is written afresh; the rest of the
# cask stays as the tap has it.
python3 - "$CASK" "$VERSION" "$SHA" <<'PY'
import re, sys
path, version, arm = sys.argv[1:]
text = open(path).read()
head = f'''  version "{version}"
  sha256 "{arm}"

  url "https://github.com/bestdeejay-design/dajet-player/releases/download/v#{{version}}-dajet/Dajet%20Player.dmg"
'''
text, found = re.subn(r'(cask "dajet-player" do\n)(.*?)(  name )', lambda m: m.group(1) + head + m.group(3), text, count=1, flags=re.S)
if not found:
    sys.exit("the cask doesn't have the shape tap.sh knows — look at it by hand")
open(path, "w").write(text)
PY
if git -C "$WORK/tap" diff --quiet; then
  echo "the tap already has Dajet Player $VERSION"
  exit 0
fi
git -C "$WORK/tap" commit -qam "Dajet Player $VERSION"
git -C "$WORK/tap" push -q
echo "tap: Dajet Player $VERSION, sha256 $SHA (Apple Silicon)"
