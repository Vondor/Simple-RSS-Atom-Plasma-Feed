#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the two files a release uploads to the KDE Store (D-011):
#   dist/SimpleRSSFeed-<version with dashes>.plasmoid   the widget
#   dist/SimpleRSSFeed-<version with dashes>.tar.gz     the source of HEAD
# for example SimpleRSSFeed-1-261118-0.plasmoid and .tar.gz for 1.261118.0.
# The source archive holds the committed files of HEAD only (git archive), so
# commit first. Prints both paths, one per line.
#
# Usage:  sh ci/build-release.sh
# Needs:  git, python3, zip, gzip

set -eu
PKG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PKG"

version=$(python3 -c 'import json; print(json.load(open("metadata.json"))["KPlugin"]["Version"])')
name="SimpleRSSFeed-$(echo "$version" | tr . -)"

plasmoid=$(sh ci/build-plasmoid.sh)

tarball="dist/${name}.tar.gz"
rm -f "$tarball"
git archive --format=tar.gz --prefix="${name}/" -o "$tarball" HEAD

echo "$plasmoid"
echo "$tarball"
