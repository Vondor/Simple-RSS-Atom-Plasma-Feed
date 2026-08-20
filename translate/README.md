# Translating SimpleRSSFeed

Translations live in this folder as gettext `.po` files and are compiled into
`contents/locale/<lang>/LC_MESSAGES/plasma_applet_org.kde.plasma.rssreader.mo`,
so they travel inside the `.plasmoid` — nothing has to be installed separately.

Currently shipped: **de** (German), **en** (English, source), **pl** (Polish).

## Adding a new language

1. Copy `template.pot` to `<code>.po`, using the locale code for your language
   (`fr`, `es`, `ja`, `pt_BR`, …). Use underscores, not dashes.
2. Fill in the `msgstr ""` lines. [Lokalize](https://apps.kde.org/lokalize/) or
   [Poedit](https://poedit.net/) make this comfortable, but any text editor works.
3. Fill in the header fields: `Language:`, `Last-Translator:`, `Plural-Forms:`.
4. Send the file in — a pull request or an e-mail attachment are both fine.

Two entries carry a `msgctxt` line (`@title widget name`, `@info widget
description`). Those are the widget's name and description in the "Add Widgets"
browser; they are written back into `metadata.json` automatically.

## For the maintainer

Requires `gettext` (`sudo apt install gettext` / `sudo pacman -S gettext`).

    sh translate/merge.sh    # after changing any i18n() string in the code:
                             # regenerates template.pot, updates every .po
    sh translate/build.sh    # compiles .po -> bundled .mo, updates metadata.json

Test a specific language without changing your system settings:

    LANGUAGE=pl LANG=pl_PL.UTF-8 plasmoidviewer -a .

The language pack for the locale you are testing has to be installed, otherwise
Plasma falls back to English.
