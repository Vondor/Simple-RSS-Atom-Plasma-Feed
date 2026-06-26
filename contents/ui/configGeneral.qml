import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_refreshTime: refreshTimeSpinBox.value
    property alias cfg_customTitle: titleField.text
    property string cfg_sourcesJson: ""
    property string cfg_excludeRegexJson: ""

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

    QQC2.TextField {
        id: titleField
        Kirigami.FormData.label: i18n("Plasmoid Title:")
        placeholderText: i18n("Leave empty to auto-collapse space...")
        Layout.fillWidth: true
    }

    QQC2.SpinBox {
        id: refreshTimeSpinBox
        Kirigami.FormData.label: i18n("Refresh Interval:")
        from: 1
        to: 1440
    }

    Item { Kirigami.FormData.isSection: true }

    ColumnLayout {
        Kirigami.FormData.label: i18n("RSS Feed Sources:")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 6
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

    Item { Kirigami.FormData.isSection: true }

    ColumnLayout {
        Kirigami.FormData.label: i18n("Blacklist (Regex):")
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Kirigami.Units.gridUnit * 6
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
