#!/bin/sh
# Compiles every *.po into contents/locale/<lang>/LC_MESSAGES/plasma_applet_<Id>.mo
# so the translations travel inside the .plasmoid file, and writes the translated
# Name[xx]/Description[xx] keys back into metadata.json (the widget browser reads
# those from JSON, not from the .mo).
#
# Usage:  sh translate/build.sh
# Needs:  gettext

DIR="$(cd "$(dirname "$0")" && pwd)"
PKGDIR="$(dirname "$DIR")"

plasmoidName=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Id"])' "$PKGDIR/metadata.json")
projectName="plasma_applet_${plasmoidName}"

if [ -z "$plasmoidName" ]; then
    echo "[build] Error: could not read KPlugin.Id from metadata.json."
    exit 1
fi

found=0
for cat in "$DIR"/*.po; do
    [ -e "$cat" ] || continue
    found=1
    catLocale=$(basename "${cat%.*}")
    installPath="$PKGDIR/contents/locale/${catLocale}/LC_MESSAGES/${projectName}.mo"
    mkdir -p "$(dirname "$installPath")"
    msgfmt --check --statistics -o "$installPath" "$cat" || exit 1
    echo "[build] ${catLocale} -> contents/locale/${catLocale}/LC_MESSAGES/${projectName}.mo"

    # Translate KPlugin.Name / KPlugin.Description via the freshly built .mo.
    python3 - "$PKGDIR/metadata.json" "$installPath" "$catLocale" <<'PY'
import gettext, json, sys
meta_path, mo_path, locale = sys.argv[1], sys.argv[2], sys.argv[3]
with open(mo_path, 'rb') as fh:
    tr = gettext.GNUTranslations(fh)
meta = json.load(open(meta_path))
k = meta["KPlugin"]
for field, ctxt in (("Name", "@title widget name"),
                    ("Description", "@info widget description")):
    src = k.get(field, "")
    out = tr.pgettext(ctxt, src) if hasattr(tr, "pgettext") else src
    if out and out != src:
        k[f"{field}[{locale}]"] = out
    else:
        k.pop(f"{field}[{locale}]", None)
meta["KPlugin"] = {key: k[key] for key in sorted(k)}
with open(meta_path, 'w', encoding='utf-8') as fh:
    json.dump(meta, fh, ensure_ascii=False, indent=4, sort_keys=True)
    fh.write("\n")
PY
done

[ "$found" = "1" ] || { echo "[build] No .po files found in $DIR"; exit 1; }
echo "[build] Done. Now repackage and test with:"
echo "        LANGUAGE=de LANG=de_DE.UTF-8 plasmoidviewer -a ."
