// SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
