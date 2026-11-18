# Third-party code and dependencies

Every direct dependency, with its licence, why it is needed, and who approved it (a human gate). The widget adds no dependency beyond what every Plasma 6 desktop ships (D-003).

## Licence allowlist
Licences compatible with GPL-3.0-or-later: GPL-2.0-or-later, GPL-3.0-or-later, LGPL-2.1-or-later, LGPL-3.0-or-later, MIT, BSD-2-Clause, BSD-3-Clause, CC0-1.0. The SerpentSoftware logo has its own licence (`LicenseRef-SerpentSoftware-Logo`, D-006) and is not part of the widget.

## Direct dependencies
All are part of a stock Plasma 6 install; none is bundled.

| Name | Version | Licence | Why | Approved (Q-n / D-n) |
|---|---|---|---|---|
| Qt Quick, Layouts, Controls, QtCore (`Settings`) | Qt 6 | LGPL-3.0-only (or GPL) | UI, settings per instance | D-003, D-004 |
| Kirigami | KDE Frameworks 6 | LGPL-2.0-or-later | units and theme | D-003 |
| Plasma components, `org.kde.plasma.plasmoid` | Plasma 6.0+ | LGPL-2.0-or-later | widget integration | D-003 |

Build and CI only (not shipped): Python 3, zip, gettext, `reuse`, the GitHub Actions `actions/checkout`, `upload-artifact`, `download-artifact`.

## Code adapted from other projects
| File | Origin | Licence | Copyright | Approved |
|---|---|---|---|---|
