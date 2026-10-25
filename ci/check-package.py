#!/usr/bin/env python3
"""Static checks for the plasmoid package. Needs only Python 3.

Checks metadata.json, the package layout and the icon setup that makes the
widget show up correctly in the "Add Widgets" browser and on the panel.

Usage:  python3 ci/check-package.py [package-dir]
"""
import json
import pathlib
import re
import sys

PKG = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
errors = []


def fail(msg):
    errors.append(msg)
    print(f"::error::{msg}")


def ok(msg):
    print(f"[ok] {msg}")


# --- metadata.json ----------------------------------------------------------
try:
    meta = json.loads((PKG / "metadata.json").read_text(encoding="utf-8"))
except (OSError, ValueError) as exc:
    print(f"::error::metadata.json is missing or not valid JSON: {exc}")
    sys.exit(1)
ok("metadata.json is valid JSON")

if meta.get("KPackageStructure") != "Plasma/Applet":
    fail('metadata.json: "KPackageStructure" must be "Plasma/Applet"')

api = meta.get("X-Plasma-API-Minimum-Version", "")
if not api.startswith("6"):
    fail('metadata.json: "X-Plasma-API-Minimum-Version" must be 6.x (Plasma 6)')

k = meta.get("KPlugin", {})
for key in ("Id", "Name", "Description", "Version", "Icon", "License", "Authors"):
    if not k.get(key):
        fail(f'metadata.json: KPlugin."{key}" is missing or empty')

if k.get("Version") and not re.fullmatch(r"\d+(\.\d+)*", k["Version"]):
    fail(f'metadata.json: KPlugin."Version" "{k["Version"]}" is not a dotted number')
ok(f'id {k.get("Id")}, version {k.get("Version")}')

# --- package layout ---------------------------------------------------------
for rel in ("contents/ui/main.qml",
            "contents/ui/configGeneral.qml",
            "contents/config/main.xml",
            "contents/config/config.qml",
            "contents/screenshot.png"):
    if not (PKG / rel).is_file():
        fail(f"{rel} is missing")
ok("package layout")

# --- icon -------------------------------------------------------------------
# The widget-browser icon needs contents/screenshot.png (checked above) plus a
# KPlugin.Icon that resolves without relying on the system icon theme: either
# a file shipped in contents/icons/, or "icon" with icon.png at the package root.
icon = k.get("Icon", "")
shipped = [p for p in (PKG / "contents/icons").glob(f"{icon}.*")
           if p.suffix in (".svg", ".svgz", ".png")] if icon else []
if icon == "icon" and (PKG / "icon.png").is_file():
    ok('icon: "icon" -> icon.png at the package root')
elif shipped:
    ok(f'icon: "{icon}" -> {shipped[0].relative_to(PKG)}')
else:
    fail(f'metadata.json: KPlugin."Icon" "{icon}" is not shipped in the package '
         f'(expected contents/icons/{icon}.svg, or "icon" with icon.png at the root). '
         "A theme-only icon name renders blank on some installs.")

for png in ("contents/screenshot.png", "icon.png"):
    p = PKG / png
    if p.is_file() and p.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{png} is not a PNG file")

# --- translations: every .po has a bundled .mo ------------------------------
domain = f'plasma_applet_{k.get("Id")}'
for po in sorted((PKG / "translate").glob("*.po")):
    mo = PKG / "contents/locale" / po.stem / "LC_MESSAGES" / f"{domain}.mo"
    if not mo.is_file():
        fail(f"translate/{po.name} has no compiled {mo.relative_to(PKG)} "
             "(run sh translate/build.sh)")
ok("translations bundled")

# --- no debug leftovers -----------------------------------------------------
for qml in sorted((PKG / "contents").rglob("*.qml")):
    if "=== DEBUG" in qml.read_text(encoding="utf-8"):
        fail(f"{qml.relative_to(PKG)} still contains a '=== DEBUG' block")

if errors:
    print(f"\n{len(errors)} problem(s) found.")
    sys.exit(1)
print("\nAll package checks passed.")
