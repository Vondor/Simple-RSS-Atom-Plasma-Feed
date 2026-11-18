// SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import QtCore
import "feedparser.js" as FeedParser

PlasmoidItem {
    id: root

    property string lastUpdatedText: i18n("Never")
    property var allArticlesRaw: []
    // Articles of the last good refresh per feed address, kept in memory only
    // (no cache on disk), so a feed that fails keeps its articles (D-019).
    property var keptArticles: ({})
    // Feeds that failed in the last refresh: [{url, error}].
    property var failedFeeds: []
    property int feedCount: 0
    // True when no feed answered in the last refresh.
    property bool allFeedsFailed: false
    property string searchQuery: ""
    property int currentFetchId: 0 // Prevents older network requests from overwriting newer ones
    property bool initializing: false  // blocks Connections writes during startup restore
    property bool removedByUser: false // the user removed this widget and has not undone it

    property string currentTitle: {
        try {
            return Plasmoid.configuration.customTitle.trim();
        } catch (e) {
            return "";
        }
    }

    onSearchQueryChanged: filterArticles()

    // Show the compact (logo) representation when the widget is smaller than
    // 250x250; the full content view is used at or above that size.
    switchWidth: 250
    switchHeight: 250

    ListModel {
        id: articlesModel
    }

    // Reusable Timer component, instantiated per in-flight feed request as a
    // safety timeout. QML's XMLHttpRequest does not implement .timeout/.ontimeout
    // (long-standing Qt limitation), so without this a single unresponsive feed
    // would prevent completedRequests from ever reaching sources.length, and the
    // whole widget would stop updating - even for feeds that fetched fine.
    Component {
        id: feedTimeoutComponent
        Timer {
            interval: 15000 // 15s per-feed safety timeout
            repeat: false
        }
    }

    Timer {
        id: refreshTimer
        interval: {
            try {
                return Plasmoid.configuration.refreshTime * 60 * 1000;
            } catch (e) {
                return 900000;
            }
        }
        running: true
        repeat: true
        onTriggered: fetchFeeds()
    }

    // Coalesces multiple config properties changing at once (e.g. editing
    // sources, blacklist, and refresh time, then clicking "Apply" once) into
    // a single fetchFeeds() call instead of one redundant fetch per property.
    Timer {
        id: refreshDebounceTimer
        interval: 50
        repeat: false
        onTriggered: fetchFeeds()
    }

    // Per-instance settings in a plain INI file under ~/.config/ (D-004).
    // category is keyed by Plasmoid.id so every instance is fully isolated;
    // QtCore's Settings persists every property automatically.
    Settings {
        id: instanceSettings
        category: "SimpleRSSFeed_" + Plasmoid.id

        property string sourcesJson: "[]"
        property string excludeRegexJson: "[]"
        property string customTitle: ""
        property int refreshTime: 15
        // Becomes true after the first successful seed so Component.onCompleted
        // knows to RESTORE from here rather than seed from Plasmoid.configuration.
        property bool seeded: false
        // True from the moment the user removes this widget (D-022). Plasma
        // gives the id of a removed widget to a new one, which must not take
        // over these values. Only ever set for this instance's own category.
        property bool removed: false
    }

    // Plasma emits destroyedChanged(true) when the user removes the widget
    // (or its panel) and destroyedChanged(false) when they press "Undo" in
    // the notification. It is not emitted on logout, shutdown or a Plasma
    // restart, so the settings of a widget that stays are never marked.
    Connections {
        target: Plasmoid
        function onDestroyedChanged(destroyed) {
            root.removedByUser = destroyed;
            instanceSettings.removed = destroyed;
        }
    }

    // Runs when the widget object goes away: on shutdown (removedByUser is
    // false, nothing happens) and when a removal becomes final after the
    // undo time. Only then are this instance's stored values emptied, so the
    // removed widget's feed addresses do not stay in the settings file. The
    // "removed" mark above is what protects a new widget; this is tidying up.
    Component.onDestruction: {
        if (!root.removedByUser)
            return;
        try {
            instanceSettings.sourcesJson = "[]";
            instanceSettings.excludeRegexJson = "[]";
            instanceSettings.customTitle = "";
            instanceSettings.refreshTime = 15;
            instanceSettings.seeded = false;
            instanceSettings.sync();
        } catch (e) {}
    }

    Connections {
        target: Plasmoid.configuration
        ignoreUnknownSignals: true
        function onSourcesJsonChanged() {
            if (!root.initializing) {
                instanceSettings.sourcesJson = Plasmoid.configuration.sourcesJson;
                refreshDebounceTimer.restart();
            }
        }
        function onExcludeRegexJsonChanged() {
            if (!root.initializing) {
                instanceSettings.excludeRegexJson = Plasmoid.configuration.excludeRegexJson;
                refreshDebounceTimer.restart();
            }
        }
        function onCustomTitleChanged() {
            if (!root.initializing)
                instanceSettings.customTitle = Plasmoid.configuration.customTitle;
        }
        function onRefreshTimeChanged() {
            if (!root.initializing) {
                instanceSettings.refreshTime = Plasmoid.configuration.refreshTime;
                refreshDebounceTimer.restart();
            }
            refreshTimer.restart();
        }
    }

    // Fills the visible list with the articles matching the search box.
    function filterArticles() {
        articlesModel.clear();
        var shown = FeedParser.filterArticles(allArticlesRaw, root.searchQuery);
        for (var i = 0; i < shown.length; i++) {
            articlesModel.append(shown[i]);
        }
    }

    // Shown when the widget is smaller than switchWidth/switchHeight (250x250).
    // Draws the same logo as the widget-gallery preview (contents/screenshot.png)
    // instead of the metadata "Icon", which renders blank here. The MouseArea is
    // required for a custom compact view: it toggles the full popup on click.
    compactRepresentation: MouseArea {
        // Reachable and usable from the keyboard and announced by screen readers.
        activeFocusOnTab: true
        Accessible.name: root.currentTitle !== "" ? root.currentTitle : Plasmoid.title
        Accessible.role: Accessible.Button
        Accessible.onPressAction: root.expanded = !root.expanded
        Keys.onReturnPressed: root.expanded = !root.expanded
        Keys.onEnterPressed: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded
        hoverEnabled: true
        QQC2.ToolTip.visible: containsMouse
        QQC2.ToolTip.text: Accessible.name
        onClicked: root.expanded = !root.expanded

        Image {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            source: Qt.resolvedUrl("../screenshot.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Preferred size for a newly-placed widget: 400x400. Plasma saves each
        // instance's size after the user resizes it, so this only seeds the
        // very first placement of a fresh instance; existing widgets keep the
        // size stored in their configuration.
        Layout.preferredWidth: 400
        Layout.preferredHeight: 400

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.mediumSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: root.currentTitle
                textFormat: Text.PlainText
                visible: text !== ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.weight: Font.Bold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            QQC2.TextField {
                id: searchInput
                placeholderText: i18n("Search articles…")
                Layout.fillWidth: true
                text: root.searchQuery
                onTextChanged: {
                    if (root.searchQuery !== text) {
                        root.searchQuery = text;
                    }
                }
                rightPadding: clearButton.width

                QQC2.ToolButton {
                    id: clearButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon.name: "edit-clear"
                    visible: root.searchQuery !== ""
                    text: i18n("Clear search")
                    display: QQC2.AbstractButton.IconOnly
                    Accessible.name: text
                    QQC2.ToolTip.visible: hovered || visualFocus
                    QQC2.ToolTip.text: text
                    onClicked: {
                        // Clearing root.searchQuery alone isn't enough: once the user has
                        // typed anything, the one-way "text: root.searchQuery" binding above
                        // is broken (QML drops a binding on any direct write to the property,
                        // including the field's own internal write on keystrokes), so the
                        // field's text must be cleared explicitly too.
                        searchInput.text = "";
                        root.searchQuery = "";
                    }
                }
            }

            PlasmaComponents.Label {
                text: {
                    if (!root.allFeedsFailed)
                        return i18n("Last Updated: %1", root.lastUpdatedText);
                    // Nothing answered: keep the old time and say so honestly.
                    return root.allArticlesRaw.length > 0 ? i18n("No feed could be loaded. Showing articles from %1.", root.lastUpdatedText) : i18n("No feed could be loaded.");
                }
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Names the feeds that failed, with the reason, in a tooltip.
            PlasmaComponents.Label {
                id: failedLabel
                readonly property string details: {
                    var lines = [];
                    for (var i = 0; i < root.failedFeeds.length; i++)
                        lines.push(root.failedFeeds[i].error);
                    lines.push(i18n("Check the address in the settings, or wait for the next update."));
                    return lines.join("\n");
                }
                text: i18np("%1 of %2 feeds could not be loaded.", "%1 of %2 feeds could not be loaded.", root.failedFeeds.length, root.feedCount)
                textFormat: Text.PlainText
                visible: root.failedFeeds.length > 0
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                color: Kirigami.Theme.neutralTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Accessible.description: details

                HoverHandler {
                    id: failedHover
                }
                QQC2.ToolTip.visible: failedHover.hovered
                QQC2.ToolTip.text: details
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.1
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: listView
                width: parent.width // FIXED: Explicit width constraint prevents horizontal layout collapse
                model: articlesModel
                spacing: Kirigami.Units.smallSpacing
                boundsBehavior: Flickable.StopAtBounds
                // Keyboard: Tab reaches the list, arrow keys move, Enter opens the article.
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                highlightFollowsCurrentItem: true
                Keys.onReturnPressed: openCurrent()
                Keys.onEnterPressed: openCurrent()
                function openCurrent() {
                    if (currentItem)
                        currentItem.clicked();
                }

                delegate: PlasmaComponents.ItemDelegate {
                    id: delegateItem
                    width: listView.width
                    height: delegateColumn.implicitHeight + (Kirigami.Units.mediumSpacing * 2)
                    highlighted: ListView.isCurrentItem && listView.activeFocus
                    Accessible.name: model.title + ", " + model.source + ", " + model.date
                    // Feed links are untrusted: open only web addresses, never file:, javascript: or app schemes.
                    onClicked: if (/^https?:\/\//i.test(model.link))
                        Qt.openUrlExternally(model.link)

                    ColumnLayout {
                        id: delegateColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.mediumSpacing
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            text: model.title
                            textFormat: Text.PlainText
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: model.source + " - " + model.date
                            textFormat: Text.PlainText
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    text: root.searchQuery !== "" ? i18n("No articles match your search.") : i18n("No articles to show. Check your feed sources or your connection.")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Kirigami.Theme.disabledTextColor
                    font.italic: true
                    visible: articlesModel.count === 0
                }
            }
        }
    }

    // Forgets every article and failure, for when no feed is configured.
    function clearArticles() {
        articlesModel.clear();
        allArticlesRaw = [];
        keptArticles = {};
        failedFeeds = [];
        feedCount = 0;
        allFeedsFailed = false;
    }

    function fetchFeeds() {
        var jsonStr = "";
        try {
            jsonStr = Plasmoid.configuration.sourcesJson;
        } catch (e) {
            lastUpdatedText = i18n("Config Access Error");
            return;
        }

        if (!jsonStr || jsonStr.trim() === "") {
            lastUpdatedText = i18n("No sources configured");
            clearArticles();
            return;
        }

        // Plasmoid.configuration was restored from this instance's Settings on
        // startup, so this is normally a plain JSON array; parseSources() also
        // reads the formats older versions wrote.
        var sources = FeedParser.parseSources(jsonStr, Plasmoid.id);
        if (sources === null) {
            lastUpdatedText = i18n("JSON Parse Error");
            return;
        }
        var myExcludes = FeedParser.parseExcludes(Plasmoid.configuration.excludeRegexJson);

        if (sources.length === 0) {
            lastUpdatedText = i18n("No sources configured");
            clearArticles();
            return;
        }

        // Each address once; empty lines are skipped.
        var urls = [];
        for (var s = 0; s < sources.length; s++) {
            if (typeof sources[s] === "string" && sources[s].trim() !== "" && urls.indexOf(sources[s]) < 0)
                urls.push(sources[s]);
        }
        if (urls.length === 0) {
            lastUpdatedText = i18n("No sources configured");
            clearArticles();
            return;
        }

        // Increment fetch ID for this specific batch request transaction
        var fetchId = ++root.currentFetchId;
        var completedRequests = 0;
        var results = {}; // url -> {articles} or {error}

        function checkCompletion() {
            // Drop execution if a newer update cycle has taken over
            if (fetchId !== root.currentFetchId)
                return;

            if (completedRequests === urls.length) {
                var combined = FeedParser.combineResults(urls, results, root.keptArticles);
                keptArticles = combined.kept;
                failedFeeds = combined.failed;
                feedCount = urls.length;
                allFeedsFailed = combined.answered === 0;
                allArticlesRaw = FeedParser.mergeArticles(combined.articles, myExcludes);
                filterArticles();

                // "Last Updated" moves only when at least one feed answered.
                if (combined.answered > 0)
                    lastUpdatedText = FeedParser.formatTime(new Date());
            }
        }

        urls.forEach(function (url) {
            var finished = false;
            var timeoutTimer = null;
            var xhr = null;

            // result: {articles} when the feed answered, {error} when not.
            function finishOnce(result) {
                if (finished)
                    return;
                finished = true;
                results[url] = result;
                if (timeoutTimer) {
                    timeoutTimer.stop();
                    timeoutTimer.destroy();
                    timeoutTimer = null;
                }
                completedRequests++;
                checkCompletion();
            }

            try {
                xhr = new XMLHttpRequest();
                timeoutTimer = feedTimeoutComponent.createObject(root);
                timeoutTimer.triggered.connect(function () {
                    if (fetchId === root.currentFetchId) {
                        try {
                            xhr.abort();
                        } catch (e) {}
                    }
                    finishOnce({
                        error: i18n("%1: no answer within 15 seconds", url)
                    });
                });

                xhr.onreadystatechange = function () {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        if (fetchId !== root.currentFetchId) {
                            finishOnce({});
                            return;
                        } // Drop stale response early
                        if (xhr.status === 200) {
                            var parsed = FeedParser.parseFeed(xhr.responseText, url, i18n("No Title"));
                            if (parsed.length > 0 || FeedParser.isFeedText(xhr.responseText))
                                finishOnce({
                                    articles: parsed
                                });
                            else
                                finishOnce({
                                    error: i18n("%1: this address is not an RSS or Atom feed", url)
                                });
                        } else if (xhr.status === 0) {
                            finishOnce({
                                error: i18n("%1: could not connect", url)
                            });
                        } else {
                            finishOnce({
                                error: i18n("%1: the server answered with error %2", url, xhr.status)
                            });
                        }
                    }
                };
                xhr.open("GET", url, true);
                xhr.send();
                timeoutTimer.start();
            } catch (e) {
                finishOnce({
                    error: i18n("%1: could not connect", url)
                });
            }
        });
    }

    Component.onCompleted: {
        root.initializing = true;
        if (FeedParser.restoresStoredSettings(instanceSettings.seeded, instanceSettings.removed)) {
            // Normal startup: restore our values, overwriting whatever KDE left in appletsrc.
            Plasmoid.configuration.sourcesJson = instanceSettings.sourcesJson;
            Plasmoid.configuration.excludeRegexJson = instanceSettings.excludeRegexJson;
            Plasmoid.configuration.customTitle = instanceSettings.customTitle;
            Plasmoid.configuration.refreshTime = instanceSettings.refreshTime;
        } else {
            // First run of this widget: seed Settings from Plasmoid.configuration so that
            // any sources already configured (in older versions) are preserved. Also the
            // path for a new widget whose id was used by a removed one (D-022): what that
            // one stored is replaced, not taken over.
            instanceSettings.sourcesJson = Plasmoid.configuration.sourcesJson;
            instanceSettings.excludeRegexJson = Plasmoid.configuration.excludeRegexJson;
            instanceSettings.customTitle = Plasmoid.configuration.customTitle;
            instanceSettings.refreshTime = Plasmoid.configuration.refreshTime;
            instanceSettings.seeded = true;
            instanceSettings.removed = false;
        }
        // A feed list in one of the older formats is rewritten as the plain list
        // the settings page reads; the feeds stay the same (issue #34).
        var plainSources = FeedParser.plainSourcesJson(instanceSettings.sourcesJson, Plasmoid.id);
        if (plainSources !== instanceSettings.sourcesJson) {
            instanceSettings.sourcesJson = plainSources;
            Plasmoid.configuration.sourcesJson = plainSources;
        }
        root.initializing = false;
        fetchFeeds();
    }
}
