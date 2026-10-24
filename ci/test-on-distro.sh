#!/bin/sh
# Installs a stock Plasma desktop from the distribution's own repositories,
# then checks that the widget works on it without any extra package.
# Meant to run as root inside a fresh debian/ubuntu/fedora container, the CI
# counterpart of a bare-bones Kubuntu or Fedora VM.
#
# Usage:  sh ci/test-on-distro.sh dist/rssreader-<version>.plasmoid

set -eu
PLASMOID="$(realpath "$1")"
ID_PLUGIN="org.kde.plasma.rssreader"
TESTER=tester

. /etc/os-release
echo "== ${PRETTY_NAME}"

# --- 1. Stock desktop only --------------------------------------------------
# The same meta-package a Plasma install starts from, with its recommends,
# and nothing else.
case "${ID}:${ID_LIKE:-}" in
    debian:*|ubuntu:*|*:*debian*)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -q kde-plasma-desktop unzip >/dev/null
        owner() { dpkg -S "$1" 2>/dev/null | cut -d: -f1; }
        ;;
    fedora:*|*:*fedora*)
        dnf install -y -q @kde-desktop unzip >/dev/null
        owner() { rpm -qf --qf '%{NAME}\n' "$1" 2>/dev/null; }
        ;;
    *)
        echo "Unsupported distribution: ${ID}"; exit 1 ;;
esac
echo "Plasma: $(plasmashell --version 2>/dev/null || echo unknown)"

# --- 2. Every QML import is provided by the stock install -------------------
QML_DIRS="/usr/lib/x86_64-linux-gnu/qt6/qml /usr/lib64/qt6/qml /usr/lib/qt6/qml"
WORK="$(mktemp -d)"
unzip -q "$PLASMOID" -d "$WORK/pkg"

status=0
imports=$(grep -rhoE '^[[:space:]]*import[[:space:]]+[A-Za-z][A-Za-z0-9_.]*' \
              "$WORK/pkg/contents" --include='*.qml' | awk '{print $2}' | sort -u)
for mod in $imports; do
    found=""
    for d in $QML_DIRS; do
        f="$d/$(echo "$mod" | tr . /)/qmldir"
        [ -f "$f" ] && { found="$f"; break; }
    done
    if [ -n "$found" ]; then
        echo "[ok] import ${mod}  (package $(owner "$found"))"
    else
        echo "::error::QML module '${mod}' is not provided by the stock ${PRETTY_NAME} Plasma install"
        status=1
    fi
done
[ "$status" = 0 ] || exit 1

# --- 3. Install the .plasmoid as a normal user ------------------------------
id "$TESTER" >/dev/null 2>&1 || useradd -m "$TESTER"
cp "$PLASMOID" "/home/$TESTER/widget.plasmoid"
chown "$TESTER" "/home/$TESTER/widget.plasmoid"
as_tester() { runuser -u "$TESTER" -- env HOME="/home/$TESTER" "$@"; }

as_tester kpackagetool6 --type Plasma/Applet --install "/home/$TESTER/widget.plasmoid"
as_tester kpackagetool6 --type Plasma/Applet --list | grep -qx "$ID_PLUGIN" \
    || { echo "::error::kpackagetool6 --list does not show ${ID_PLUGIN}"; exit 1; }
as_tester kpackagetool6 --type Plasma/Applet --show "$ID_PLUGIN"

INSTALLED="/home/$TESTER/.local/share/plasma/plasmoids/$ID_PLUGIN"
for rel in metadata.json contents/ui/main.qml contents/screenshot.png; do
    [ -f "$INSTALLED/$rel" ] || { echo "::error::$rel missing after install"; status=1; }
done
ls "$INSTALLED"/contents/locale/*/LC_MESSAGES/*.mo >/dev/null 2>&1 \
    || { echo "::error::no translations installed"; status=1; }

icon=$(sed -n 's/^ *"Icon": *"\([^"]*\)".*/\1/p' "$INSTALLED/metadata.json")
if [ "$icon" = icon ]; then
    [ -f "$INSTALLED/icon.png" ] || { echo "::error::icon.png missing after install"; status=1; }
else
    ls "$INSTALLED/contents/icons/$icon".* >/dev/null 2>&1 \
        || { echo "::error::contents/icons/$icon.* missing after install"; status=1; }
fi
[ "$status" = 0 ] || exit 1
echo "[ok] installed with kpackagetool6"

# --- 4. Load the widget ------------------------------------------------------
# plasmoidviewer is a developer tool (plasma-sdk), so it is installed only now,
# after the stock checks above. It runs headless for 20 seconds; the widget
# must load without QML errors.
case "${ID}:${ID_LIKE:-}" in
    fedora:*|*:*fedora*) dnf install -y -q plasma-sdk >/dev/null ;;
    *) apt-get install -y -q --no-install-recommends plasma-sdk >/dev/null ;;
esac

RUNTIME="/tmp/runtime-$TESTER"
mkdir -p "$RUNTIME" && chown "$TESTER" "$RUNTIME" && chmod 700 "$RUNTIME"
LOG="$WORK/plasmoidviewer.log"
set +e
as_tester XDG_RUNTIME_DIR="$RUNTIME" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    timeout 20 dbus-run-session -- plasmoidviewer -a "$ID_PLUGIN" >"$LOG" 2>&1
rc=$?
set -e
cat "$LOG"

# 124 = still running when the timeout hit, which is what we want.
if [ "$rc" != 124 ] && [ "$rc" != 0 ]; then
    echo "::error::plasmoidviewer exited with code $rc"
    exit 1
fi
if grep -E "$ID_PLUGIN|plasmoids/|module \".*\" is not installed" "$LOG" \
        | grep -qiE 'error|is not installed|is not a type|ReferenceError|TypeError|Cannot'; then
    echo "::error::the widget logged QML errors while loading (see log above)"
    exit 1
fi
echo "[ok] widget loads in plasmoidviewer"
echo "== All checks passed on ${PRETTY_NAME}"
