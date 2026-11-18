# Roadmap

| Milestone | Goal | Stage | Status |
|---|---|---|---|
| 1.5 | Works out of the box on stock Plasma 6: shipped icon, per-instance settings, translations inside the package | released | done |
| 1.6 | Duplicate removal, per-feed timeout, translated fallbacks, stock-distro CI | Gold (1.6.1 on the KDE Store) | done |
| Standards | Repository follows the team's product standard: `AGENTS.md`, decision log, docs, templates, DCO and REUSE checks | | done |
| Parser tests | Feed parsing in `feedparser.js`, tested in CI with synthetic feeds (D-015, #37) | | done |
| Lints | Format and syntax lints in CI: whitespace, JSON/XML, qmlformat style (D-011), shellcheck | | done |
| Releases | Date version numbers `1.YYMMDD.N` (D-012); a tag builds `SimpleRSSFeed-<version>.plasmoid` and `.tar.gz` for the KDE Store | | done |

## Steps table for the current milestone (written by step 0)
| Step | Tier/effort | Needs | Side by side with | Files |
|---|---|---|---|---|
| 0: reserve decision rows, record the merge permission (D-013) | low | Owner merges this PR (it touches `AGENTS.md` 3.2) | none | `docs/DECISIONS.md`, `docs/ROADMAP.md`, `AGENTS.md` |
| 1: issues #8 and #29, link schemes (D-014) | medium | none | none | per issue |
| 2: issue #37, parser tests in CI (D-015) | high | Owner approval, CI change | after 1 | per issue |
| 3: issue #30, parser entities and CDATA (D-016) | high | none | after 2 | per issue |
| 4: issue #31, date formats (D-017) | high | none | after 3 | per issue |
| 5: issue #33, size limits for large feeds (D-018) | medium | none | after 4 | per issue |
| 6: issue #32, failed refresh keeps the list (D-019) | medium | none | after 5 | per issue |
| 7: issue #35, search and settings on first use (D-020) | high | none | after 6 | per issue |
| 8: issue #36, accessibility (D-021) | medium | none | after 7 | per issue |
| 9: issue #34, settings of a reused `Plasmoid.id` (D-022) | high | Owner's choice of the clear-on-removal option; settings storage, owner gate | after 8 | per issue |
| 10: issue #38, cleanups (D-023) | low | Owner merges (workflow change is a CI gate) | docs any time; workflow after step 9 | per issue |

## User Sprints
<!-- one block per Sprint (testers, dates), then one line per kept item with a blank line between items, so parallel steps setting their own status never touch neighbouring lines -->

None so far.
