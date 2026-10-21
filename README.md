# Simple RSS / Atom Plasma Feed

A lightweight RSS and Atom feed reader widget (plasmoid) for **KDE Plasma 6**.
It merges any number of feeds into one list, newest first, right on your
desktop or panel.

<img src="contents/screenshot.png" alt="Widget icon" width="96">

## Features

- Reads both **RSS** (`<item>`) and **Atom** (`<entry>`) feeds.
- Combines all configured sources into a single list sorted by date, with
  duplicate articles (same link, or same source and title) removed.
- **Live filter**: type a regular expression into the search field to narrow
  the list by title or source.
- **Blacklist**: regular expressions that permanently hide matching articles.
- Configurable refresh interval (1 to 1440 minutes) and an optional custom
  title.
- Click an article to open it in your default browser.
- Each widget instance keeps its own settings, so you can run several feed
  widgets side by side.
- A per-feed timeout of 15 seconds keeps one slow or dead feed from stalling
  the others.
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
kpackagetool6 -t Plasma/Applet -i .
```

To update an existing installation, use `-u` instead of `-i`.
To remove it: `kpackagetool6 -t Plasma/Applet -r org.kde.plasma.rssreader`.

If the widget does not show up in the widget browser right away, run
`kbuildsycoca6` or log out and back in.

## Configuration

Right-click the widget and choose **Configure RSS Feed Plasmoid…**

| Setting | Description |
| --- | --- |
| **Plasmoid Title** | Optional heading. Leave it empty to hide the title and save space. |
| **Refresh Interval** | How often all feeds are reloaded, in minutes (default: 15). |
| **RSS Feed Sources** | The feed URLs to read. RSS and Atom URLs can be mixed freely. The default source is the KDE announcements feed. |
| **Blacklist (Regex)** | Case-insensitive regular expressions. Articles whose title or source matches any of them are hidden. |

The search field at the top of the widget takes a case-insensitive regular
expression too, for example `plasma|frameworks`.

## Development

Try the widget without installing it:

```sh
plasmoidviewer -a .
```

Check the QML with `qmllint` (from Qt 6), for example
`/usr/lib/qt6/bin/qmllint contents/ui/*.qml`.

The translation workflow (`merge.sh`, `build.sh`) is described in
[`translate/README.md`](translate/README.md).

### Project layout

```
metadata.json          Widget metadata (id, version, name/description translations)
contents/ui/           QML: main.qml (widget), configGeneral.qml (settings page)
contents/config/       Configuration schema and settings pages
contents/icons/        Widget icon
contents/locale/       Compiled translations (.mo), bundled with the widget
translate/             Translation sources (.po/.pot) and helper scripts
```

## Contributing

Bug reports, feature ideas and pull requests are welcome on
[GitHub](https://github.com/Vondor/Simple-RSS-Atom-Plasma-Feed/issues).
New translations are especially appreciated.

## Credits

Made by Fabian Drywa ([dev@serpentsoftware.de](mailto:dev@serpentsoftware.de)).
The code was created with the help of Gemini AI and refined with Claude AI;
the design and translations are by humans.

## License

Copyright © 2026 Fabian Drywa

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version (`GPL-3.0-or-later`). See [LICENSE](LICENSE) for the full text.
