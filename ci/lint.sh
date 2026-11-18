#!/bin/sh
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
# Format and syntax lints for every tracked source file. Fails on the first
# category that has problems, after listing all problems of that category.
#
#   1. Text hygiene: no trailing whitespace, no CRLF, no tabs in source files,
#      newline at the end of every text file.
#   2. JSON parses (metadata.json), XML is well formed (main.xml, SVG icons).
#   3. QML parses and matches qmlformat's output (the code style, D-011).
#   4. Shell scripts pass shellcheck (warnings and errors), Python compiles.
#
# Usage:  sh ci/lint.sh
# Needs:  git, python3, shellcheck, qmlformat.
# qmlformat's output changes between Qt versions, so CI pins one: set
# QMLFORMAT to the same one locally, for example
#   pipx install pyside6-essentials==6.12.0  ->  QMLFORMAT=pyside6-qmlformat
# Fix the QML style in place with:  sh ci/lint.sh --fix

set -eu
cd "$(dirname "$0")/.."
FIX=0
[ "${1:-}" = "--fix" ] && FIX=1
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TAB="$(printf '\t')"
CR="$(printf '\r')"
status=0
err() { echo "::error file=$1::$2"; status=1; }
section_done() {
    if [ "$status" != 0 ]; then
        echo "lint: $1 failed"
        # --fix goes on to the QML step, which removes most of these problems.
        [ "$FIX" = 1 ] && { status=0; return; }
        exit 1
    fi
    echo "[ok] $1"
}

# Tracked text files. Binaries and verbatim licence texts are left alone.
git ls-files | grep -vE '\.(mo|png)$|^LICENSE$|^LICENSES/' > "$WORK/files"

# --- 1. Text hygiene --------------------------------------------------------
while IFS= read -r f; do
    [ -f "$f" ] || continue
    if grep -q "$CR" "$f"; then
        err "$f" "Windows line endings (CRLF); use LF"
    fi
    if grep -nE "[ $TAB]+\$" "$f" > "$WORK/hits"; then
        line=$(head -n1 "$WORK/hits" | cut -d: -f1)
        err "$f" "trailing whitespace on $(wc -l < "$WORK/hits") line(s), first on line $line"
    fi
    if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then
        err "$f" "no newline at end of file"
    fi
    case "$f" in
        *.qml|*.sh|*.py|*.xml|*.json|*.yml|*.svg)
            if grep -q "$TAB" "$f"; then err "$f" "tab character; indent with spaces"; fi ;;
    esac
done < "$WORK/files"
section_done "text hygiene"

# --- 2. JSON and XML --------------------------------------------------------
grep -E '\.json$' "$WORK/files" | while IFS= read -r f; do
    python3 -c 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$f" \
        || echo "$f" >> "$WORK/bad"
done
grep -E '\.(xml|svg)$' "$WORK/files" | while IFS= read -r f; do
    python3 -c 'import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])' "$f" \
        || echo "$f" >> "$WORK/bad"
done
if [ -s "$WORK/bad" ]; then
    while IFS= read -r f; do err "$f" "does not parse (see the message above)"; done < "$WORK/bad"
fi
section_done "JSON and XML parse"

# --- 3. QML -----------------------------------------------------------------
QMLFORMAT="${QMLFORMAT:-}"
if [ -z "$QMLFORMAT" ]; then
    for c in qmlformat6 qmlformat pyside6-qmlformat /usr/lib/qt6/bin/qmlformat /usr/lib64/qt6/bin/qmlformat; do
        if command -v "$c" >/dev/null 2>&1; then QMLFORMAT="$c"; break; fi
    done
fi
if [ -z "$QMLFORMAT" ]; then
    echo "::error::qmlformat not found. Install Qt 6 declarative tools or 'pipx install pyside6-essentials==6.12.0' and set QMLFORMAT=pyside6-qmlformat"
    exit 1
fi
grep -E '\.qml$' "$WORK/files" | while IFS= read -r f; do
    out="$WORK/formatted.qml"
    if ! "$QMLFORMAT" "$f" > "$out" 2> "$WORK/qmlformat.log"; then
        cat "$WORK/qmlformat.log"
        echo "$f: does not parse as QML (see the message above)" >> "$WORK/qml"
    elif ! cmp -s "$f" "$out"; then
        if [ "$FIX" = 1 ]; then
            cp "$out" "$f"; echo "fixed $f"
        else
            diff -u "$f" "$out" | head -n 40 || true
            echo "$f: not in qmlformat style. Run sh ci/lint.sh --fix" >> "$WORK/qml"
        fi
    fi
done
if [ -s "$WORK/qml" ]; then
    while IFS= read -r line; do err "${line%%:*}" "${line#*: }"; done < "$WORK/qml"
fi
section_done "QML parses and matches qmlformat ($("$QMLFORMAT" --version 2>/dev/null | head -n1 || echo "$QMLFORMAT"))"

# --- 4. Shell and Python ----------------------------------------------------
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "::error::shellcheck not found (apt install shellcheck / dnf install ShellCheck)"
    exit 1
fi
# shellcheck disable=SC2046 # one word per path is intended; paths have no spaces
shellcheck --severity=warning $(grep -E '\.sh$' "$WORK/files") || status=1
for f in $(grep -E '\.py$' "$WORK/files"); do
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "$f" \
        || err "$f" "Python syntax error (see above)"
done
section_done "shellcheck and Python syntax"

echo "All lints passed."
