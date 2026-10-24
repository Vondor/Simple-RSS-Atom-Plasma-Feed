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
        version() { dpkg-query -W -f '${Version}' "$1" 2>/dev/null; }
        ;;
    fedora:*|*:*fedora*)
        dnf install -y -q @kde-desktop unzip >/dev/null
        owner() { rpm -qf --qf '%{NAME}\n' "$1" 2>/dev/null; }
        version() { rpm -q --qf '%{VERSION}' "$1" 2>/dev/null; }
        ;;
    *)
        echo "Unsupported distribution: ${ID}"; exit 1 ;;
esac
echo "plasma-workspace $(version plasma-workspace)"

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
    # On older libplasma (e.g. Plasma 6.3 in Debian 13) these two modules
    # have no qmldir: plasmashell registers them from libPlasmaQuick at
    # runtime. The plasmoidviewer step below checks that they really load.
    if [ -z "$found" ] && { [ "$mod" = org.kde.plasma.plasmoid ] || [ "$mod" = org.kde.plasma.configuration ]; }; then
        found=$(ls /usr/lib/x86_64-linux-gnu/libPlasmaQuick.so.6 /usr/lib64/libPlasmaQuick.so.6 2>/dev/null | head -n1)
    fi
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
# plasmoidviewer (plasma-sdk) and dbus-run-session (dbus-daemon) are test
# tools, so they are installed only now, after the stock checks above.
# plasmoidviewer runs headless for 20 seconds; the widget must load without
# QML errors.
case "${ID}:${ID_LIKE:-}" in
    fedora:*|*:*fedora*) dnf install -y -q plasma-sdk dbus-daemon >/dev/null ;;
    *) apt-get install -y -q --no-install-recommends plasma-sdk dbus-daemon >/dev/null ;;
esac

RUNTIME="/tmp/runtime-$TESTER"
mkdir -p "$RUNTIME" && chown "$TESTER" "$RUNTIME" && chmod 700 "$RUNTIME"
chmod 755 "$WORK"

# view <applet id or package dir> <log file>: prints plasmoidviewer's exit code
view() {
    set +e
    # QT_FORCE_STDERR_LOGGING: Fedora's Qt logs to the journal otherwise.
    as_tester XDG_RUNTIME_DIR="$RUNTIME" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
        QT_FORCE_STDERR_LOGGING=1 \
        timeout 20 dbus-run-session -- plasmoidviewer -a "$1" >"$2" 2>&1
    echo $?
    set -e
}

# qml_errors <log file>: prints the QML errors that come from the widget's own
# files. Errors from Plasma's containment around it are not ours to fail on.
qml_errors() {
    grep -E "plasmoids/$ID_PLUGIN/|/broken/" "$1" \
        | grep -iE 'error|is not installed|is not a type|ReferenceError|TypeError|Cannot'
}

LOG="$WORK/plasmoidviewer.log"
rc=$(view "$ID_PLUGIN" "$LOG")
echo "::group::plasmoidviewer log"; cat "$LOG"; echo "::endgroup::"

# 124 = still running when the timeout hit, which is what we want.
if [ "$rc" != 124 ] && [ "$rc" != 0 ]; then
    echo "::error::plasmoidviewer exited with code $rc"
    exit 1
fi
if qml_errors "$LOG"; then
    echo "::error::the widget logged QML errors while loading (see lines above)"
    exit 1
fi
echo "[ok] widget loads in plasmoidviewer"

# Self-test: the same check must catch a copy with a missing QML module,
# otherwise a pass above would mean nothing.
cp -a "$INSTALLED" "$WORK/broken"
sed -i '0,/^import QtCore/s//import QtCore\nimport org.example.missing/' "$WORK/broken/contents/ui/main.qml"
# A different Id, so plasmoidviewer cannot pick the installed copy instead.
sed -i "s/\"$ID_PLUGIN\"/\"$ID_PLUGIN.broken\"/" "$WORK/broken/metadata.json"
chown -R "$TESTER" "$WORK/broken"
view "$WORK/broken" "$WORK/broken.log" >/dev/null
if qml_errors "$WORK/broken.log" >/dev/null; then
    echo "[ok] self-test: a missing QML module is detected"
else
    echo "::group::self-test log"; cat "$WORK/broken.log"; echo "::endgroup::"
    echo "::error::self-test failed: a deliberately broken copy loaded without a detected error"
    exit 1
fi
echo "== All checks passed on ${PRETTY_NAME}"
