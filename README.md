# Simple RSS / Atom Plasma Feed

[![CI](https://github.com/Vondor/Simple-RSS-Atom-Plasma-Feed/actions/workflows/ci.yml/badge.svg)](https://github.com/Vondor/Simple-RSS-Atom-Plasma-Feed/actions/workflows/ci.yml)

A lightweight RSS and Atom feed reader widget (plasmoid) for **KDE Plasma 6**.
It merges any number of feeds into one list, newest first, right on your
desktop or panel.

<img src="contents/screenshot.png" alt="Widget icon" width="96">

## Features

- Reads both **RSS** (`<item>`) and **Atom** (`<entry>`) feeds.
- Combines all configured sources into a single list sorted by date, with
  duplicate articles (same link, or same source and title) removed.
- **Search**: type any text into the search field to narrow the list to the
  articles whose title or source contains it.
- **Hide articles**: words (or regular expressions) that permanently hide
  matching articles.
- Configurable refresh interval (1 to 1440 minutes) and an optional custom
  title.
- Click an article to open it in your default browser.
- Each widget instance keeps its own settings, so you can run several feed
  widgets side by side.
- A per-feed timeout of 15 seconds keeps one slow or dead feed from stalling
  the others.
- Very large feeds are cut off to keep your desktop responsive: the first 100
  articles of each feed are shown, and no more than 2 MB of a feed is read.
- Compact (icon) view on small panels, full list at 250×250 px and above.
- Translations: German and English, plus Klingon (`tlh`) and Quenya (`qya`)
  as easter eggs. See [`translate/README.md`](translate/README.md) to add
  your language.

## Requirements

- KDE Plasma 6.0 or newer.

No extra packages, scripts or setup steps are needed. Everything ships inside
the `.plasmoid` file.

## Installation

### From the KDE Store (recommended)

1. Right-click your desktop or panel and choose **Add or Manage Widgets…**
2. Click **Get New Widgets… → Download New Plasma Widgets**.
3. Search for **RSS Feed Plasmoid** and click **Install**.

The widget is also available directly on the
[KDE Store](https://store.kde.org/p/2363221/).

### From a `.plasmoid` file

Download the `.plasmoid` file from the KDE Store, then either use
**Add or Manage Widgets… → Get New Widgets… → Install Widget From Local File…**,
or run:

```sh
kpackagetool6 -t Plasma/Applet -i rssreader.plasmoid
```

### From source

```sh
git clone https://github.com/Vondor/Simple-RSS-Atom-Plasma-Feed.git
cd Simple-RSS-Atom-Plasma-Feed
sh ci/build-plasmoid.sh
kpackagetool6 -t Plasma/Applet -i dist/SimpleRSSFeed-*.plasmoid
```

The build writes the build number of the checked-out commit into the
package, so the widget shows which build it is. `kpackagetool6 -t Plasma/Applet -i .`
also works, but then the widget shows the hand-set `Version` from
`metadata.json` instead. To update an existing installation, use `-u` instead
of `-i`; delete `dist/` first if it holds older builds.
To remove it: `kpackagetool6 -t Plasma/Applet -r org.kde.plasma.rssreader`.

If the widget does not show up in the widget browser right away, run
`kbuildsycoca6` or log out and back in.

## Configuration

Right-click the widget and choose **Configure RSS Feed Plasmoid…**

| Setting | Description |
| --- | --- |
| **Widget Title** | Optional heading. Leave it empty to hide the title and save space. |
| **Refresh Interval** | How often all feeds are reloaded, in minutes (default: 15). |
| **RSS Feed Sources** | The feed addresses to read. RSS and Atom feeds can be mixed freely. Paste an address and press **Add**; `https://` is added when it is missing, and an address you pasted but did not add is still saved when you press **OK** or **Apply**. The default source is the KDE announcements feed. |
| **Hide Articles Matching** | Words that hide every article whose title or source contains one of them, not case-sensitive. Regular expressions work too, for example `sponsored|advert`; text that is not a valid expression, such as `C++`, is matched as written. |

The search field at the top of the widget finds plain text, not case-sensitive,
in titles and sources: `C++` finds exactly `C++`.

## Development

Try the widget without installing it:

```sh
plasmoidviewer -a .
```

Check the QML with `qmllint` (from Qt 6), for example
`/usr/lib/qt6/bin/qmllint contents/ui/*.qml`.

The translation workflow (`merge.sh`, `build.sh`) is described in
[`translate/README.md`](translate/README.md).

### Continuous integration

Every push and pull request (and a weekly scheduled run) builds the
`.plasmoid` and tests it on fresh Kubuntu, Debian and Fedora containers that
contain only the distribution's stock Plasma packages. It fails if a QML
import is not provided by a stock install, if `kpackagetool6` cannot install
the file, or if the widget logs QML errors while loading. It also checks
`metadata.json`, the icon files and that the compiled translations match the
`.po` files. On pull requests it also checks that every commit is signed off
(DCO) and that every file has licence information
([REUSE](https://reuse.software/)). The scripts live in [`ci/`](ci) and run
locally too:

```sh
python3 ci/check-package.py      # metadata, layout, icon
python3 ci/test-parser.py        # feed parser cases (needs pyside6-essentials 6.12)
sh ci/check-translations.sh      # .pot/.mo/metadata.json up to date (needs gettext)
sh ci/build-plasmoid.sh          # writes dist/SimpleRSSFeed-<version with dashes>.plasmoid
reuse lint                       # licence headers (pipx run reuse lint)
```

### Version numbers and releases

Every build is numbered `1.YYMMDD.N` (D-012, D-025): the UTC date of the
commit, then how many merges to `main` came earlier that day, from 0. The
third merge on 2026-11-18 is `1.261118.2`. The number is worked out from git
(`sh ci/build-version.sh` prints it for `HEAD` or a given commit), so every
merged patch raises it and no pull request edits a version file.
`ci/build-plasmoid.sh` writes it into the packaged `metadata.json`; the
`Version` in the checkout is only a hand-set fallback for builds without git
history. Numbers always go up, so the KDE Store and Plasma see every release
as newer than 1.6.1.

To publish a release of the current `main`:

1. `git fetch origin && sh ci/build-version.sh origin/main` prints the number,
   for example `1.261118.17`.
2. Tag that commit and push the tag:
   `git tag -a v1.261118.17 origin/main -m "Release 1.261118.17" && git push origin v1.261118.17`.

The release workflow checks that the tag is the build number of the tagged
commit and that the commit is on `main`, then attaches
`SimpleRSSFeed-1-261118-0.plasmoid` and `SimpleRSSFeed-1-261118-0.tar.gz`
(the source) to a GitHub release. Download both from the release page and
upload them to the [KDE Store](https://store.kde.org/p/2363221).
`sh ci/build-release.sh` builds the same two files locally.

### Project layout

```
metadata.json          Widget metadata (id, version, name/description translations)
contents/ui/           QML: main.qml (widget), feedparser.js (feed parsing), configGeneral.qml (settings page)
contents/config/       Configuration schema and settings pages
contents/icons/        Widget icon
docs/                  Decisions, roadmap, architecture, glossary, threat model, third-party list
docs/branding/         Publisher logo (SerpentSoftware), not part of the widget
contents/locale/       Compiled translations (.mo), bundled with the widget
translate/             Translation sources (.po/.pot) and helper scripts
ci/                    Checks and packaging used by the GitHub Actions workflows
```

## Contributing

Bug reports, feature ideas and pull requests are welcome on
[GitHub](https://github.com/Vondor/Simple-RSS-Atom-Plasma-Feed/issues).
New translations are especially appreciated. The widget is meant to stay
simple: bug fixes are always welcome, but big extensions of its functions may
be rejected, so please open an issue before starting on a larger feature. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; the project's rules for every
contributor, human or AI, are in [AGENTS.md](AGENTS.md), and its decisions in
[docs/DECISIONS.md](docs/DECISIONS.md).

## Credits

Made by Fabian Drywa ([dev@serpentsoftware.de](mailto:dev@serpentsoftware.de)).
The code was created with the help of Gemini AI and refined with Claude AI;
the design and the German translation are by a human. The Klingon and Quenya
translations are made by AI until a speaker reviews them.

## Publisher

Simple RSS / Atom Plasma Feed is published by SerpentSoftware. Its homepage is
the [KDE Store page](https://store.kde.org/p/2363221).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/branding/serpentsoftware-mark-dark.svg">
  <img src="docs/branding/serpentsoftware-mark.svg" alt="SerpentSoftware logo" width="64">
</picture>

## License

Copyright © 2026 Fabian Drywa

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version (`GPL-3.0-or-later`). See [LICENSE](LICENSE) for the full text. Each
source file names its licence in an SPDX header; [REUSE.toml](REUSE.toml)
covers the files that cannot carry one, and [LICENSES/](LICENSES/) holds every
licence text.

The SerpentSoftware logo in `docs/branding/` is the publisher's brand mark and
is not covered by the GPL (`LicenseRef-SerpentSoftware-Logo`, see
[LICENSES/](LICENSES/LicenseRef-SerpentSoftware-Logo.txt) and
[REUSE.toml](REUSE.toml)): copy it unmodified with the project, but remove it
if you publish a fork under your own name. The widget icon
(`contents/icons/rssreader.svg`) is part of the project and stays under the
GPL.
