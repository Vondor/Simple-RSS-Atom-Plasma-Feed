// SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "feedparser.js" as FeedParser

Item {
    id: page

    // 485x600 is only the *preferred* size the dialog opens at. The actual
    // size is bound to fill the host (via width/height, not anchors — anchors
    // on a host-managed root triggers ColumnView warnings). Filling the host
    // is what makes the 5px margin below land against the real window edge
    // instead of around a floating 485-wide box centered in a larger window.
    implicitWidth: 485
    implicitHeight: 600
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight

    property alias cfg_refreshTime: refreshTimeSpinBox.value
    property alias cfg_customTitle: titleField.text
    property string cfg_sourcesJson: ""
    property string cfg_excludeRegexJson: ""

    // Plasma's settings dialog also hands every page a cfg_<key>Default value
    // for each entry in main.xml, and logs a warning for each one the page
    // does not declare. The page does not use them; they exist so the dialog
    // opens without warnings.
    property int cfg_refreshTimeDefault
    property string cfg_customTitleDefault
    property string cfg_sourcesJsonDefault
    property string cfg_excludeRegexJsonDefault

    // Shared width for every row label: sized to whichever translated label
    // text is longest, so the label column lines up no matter the locale.
    // Re-evaluates automatically whenever any label's text/font changes.
    property real formLabelWidth: Math.max(titleFieldLabel.implicitWidth, refreshTimeSpinBoxLabel.implicitWidth, feedsSourcesLabel.implicitWidth, regexSourcesLabel.implicitWidth)

    // Relative height of the two list sections when the dialog has spare
    // vertical space. They're distributed in this ratio, so 2 : 1 means the
    // feeds list is twice as tall as the blacklist. Change these two numbers
    // to retune; any non-negative values work (e.g. 3 and 2, or 1 and 1).
    property int feedsListStretch: 2
    property int regexListStretch: 1

    // False until the stored lists have been read into the models, so that
    // writing cfg_* below (which includes typed but not yet added text) never
    // reads them back in as list entries.
    property bool feedsLoaded: false
    property bool regexLoaded: false

    // What the two input fields would add: a feed address with https:// put
    // in front when missing ("" when it is not a web address), and a
    // blacklist entry (typed text that is not a valid pattern is matched
    // literally). Both come from feedparser.js and are tested there (D-020).
    readonly property string pendingFeedUrl: FeedParser.normalizeFeedUrl(newFeedInput.text)
    readonly property bool pendingFeedDuplicate: pendingFeedUrl !== "" && hasFeed(pendingFeedUrl)
    readonly property string pendingRegex: FeedParser.blacklistPattern(newRegexInput.text)
    // Set when the user leaves the feed field or presses Enter or "Add" with
    // text that is not a web address, so the hint does not flash while typing.
    property bool showFeedProblem: false

    ListModel {
        id: feedsModel
    }
    ListModel {
        id: regexModel
    }

    // Populate feeds list when cfg_sourcesJson is set on dialog open.
    // Accepts plain JSON array only — main.qml's per-instance Settings own the
    // canonical data (and convert older formats on startup);
    // Plasmoid.configuration is just a staging area for the dialog.
    onCfg_sourcesJsonChanged: {
        if (!page.feedsLoaded && cfg_sourcesJson) {
            page.feedsLoaded = true;
            try {
                var parsed = JSON.parse(cfg_sourcesJson);
                var urls = Array.isArray(parsed) ? parsed : [];
                for (var i = 0; i < urls.length; i++)
                    feedsModel.append({
                        "url": urls[i]
                    });
            } catch (e) {
                console.error("RSS configGeneral sourcesJson parse:", e);
            }
        }
    }

    onCfg_excludeRegexJsonChanged: {
        if (!page.regexLoaded && cfg_excludeRegexJson) {
            page.regexLoaded = true;
            try {
                var rules = JSON.parse(cfg_excludeRegexJson);
                if (Array.isArray(rules)) {
                    for (var i = 0; i < rules.length; i++)
                        regexModel.append({
                            "pattern": rules[i]
                        });
                }
            } catch (e) {
                console.error(e);
            }
        }
    }

    // Write plain JSON arrays. main.qml's Connections handler picks these up,
    // saves them to Settings under this instance's Plasmoid.id, and refreshes feeds.
    // NOTE: Plasmoid is intentionally NOT referenced here — it is not available
    //       in config pages in Plasma 6.
    //
    // A valid address or pattern that is typed but not yet added counts as
    // added (issue #35): pressing OK or Apply without "Add" keeps it, and
    // typing it marks the page as changed. The field keeps the text until
    // "Add" is pressed.
    function hasFeed(url) {
        for (var i = 0; i < feedsModel.count; i++) {
            if (feedsModel.get(i).url === url)
                return true;
        }
        return false;
    }

    function updateFeedsConfig() {
        var urls = [];
        for (var i = 0; i < feedsModel.count; i++)
            urls.push(feedsModel.get(i).url);
        // Computed from the field here rather than read from pendingFeedUrl,
        // which may not be updated yet when onTextChanged calls this.
        var pending = FeedParser.normalizeFeedUrl(newFeedInput.text);
        if (pending !== "" && urls.indexOf(pending) === -1)
            urls.push(pending);
        page.feedsLoaded = true;
        cfg_sourcesJson = JSON.stringify(urls);
    }

    function updateRegexConfig() {
        var rules = [];
        for (var i = 0; i < regexModel.count; i++)
            rules.push(regexModel.get(i).pattern);
        var pending = FeedParser.blacklistPattern(newRegexInput.text);
        if (pending !== "" && rules.indexOf(pending) === -1)
            rules.push(pending);
        page.regexLoaded = true;
        cfg_excludeRegexJson = JSON.stringify(rules);
    }

    function addFeed() {
        if (pendingFeedUrl === "") {
            showFeedProblem = newFeedInput.text.trim() !== "";
            return;
        }
        if (!hasFeed(pendingFeedUrl))
            feedsModel.append({
                "url": pendingFeedUrl
            });
        newFeedInput.text = "";
        updateFeedsConfig();
    }

    function addRegex() {
        if (pendingRegex === "")
            return;
        var known = false;
        for (var i = 0; i < regexModel.count; i++) {
            if (regexModel.get(i).pattern === pendingRegex)
                known = true;
        }
        if (!known)
            regexModel.append({
                "pattern": pendingRegex
            });
        newRegexInput.text = "";
        updateRegexConfig();
    }

    // Fixed 5px inset on all four sides. The ColumnLayout — unlike the
    // previous Kirigami.FormLayout root — genuinely distributes leftover
    // vertical space, which is what lets the list boxes expand.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: Kirigami.Units.smallSpacing

        // --- Plasmoid Title --------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                id: titleFieldLabel
                text: i18n("Widget Title:")
                Layout.minimumWidth: page.formLabelWidth
                Layout.preferredWidth: page.formLabelWidth
            }
            QQC2.TextField {
                id: titleField
                placeholderText: i18n("Leave empty to show no title")
                Accessible.name: titleFieldLabel.text
                Layout.fillWidth: true
            }
        }

        // --- Refresh Interval ------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                id: refreshTimeSpinBoxLabel
                text: i18n("Refresh Interval:")
                Layout.minimumWidth: page.formLabelWidth
                Layout.preferredWidth: page.formLabelWidth
            }
            QQC2.SpinBox {
                id: refreshTimeSpinBox
                Accessible.name: refreshTimeSpinBoxLabel.text
                from: 1
                to: 1440
            }
            // Absorbs the remaining row width so the spin box stays compact.
            Item {
                Layout.fillWidth: true
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // --- RSS Feed Sources ------------------------------------------
        // This row and the Blacklist row are the two that grow when the
        // dialog is taller; every other row keeps its natural height. The
        // leftover space is split between them in feedsListStretch :
        // regexListStretch. The preferred/minimum heights sit on the list
        // frames, not on the whole row, so the input field, the warning and
        // the help text below a list never eat into the list's own height
        // (with the help text inside the row budget, the filter list shrank
        // to less than one entry in a normal-sized dialog).
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                id: feedsSourcesLabel
                text: i18n("RSS Feed Sources:")
                Layout.minimumWidth: page.formLabelWidth
                Layout.preferredWidth: page.formLabelWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: page.feedsListStretch * Kirigami.Units.gridUnit * 6
                    Layout.minimumHeight: page.feedsListStretch * Kirigami.Units.gridUnit * 3
                    color: Kirigami.Theme.backgroundColor
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.85)
                    border.width: 1
                    radius: 4

                    QQC2.ScrollView {
                        anchors.fill: parent
                        anchors.margins: 2
                        clip: true

                        ListView {
                            id: feedsListView
                            model: feedsModel
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: QQC2.ItemDelegate {
                                id: feedDelegate
                                width: feedsListView.width
                                hoverEnabled: true

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.mediumSpacing

                                    QQC2.Label {
                                        text: model.url
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    QQC2.ToolButton {
                                        icon.name: "edit-delete"
                                        text: i18n("Remove Source")
                                        display: QQC2.AbstractButton.IconOnly
                                        Accessible.name: text
                                        QQC2.ToolTip.visible: parent.parent.hovered || hovered || visualFocus
                                        QQC2.ToolTip.text: text
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                        onClicked: {
                                            feedsModel.remove(index);
                                            page.updateFeedsConfig();
                                        }
                                    }
                                }
                            }

                            QQC2.Label {
                                anchors.centerIn: parent
                                text: i18n("No feeds configured yet.")
                                color: Kirigami.Theme.disabledTextColor
                                font.italic: true
                                visible: feedsModel.count === 0
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        id: newFeedInput
                        Layout.fillWidth: true
                        placeholderText: i18n("Paste a feed address…")
                        onTextChanged: {
                            page.showFeedProblem = false;
                            page.updateFeedsConfig();
                        }
                        onEditingFinished: page.showFeedProblem = text.trim() !== "" && page.pendingFeedUrl === ""
                        onAccepted: page.addFeed()
                    }
                    QQC2.Button {
                        id: addFeedButton
                        icon.name: "list-add"
                        text: i18n("Add")
                        enabled: newFeedInput.text.trim() !== ""
                        onClicked: page.addFeed()
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Kirigami.Theme.negativeTextColor
                    visible: page.pendingFeedDuplicate || (page.showFeedProblem && page.pendingFeedUrl === "")
                    text: page.pendingFeedDuplicate ? i18n("This feed is already in the list.") : i18n("This is not a web address. A feed address looks like https://example.org/feed.")
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // --- Hide articles matching (blacklist) ------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                id: regexSourcesLabel
                text: i18n("Hide Articles Matching:")
                Layout.minimumWidth: page.formLabelWidth
                Layout.preferredWidth: page.formLabelWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: page.regexListStretch * Kirigami.Units.gridUnit * 6
                    Layout.minimumHeight: page.regexListStretch * Kirigami.Units.gridUnit * 3
                    color: Kirigami.Theme.backgroundColor
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.85)
                    border.width: 1
                    radius: 4

                    QQC2.ScrollView {
                        anchors.fill: parent
                        anchors.margins: 2
                        clip: true

                        ListView {
                            id: regexListView
                            model: regexModel
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: QQC2.ItemDelegate {
                                id: regexDelegate
                                width: regexListView.width
                                hoverEnabled: true

                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.mediumSpacing

                                    QQC2.Label {
                                        text: model.pattern
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    QQC2.ToolButton {
                                        icon.name: "edit-delete"
                                        text: i18n("Remove Pattern")
                                        display: QQC2.AbstractButton.IconOnly
                                        Accessible.name: text
                                        QQC2.ToolTip.visible: parent.parent.hovered || hovered || visualFocus
                                        QQC2.ToolTip.text: text
                                        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                                        onClicked: {
                                            regexModel.remove(index);
                                            page.updateRegexConfig();
                                        }
                                    }
                                }
                            }

                            QQC2.Label {
                                anchors.centerIn: parent
                                text: i18n("No articles are hidden.")
                                color: Kirigami.Theme.disabledTextColor
                                font.italic: true
                                visible: regexModel.count === 0
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        id: newRegexInput
                        Layout.fillWidth: true
                        placeholderText: i18n("Add a word…")
                        onTextChanged: page.updateRegexConfig()
                        onAccepted: page.addRegex()
                    }
                    QQC2.Button {
                        id: addRegexButton
                        icon.name: "list-add"
                        text: i18n("Add")
                        enabled: newRegexInput.text.trim() !== ""
                        onClicked: page.addRegex()
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    text: i18n("Articles whose title or source contains one of these words are hidden. Upper and lower case do not matter. Regular expressions work too.")
                }
            }
        }
    }
}
