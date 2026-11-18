#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Prints the build number of a commit (D-012, D-025): 1.YYMMDD.N, worked out
# from git so that every merge to main raises it and no pull request edits a
# version file (as KassenSturz D-226 does):
#   YYMMDD  the commit's committer date in UTC
#   N       how many earlier commits on the first-parent line (on main: the
#           earlier merges) carry the same UTC date, counting from 0
# For example the third merge to main on 2026-11-18 is 1.261118.2.
# ci/build-plasmoid.sh writes this number into the packaged metadata.json;
# a release tag is v<this number of the tagged commit>.
#
# Without git history (a source archive) it prints "Version" from
# metadata.json. A shallow clone would count wrong, so it stops instead.
#
# Usage:  sh ci/build-version.sh [commit]      (default HEAD)
# Needs:  git (python3 for the fallback)

set -eu
cd "$(dirname "$0")/.."
rev="${1:-HEAD}"

if ! git rev-parse --verify -q "${rev}^{commit}" >/dev/null 2>&1; then
    if [ $# -gt 0 ]; then
        echo "build-version.sh: no commit ${rev}" >&2
        exit 1
    fi
    echo "build-version.sh: no git history, using Version from metadata.json" >&2
    python3 -c 'import json; print(json.load(open("metadata.json"))["KPlugin"]["Version"])'
    exit 0
fi
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "build-version.sh: shallow clone, run git fetch --unshallow (in CI: fetch-depth: 0)" >&2
    exit 1
fi

days=$(TZ=UTC0 git log --first-parent --format=%cd --date=format-local:%y%m%d "${rev}")
day=$(echo "${days}" | head -n 1)
n=$(echo "${days}" | awk -v d="${day}" '$0 != d { exit } { c++ } END { print c - 1 }')
echo "1.${day}.${n}"
