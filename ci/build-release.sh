#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the two files a release uploads to the KDE Store (D-012):
#   dist/SimpleRSSFeed-<version with dashes>.plasmoid   the widget
#   dist/SimpleRSSFeed-<version with dashes>.tar.gz     the source of HEAD
# for example SimpleRSSFeed-1-261118-0.plasmoid and .tar.gz for 1.261118.0,
# the build number of HEAD (ci/build-version.sh, D-025). The source archive
# holds the committed files of HEAD only (git archive), so commit first; its
# metadata.json keeps the hand-set Version, only the .plasmoid carries the
# build number. Prints both paths, one per line.
#
# Usage:  sh ci/build-release.sh
# Needs:  git, python3, zip, gzip

set -eu
PKG="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PKG"

version=$(sh ci/build-version.sh)
name="SimpleRSSFeed-$(echo "$version" | tr . -)"

plasmoid=$(sh ci/build-plasmoid.sh)

tarball="dist/${name}.tar.gz"
rm -f "$tarball"
git archive --format=tar.gz --prefix="${name}/" -o "$tarball" HEAD

echo "$plasmoid"
echo "$tarball"
