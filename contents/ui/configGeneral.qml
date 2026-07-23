import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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

    // Shared width for every row label: sized to whichever translated label
    // text is longest, so the label column lines up no matter the locale.
    // Re-evaluates automatically whenever any label's text/font changes.
    property real formLabelWidth: Math.max(
        titleFieldLabel.implicitWidth,
        refreshTimeSpinBoxLabel.implicitWidth,
        feedsSourcesLabel.implicitWidth,
        regexSourcesLabel.implicitWidth
    )

    // Relative height of the two list sections when the dialog has spare
    // vertical space. They're distributed in this ratio, so 2 : 1 means the
    // feeds list is twice as tall as the blacklist. Change these two numbers
    // to retune; any non-negative values work (e.g. 3 and 2, or 1 and 1).
    property int feedsListStretch: 2
    property int regexListStretch: 1

    ListModel { id: feedsModel }
    ListModel { id: regexModel }

    // Populate feeds list when cfg_sourcesJson is set on dialog open.
    // Accepts plain JSON array only — the SQLite layer in main.qml owns the
    // canonical data; Plasmoid.configuration is just a staging area for the dialog.
    onCfg_sourcesJsonChanged: {
        if (feedsModel.count === 0 && cfg_sourcesJson) {
            try {
                var parsed = JSON.parse(cfg_sourcesJson);
                var urls = Array.isArray(parsed) ? parsed : [];
                for (var i = 0; i < urls.length; i++)
                    feedsModel.append({ "url": urls[i] });
            } catch(e) { console.error("RSS configGeneral sourcesJson parse:", e); }
        }
    }

    onCfg_excludeRegexJsonChanged: {
        if (regexModel.count === 0 && cfg_excludeRegexJson) {
            try {
                var rules = JSON.parse(cfg_excludeRegexJson);
                if (Array.isArray(rules)) {
                    for (var i = 0; i < rules.length; i++)
                        regexModel.append({ "pattern": rules[i] });
                }
            } catch(e) { console.error(e); }
        }
    }

    // Write plain JSON arrays. main.qml's Connections handler picks these up,
    // saves them to SQLite under this instance's Plasmoid.id, and refreshes feeds.
    // NOTE: Plasmoid is intentionally NOT referenced here — it is not available
    //       in config pages in Plasma 6.
    function updateFeedsConfig() {
        var urls = [];
        for (var i = 0; i < feedsModel.count; i++)
            urls.push(feedsModel.get(i).url);
        cfg_sourcesJson = JSON.stringify(urls);
    }

    function updateRegexConfig() {
        var rules = [];
        for (var i = 0; i < regexModel.count; i++)
            rules.push(regexModel.get(i).pattern);
        cfg_excludeRegexJson = JSON.stringify(rules);
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
                text: i18n("Plasmoid Title:")
                Layout.minimumWidth: page.formLabelWidth
                Layout.preferredWidth: page.formLabelWidth
            }
            QQC2.TextField {
                id: titleField
                placeholderText: i18n("Leave empty to auto-collapse space...")
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
                from: 1
                to: 1440
            }
            // Absorbs the remaining row width so the spin box stays compact.
            Item { Layout.fillWidth: true }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // --- RSS Feed Sources ------------------------------------------
        // This row and the Blacklist row are the two that grow when the
        // dialog is taller; every other row keeps its natural height. The
        // leftover space is split between them in feedsListStretch :
        // regexListStretch, and preferred/minimum both carry that ratio so
        // the proportion holds at every dialog size.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: page.feedsListStretch * Kirigami.Units.gridUnit * 6
            Layout.minimumHeight: page.feedsListStretch * Kirigami.Units.gridUnit * 3
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
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.textColor
                    border.width: 1
                    opacity: 0.85
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
                                        display: QQC2.AbstractButton.IconOnly
                                        QQC2.ToolTip.visible: parent.parent.hovered
                                        QQC2.ToolTip.text: i18n("Remove Source")
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
                                opacity: 0.4
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
                        placeholderText: i18n("Add feed URL...")
                        onAccepted: addFeedButton.clicked()
                    }
                    QQC2.Button {
                        id: addFeedButton
                        icon.name: "list-add"
                        text: i18n("Add")
                        onClicked: {
                            if (newFeedInput.text.trim() !== "") {
                                feedsModel.append({ "url": newFeedInput.text.trim() });
                                newFeedInput.text = "";
                                page.updateFeedsConfig();
                            }
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // --- Blacklist (Regex) -----------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: page.regexListStretch * Kirigami.Units.gridUnit * 6
            Layout.minimumHeight: page.regexListStretch * Kirigami.Units.gridUnit * 3
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                id: regexSourcesLabel
                text: i18n("Blacklist (Regex):")
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
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.textColor
                    border.width: 1
                    opacity: 0.85
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
                                        display: QQC2.AbstractButton.IconOnly
                                        QQC2.ToolTip.visible: parent.parent.hovered
                                        QQC2.ToolTip.text: i18n("Remove Pattern")
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
                                text: i18n("No exclusion patterns configured.")
                                opacity: 0.4
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
                        placeholderText: i18n("Add block expression...")
                        onAccepted: addRegexButton.clicked()
                    }
                    QQC2.Button {
                        id: addRegexButton
                        icon.name: "list-add"
                        text: i18n("Add")
                        onClicked: {
                            if (newRegexInput.text.trim() !== "") {
                                regexModel.append({ "pattern": newRegexInput.text.trim() });
                                newRegexInput.text = "";
                                page.updateRegexConfig();
                            }
                        }
                    }
                }
            }
        }
    }
}
