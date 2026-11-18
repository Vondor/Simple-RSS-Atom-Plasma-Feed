# Architecture

<!-- Keep this current with every structural change; agents read it before planning. -->

## Overview
A Plasma 6 KPackage (`Plasma/Applet`) of plain QML. `main.qml` reads the instance's settings, fetches every configured feed with `XMLHttpRequest` and hands the text to `feedparser.js`, which parses RSS `<item>` and Atom `<entry>` elements, drops duplicates and blacklisted articles, sorts by date and shows the list. A timer refreshes all feeds at the configured interval. Clicking an article opens its link with the desktop's default browser.

## Components
| Component | Responsibility | Depends on |
|---|---|---|
| `metadata.json` | id, name, version (`1.YYMMDD.N`, D-012), licence, icon, website (KDE Store) and bug-report link (GitHub issues) for the About page, translated name and description | — |
| `contents/ui/main.qml` | compact and full views, feed loading with a 15 s timeout per feed, the list model | QtQuick, Layouts, Controls, Kirigami, Plasma components, plasmoid, QtCore, `feedparser.js` |
| `contents/ui/feedparser.js` | pure functions (`.pragma library`, no QML items, no `i18n()`): reading the stored sources and blacklist, parsing RSS/Atom into articles, blacklist, duplicates, newest-first order, search filter, reading feed dates and formatting them in the user's locale (D-015, D-017) | the QML JavaScript engine only |
| `contents/ui/configGeneral.qml` | settings page (title, interval, sources, blacklist) | QtQuick, Controls, Layouts, Kirigami |
| `contents/config/main.xml`, `config.qml` | settings schema and settings pages | KConfigXT |
| `contents/locale/` | compiled translations, built from `translate/*.po` | gettext at build time only |
| `ci/` | package checks, format lints (`lint.sh`), feed parser cases (`test-parser.py`, D-015), translation check, `.plasmoid` build, stock-distro install test | Python 3, zip, gettext, shellcheck, qmlformat and PySide6 (CI only), containers |

## Data storage
Only the user's settings: feed URLs, blacklist patterns, title, refresh interval. They live in `QtCore` `Settings` under the category `SimpleRSSFeed_<Plasmoid.id>`, one per widget instance (D-004). Feed articles are kept in memory only and fetched again on refresh; a feed that fails keeps the articles of its last good refresh until the widget restarts (D-019). A removed widget's section is marked `removed`; Undo takes the mark off and restores it, and its values are emptied once the removal is final, so a new widget with the same id starts from the defaults (D-022). A settings change must keep reading the values an older version wrote.

## Boundaries
- Network: only the feed URLs the user configured (`AGENTS.md` 3.1.3).
- No compiled code, no modules beyond stock Plasma 6 (`AGENTS.md` 3.1.5).
- Feed content is data to show as plain text, never executed or rendered as rich content (`docs/THREAT_MODEL.md`).
