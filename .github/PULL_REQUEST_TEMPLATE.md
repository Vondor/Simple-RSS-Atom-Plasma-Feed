## Made by

<!-- Who made this: the owner, or the AI by tool and model, e.g. "Example Assistant (model-name 1.2)". For a fix of a supporter's finding: "based on <tool>'s finding" and the issue link. -->

## What and why

<!-- One purpose. What changes for the user, and why. Link the roadmap item or issue. -->

## How it was checked

- [ ] CI is green (package, translations, stock Kubuntu / Debian / Fedora, sign-off, licence headers)
- [ ] Tried on a Plasma 6 desktop: <!-- what was done and seen, or "not yet, waiting for the owner" -->

## Definition of done (AGENTS.md 7.9)

- [ ] Checks in AGENTS.md 7.7 pass locally
- [ ] Translations merged and built if any `i18n()` string or `.po` file changed
- [ ] Docs updated (`docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/GLOSSARY.md`, README, as relevant)
- [ ] `docs/DECISIONS.md` updated if this makes or changes a decision
- [ ] No `TODO` without an issue reference, no leftover debug code
- [ ] Licence header on every new source file, or a `REUSE.toml` entry
- [ ] Every commit is signed off (`git commit -s`)
- [ ] Labels set: the areas, a kind, and `human-gate` if one is ticked below

## Human gates (AGENTS.md 3.2)

Tick every gate this pull request touches, or tick "No human gate applies". Keep the whole list.

- [ ] Merge, release, version number or KDE Store publishing
- [ ] Licence (`LICENSE`, `LICENSES/`, `REUSE.toml`, `metadata.json` "License"), mission, principles or boundaries, or `AGENTS.md` human gates
- [ ] Package id (`metadata.json` "Id")
- [ ] New dependency or raised minimum Plasma version
- [ ] Change to how settings are stored, affecting existing installs
- [ ] Author, publisher or branding
- [ ] Credentials, cryptography or connections to hosts other than the user's feeds
- [ ] CI, workflow or branch-protection changes
- [ ] Code adapted from another project
- [ ] Author is not the owner's own agent team
- [ ] No human gate applies
