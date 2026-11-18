# Decisions

One row per decision. Numbers are handed out by the coordinator and never reused. Rephrase the owner's words; attribute by question number, and say who decided (the owner, or the AI by tool and model). Rows D-001 to D-007 record decisions made before this log existed (2026-06 to 2026-10).

**Reserved rows.** Every handed-out number exists here as a `Reserved` row (written by the first PR of a Sprint or phase, plus a spare block for fix agents). A PR replaces its own row and never appends at the end, so parallel PRs do not conflict.

| ID | Date | Decision | Why | Source (Q-n / PR) |
|---|---|---|---|---|
| D-001 | 2026-06-19 | Name "Simple RSS / Atom Plasma Feed", shown as "RSS Feed Plasmoid", package id `org.kde.plasma.rssreader`. Decided by the owner. | Existing installs depend on the id. | initial commit |
| D-002 | 2026-10-24 | Licence GPL-3.0-or-later, full text in `LICENSE`. Decided by the owner. | Free software, compatible with KDE. | PR #1 |
| D-003 | 2026-07-11 | The widget works out of the box on a stock Plasma 6 desktop (bare Kubuntu, Debian, Fedora) with no extra packages; CI tests the built `.plasmoid` in stock distribution containers. Decided by the owner. | Users install from the KDE Store and expect it to just work. | v1.5, PR #3 |
| D-004 | 2026-07 | Settings are per widget instance, through `QtCore` `Settings` with category `SimpleRSSFeed_<Plasmoid.id>`. Decided by the owner. | `Plasmoid.configuration` mixed values between instances. | v1.5 |
| D-005 | 2026-10-25 | The homepage is the KDE Store page https://store.kde.org/p/2363221; serpentsoftware.de is never a homepage. Decided by the owner. | That domain hosts no project pages. | PR #6 |
| D-006 | 2026-10-25 | The SerpentSoftware logo is a publisher mark in `docs/branding/`, under `LicenseRef-SerpentSoftware-Logo`; the widget keeps its own icon `rssreader.svg`. Decided by the owner. | Brand rules in Agent-Teams `branding/`. | PR #4 |
| D-007 | 2026-10-25 | Agents do not merge pull requests in this repository unless the owner allows it for that pull request or records a general permission in `AGENTS.md`. Decided by the owner. | Releases reach every KDE Store user. | PR #5 |
| D-008 | 2026-11-18 | Every commit is signed off under the DCO; agents sign off in the owner's identity (Fabian Drywa) as committer, as in the owner's other products. CI checks it on pull requests. Decided by the owner. | Part of the team's product standard. | Q-001 |
| D-009 | 2026-11-18 | The widget is in release stage Gold. Decided by the owner. | It is public on the KDE Store at 1.6.1. | Q-002 |
| D-010 | 2026-11-18 | The documentation is licensed like the code, GPL-3.0-or-later (`REUSE.toml`). Decided by the owner. | One licence for the whole project. | Q-003 |
| D-011 | 2026-11-18 | QML code style is whatever `qmlformat` from Qt 6.12 writes (default settings); CI job "Lint" (`ci/lint.sh`) checks it together with whitespace, JSON/XML parsing, shellcheck and Python syntax. `sh ci/lint.sh --fix` reformats. Decided by the AI (Claude Code, Claude Opus 5.5), pending the owner's review in the PR. | The owner asked for a check that the code format is valid; qmlformat is Qt's own formatter and needs nothing in the widget. Pinned because its output changes between Qt versions. | this PR |
| D-012 | 2026-11-18 | Versions are numbered `1.YYMMDD.N` like the owner's other product (KassenSturz D-152, there `0.YYMMDD.N` before its 1.0): release date in UTC, then a counter from 0 for further releases that day, no leading zeros; the major stays 1 because 1.6.1 is already public. `Version` in `metadata.json` is bumped by hand only in a release pull request (`ci/next-version.sh` prints the number); the tag is `v<Version>`. A tag builds `SimpleRSSFeed-<version with dashes>.plasmoid` and `.tar.gz` (source) and attaches them to a GitHub release for the KDE Store upload. Proposed by Claude (Opus 5.5); takes effect when the owner merges. | The owner asked for KassenSturz's numbering and these file names; date numbers stay higher than 1.6.1, so updates are seen. | Q-004 |

# Open questions

| ID | Asked by | Question | Options (R = recommended) | Kind (1 or 2) | Answer |
|---|---|---|---|---|---|
| Q-001 | Claude (Opus 5.5), 2026-11-18 | Do agents sign off their commits in the owner's identity under the DCO, as in the owner's other products? | R: yes, as the owner; or no DCO for this repository (drop the check) | 1 | yes, sign off as the owner (D-008) |
| Q-002 | Claude (Opus 5.5), 2026-11-18 | Which release stage is the widget in? It is public on the KDE Store at 1.6.1. | R: Gold (only the owner declares it); or Beta | 1 | Gold (D-009) |
| Q-003 | Claude (Opus 5.5), 2026-11-18 | Which licence covers the documentation? Until answered it is the code's GPL-3.0-or-later (`REUSE.toml`). | R: keep GPL-3.0-or-later; or CC-BY-SA-4.0 | 1 | GPL-3.0-or-later (D-010) |
| Q-004 | Claude (Opus 5.5), 2026-11-18 | Which numbering after 1.6.1, now that versions follow KassenSturz's date scheme? | R: `1.YYMMDD.N` (keeps the major above 1.6.1); or `0.YYMMDD.N` exactly as KassenSturz (lower than 1.6.1, so stores would not offer it as an update) | 1 | `1.YYMMDD.N` (D-012), on merge |
