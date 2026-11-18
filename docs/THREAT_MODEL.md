# Threat model

| Asset | Threat | Mitigation | Test or check |
|---|---|---|---|
| The user's desktop session and privacy | A feed delivers markup in titles, for example an entity-encoded `<img>` that survives `stripTags()` (tags are stripped before entities are decoded) and is then rendered by a `Label` in its default auto text format, loading a remote image | Titles, sources and the widget title are shown with `textFormat: Text.PlainText`, so markup is never rendered (issue #8) | review of the `main.qml` delegates: every feed-derived `Label` sets `textFormat: Text.PlainText` |
| The user's desktop session | A feed is huge, slow or never answers | 15 s timeout per feed; one feed never blocks the others or empties the list, and a failed feed is named (D-019); at most the first 100 articles and 2,000,000 characters of a feed are read (D-018) | `main.qml` timeout timer, `feedparser.js` `parseFeed` |
| The list | A user's blacklist or search pattern is not a valid regular expression | Invalid patterns are caught and ignored | `ci/test-parser.py` cases "invalid and empty patterns" and "invalid regex" |
| The user's privacy | The widget contacts hosts the user did not choose | Only the configured feed URLs are fetched; no telemetry (`AGENTS.md` 3.1.3) | review; no other URLs in `contents/` |
| The user's browser | A feed link points to a harmful site | Only `http://` and `https://` links are opened, in the user's own browser, where its protections apply; `file:`, `javascript:` and app-scheme links do nothing; the widget never fetches them (issue #29) | `onClicked` in the `main.qml` delegate |
| Existing installs | An update changes the package id or the settings layout | Both are human gates (`AGENTS.md` 3.2) | `ci/check-package.py` |

Untrusted input: the feeds' XML (titles, links, dates). It is parsed as data and shown as text only.
