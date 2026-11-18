#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Prints the version number for a release made today (D-012): 1.YYMMDD.N,
# the UTC date, then a counter from 0 for further releases the same day,
# taken from the existing v1.YYMMDD.* tags. No leading zeros in N.
# Write the result into metadata.json "Version" in the release pull request,
# then tag the merged commit with v<version>.
#
# Usage:  sh ci/next-version.sh          (fetches tags first: git fetch --tags)
# Needs:  git

set -eu
cd "$(dirname "$0")/.."

day=$(date -u +%y%m%d)
n=$(git tag -l "v1.${day}.*" | wc -l | tr -d ' ')
echo "1.${day}.${n}"
