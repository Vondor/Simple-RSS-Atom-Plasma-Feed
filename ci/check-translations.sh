#!/bin/sh
# Rebuilds the translations in a scratch copy and fails if the committed files
# are stale: template.pot missing new i18n() strings, .mo files not rebuilt
# after a .po edit, or metadata.json Name[xx]/Description[xx] out of sync.
#
# Usage:  sh ci/check-translations.sh
# Needs:  gettext, python3

set -eu
SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -a "$SRC/." "$WORK/"

sh "$WORK/translate/merge.sh" >/dev/null
sh "$WORK/translate/build.sh"

status=0
for f in translate/template.pot metadata.json; do
    if ! diff -u "$SRC/$f" "$WORK/$f"; then
        echo "::error file=$f::$f is out of date. Run sh translate/merge.sh && sh translate/build.sh and commit the result."
        status=1
    fi
done

# Compare .mo files by content, not bytes: msgfmt output can differ between
# gettext versions even when the translations are identical.
for mo in "$WORK"/contents/locale/*/LC_MESSAGES/*.mo; do
    rel="${mo#"$WORK"/}"
    if [ ! -f "$SRC/$rel" ]; then
        echo "::error file=$rel::$rel is not committed. Run sh translate/build.sh."
        status=1
    else
        msgunfmt "$SRC/$rel" > "$WORK/committed.po"
        msgunfmt "$mo" > "$WORK/rebuilt.po"
        if ! diff -u "$WORK/committed.po" "$WORK/rebuilt.po"; then
            echo "::error file=$rel::$rel does not match its .po file. Run sh translate/build.sh."
            status=1
        fi
    fi
done

[ "$status" = 0 ] && echo "Translations are up to date."
exit "$status"
