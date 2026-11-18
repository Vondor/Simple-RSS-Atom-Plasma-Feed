#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Packs the widget into dist/SimpleRSSFeed-<version with dashes>.plasmoid
# (for example SimpleRSSFeed-1-261118-0.plasmoid), the file that goes to the
# KDE Store. Only what the widget needs at runtime is included.
# The version is the build number of HEAD (ci/build-version.sh, D-025); it is
# written into the packaged metadata.json only, the checkout stays unchanged.
#
# Usage:  sh ci/build-plasmoid.sh
# Needs:  git, python3, zip

set -eu
PKG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PKG"

version=$(sh ci/build-version.sh)
out="$PKG/dist/SimpleRSSFeed-$(echo "$version" | tr . -).plasmoid"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R contents "$stage/"
[ -f icon.png ] && cp icon.png "$stage/"
# Replace only the value of KPlugin "Version", so the file keeps its layout.
python3 - "$version" "$stage/metadata.json" <<'PY'
import json, re, sys
version, dest = sys.argv[1], sys.argv[2]
text = open("metadata.json", encoding="utf-8").read()
new, count = re.subn(r'("Version"\s*:\s*")[^"]*(")', lambda m: m.group(1) + version + m.group(2), text)
if count != 1:
    sys.exit(f'build-plasmoid.sh: expected one "Version" in metadata.json, found {count}')
if json.loads(new)["KPlugin"]["Version"] != version:
    sys.exit('build-plasmoid.sh: "Version" is not KPlugin.Version')
open(dest, "w", encoding="utf-8").write(new)
PY

mkdir -p dist
rm -f "$out"
(cd "$stage" && zip -r -X -q "$out" .)
echo "dist/$(basename "$out")"
