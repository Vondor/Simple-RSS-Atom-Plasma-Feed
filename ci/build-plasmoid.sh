#!/bin/sh
# Packs the widget into dist/rssreader-<version>.plasmoid, the file that goes
# to the KDE Store. Only what the widget needs at runtime is included.
#
# Usage:  sh ci/build-plasmoid.sh
# Needs:  python3, zip

set -eu
PKG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PKG"

version=$(python3 -c 'import json; print(json.load(open("metadata.json"))["KPlugin"]["Version"])')
out="dist/rssreader-${version}.plasmoid"

files="metadata.json contents"
[ -f icon.png ] && files="$files icon.png"

mkdir -p dist
rm -f "$out"
# shellcheck disable=SC2086
zip -r -X -q "$out" $files
echo "$out"
