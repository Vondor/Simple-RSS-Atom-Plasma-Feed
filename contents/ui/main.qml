import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import QtCore

PlasmoidItem {
    id: root

    property string lastUpdatedText: i18n("Never")
    property var allArticlesRaw: [] 
    property string searchQuery: "" 
    property int currentFetchId: 0 // Prevents older network requests from overwriting newer ones
    property bool initializing: false  // blocks Connections writes during startup restore
    
    property string currentTitle: {
        try {
            return Plasmoid.configuration.customTitle.trim();
        } catch(e) {
            return "";
        }
    }

    onSearchQueryChanged: filterArticles()

    // Show the compact (logo) representation when the widget is smaller than
    // 250x250; the full content view is used at or above that size.
    switchWidth: 250
    switchHeight: 250

    ListModel { id: articlesModel }

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
            } catch(e) {
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

    // Per-instance settings in a plain INI file under ~/.config/.
    // category is keyed by Plasmoid.id so every instance is fully isolated.
    // Qt.labs.settings persists every property automatically — no manual I/O needed.
    Settings {
        id: instanceSettings
        category: "SimpleRSSFeed_" + Plasmoid.id

        property string sourcesJson:      "[]"
        property string excludeRegexJson: "[]"
        property string customTitle:      ""
        property int    refreshTime:      15
        // Becomes true after the first successful seed so Component.onCompleted
        // knows to RESTORE from here rather than seed from Plasmoid.configuration.
        property bool   seeded:           false
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

    // CUSTOM FORMATTERS FOR TIME, DATE, AND TIMEZONES
    function formatMyDateTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        
        var day = ("0" + date.getDate()).slice(-2);
        var month = ("0" + (date.getMonth() + 1)).slice(-2);
        var year = ("0" + date.getFullYear()).slice(-2);
        
        var hours = ("0" + date.getHours()).slice(-2);
        var minutes = ("0" + date.getMinutes()).slice(-2);
        
        var tz = "";
        try {
            var parts = new Intl.DateTimeFormat('en', { timeZoneName: 'short' }).formatToParts(date);
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].type === 'timeZoneName') {
                    tz = parts[i].value;
                    break;
                }
            }
        } catch (e) {
            var match = date.toString().match(/\(([^)]+)\)$/);
            if (match) tz = match[1];
        }
        
        return day + "." + month + "." + year + " " + hours + ":" + minutes + (tz ? " " + tz : "");
    }

    function formatMyTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        
        var hours = ("0" + date.getHours()).slice(-2);
        var minutes = ("0" + date.getMinutes()).slice(-2);
        
        var tz = "";
        try {
            var parts = new Intl.DateTimeFormat('en', { timeZoneName: 'short' }).formatToParts(date);
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].type === 'timeZoneName') {
                    tz = parts[i].value;
                    break;
                }
            }
        } catch (e) {
            var match = date.toString().match(/\(([^)]+)\)$/);
            if (match) tz = match[1];
        }
        
        return hours + ":" + minutes + (tz ? " " + tz : "");
    }

    function filterArticles() {
        articlesModel.clear();
        var query = root.searchQuery.trim();
        
        if (query === "") {
            for (var i = 0; i < allArticlesRaw.length; i++) {
                articlesModel.append(allArticlesRaw[i]);
            }
            return;
        }

        var regex;
        try {
            regex = new RegExp(query, "i");
        } catch (e) {
            return; 
        }

        for (var j = 0; j < allArticlesRaw.length; j++) {
            var item = allArticlesRaw[j];
            if (regex.test(item.title) || regex.test(item.source)) {
                articlesModel.append(item);
            }
        }
    }

    // Shown when the widget is smaller than switchWidth/switchHeight (250x250).
    // Draws the same logo as the widget-gallery preview (contents/screenshot.png)
    // instead of the metadata "Icon", which renders blank here. The MouseArea is
    // required for a custom compact view: it toggles the full popup on click.
    compactRepresentation: MouseArea {
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
                visible: text !== ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
                font.weight: Font.Bold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            QQC2.TextField {
                id: searchInput
                placeholderText: i18n("Regex Filter Articles...")
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
                text: i18n("Last Updated: %1", lastUpdatedText)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                opacity: 0.6
                Layout.fillWidth: true
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
                
                delegate: PlasmaComponents.ItemDelegate {
                    id: delegateItem
                    width: listView.width
                    height: delegateColumn.implicitHeight + (Kirigami.Units.mediumSpacing * 2)
                    onClicked: if (model.link) Qt.openUrlExternally(model.link)
                    
                    ColumnLayout {
                        id: delegateColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Kirigami.Units.mediumSpacing
                        spacing: 4

                        PlasmaComponents.Label {
                            text: model.title
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: model.source + " - " + model.date
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            opacity: 0.65
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    text: root.searchQuery !== "" ? i18n("No articles match your filter.") : i18n("No articles to show. Check your feed sources or your connection.")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.5
                    font.italic: true
                    visible: articlesModel.count === 0
                }
            }
        }
    }


    function fetchFeeds() {
        var jsonStr = "";
        try {
            jsonStr = Plasmoid.configuration.sourcesJson;
        } catch(e) {
            lastUpdatedText = i18n("Config Access Error");
            return;
        }

        if (!jsonStr || jsonStr.trim() === "") {
            lastUpdatedText = i18n("No sources configured");
            articlesModel.clear();
            allArticlesRaw = [];
            return;
        }

        // Plasmoid.configuration was pre-populated from SQLite on startup, so this
        // is normally a plain JSON array. Legacy branches handle old-format installs.
        var sources    = [];
        var myExcludes = [];
        try {
            var parsed = JSON.parse(jsonStr);
            if (Array.isArray(parsed)) {
                sources = parsed;
            } else if (parsed && typeof parsed === "object") {
                if      (parsed.v === 1) sources = parsed.sources || [];
                else if (parsed.v === 2) sources = ((parsed.instances || {})[String(Plasmoid.id)] || {}).sources || [];
            }
        } catch(e) {
            lastUpdatedText = i18n("JSON Parse Error");
            return;
        }

        try { myExcludes = JSON.parse(Plasmoid.configuration.excludeRegexJson || "[]"); } catch(e) {}

        if (!Array.isArray(sources) || sources.length === 0) {
            lastUpdatedText = i18n("No sources configured");
            articlesModel.clear();
            allArticlesRaw = [];
            return;
        }

        // Increment fetch ID for this specific batch request transaction
        var fetchId = ++root.currentFetchId;
        var completedRequests = 0;
        var fetchedArticles = [];

        function checkCompletion() {
            // Drop execution if a newer update cycle has taken over
            if (fetchId !== root.currentFetchId) return;

            if (completedRequests === sources.length) {
                // Excludes were already extracted from the v2 config above.
                var excludePatterns = Array.isArray(myExcludes) ? myExcludes : [];

                var compiledExcludes = [];
                for (var k = 0; k < excludePatterns.length; k++) {
                    try {
                        if (excludePatterns[k].trim() !== "") {
                            compiledExcludes.push(new RegExp(excludePatterns[k], "i"));
                        }
                    } catch(err) {}
                }

                var allowedArticles = [];
                for (var i = 0; i < fetchedArticles.length; i++) {
                    var article = fetchedArticles[i];
                    var shouldExclude = false;
                    for (var r = 0; r < compiledExcludes.length; r++) {
                        if (compiledExcludes[r].test(article.title) || compiledExcludes[r].test(article.source)) {
                            shouldExclude = true;
                            break;
                        }
                    }
                    if (!shouldExclude) {
                        allowedArticles.push(article);
                    }
                }

                // De-duplicate: same article can appear if a feed URL is listed twice,
                // or if two different sources syndicate the same item. Key on the link
                // when present, otherwise fall back to source+title.
                var seenKeys = {};
                var dedupedArticles = [];
                for (var d = 0; d < allowedArticles.length; d++) {
                    var dedupArticle = allowedArticles[d];
                    var dedupKey = dedupArticle.link ? dedupArticle.link : (dedupArticle.source + "|" + dedupArticle.title);
                    if (!seenKeys[dedupKey]) {
                        seenKeys[dedupKey] = true;
                        dedupedArticles.push(dedupArticle);
                    }
                }

                dedupedArticles.sort(function(a, b) { return b.timestamp - a.timestamp; });
                allArticlesRaw = dedupedArticles;
                filterArticles(); 
                
                lastUpdatedText = formatMyTime(new Date());
            }
        }

        sources.forEach(function(url) {
            if (!url || url.trim() === "") {
                completedRequests++;
                checkCompletion();
                return;
            }

            var finished = false;
            var timeoutTimer = null;
            var xhr = null;

            function finishOnce() {
                if (finished) return;
                finished = true;
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
                timeoutTimer.triggered.connect(function() {
                    if (fetchId === root.currentFetchId) {
                        try { xhr.abort(); } catch(e) {}
                    }
                    finishOnce();
                });

                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        if (fetchId !== root.currentFetchId) { finishOnce(); return; } // Drop stale response early
                        if (xhr.status === 200) {
                            parseFeed(xhr.responseText, url, fetchedArticles);
                        }
                        finishOnce();
                    }
                };
                xhr.open("GET", url, true);
                xhr.send();
                timeoutTimer.start();
            } catch (e) {
                finishOnce();
            }
        });
    }

    function parseFeed(xmlText, sourceUrl, targetArray) {
        if (!xmlText) return;
        var feedTitleMatch = xmlText.match(/<title[^>]*>([\s\S]*?)<\/title>/);
        var feedTitle = feedTitleMatch ? stripTags(feedTitleMatch[1]) : sourceUrl;
        var itemRegex = /<(item|entry)[^>]*>([\s\S]*?)<\/\1>/g;
        var match;

        while ((match = itemRegex.exec(xmlText)) !== null) {
            var content = match[2];
            var titleM = content.match(/<title[^>]*>([\s\S]*?)<\/title>/);
            
            var link = "";
            // Atom entries can list multiple self-closing <link> tags (rel="alternate",
            // "self", "edit", etc). Prefer rel="alternate" - the actual article URL -
            // regardless of whether "rel" or "href" comes first in the tag.
            var altM = content.match(/<link\b[^>]*\brel=["']alternate["'][^>]*\bhref=["']([^"']+)["']/) ||
                       content.match(/<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\brel=["']alternate["']/);
            if (altM) {
                link = altM[1].trim();
            } else {
                var linkM = content.match(/<link[^>]*>([\s\S]*?)<\/link>/);
                if (linkM && linkM[1].trim() !== "" && !linkM[1].includes("href=")) {
                    // RSS-style: <link>http://example.com</link>
                    link = stripTags(linkM[1]).trim();
                } else {
                    // Atom fallback: no rel="alternate" found, take the first href present
                    var hM = content.match(/<link[^>]+href=["']([^"']+)["']/);
                    if (hM) link = hM[1].trim();
                }
            }
            
            var dM = content.match(/<(pubDate|updated|published)[^>]*>([\s\S]*?)<\/\1>/);
            var pubDate = dM ? stripTags(dM[2]) : "";
            var ts = 0;
            var fmtDate = pubDate;
            try {
                if (pubDate) {
                    var d = new Date(pubDate);
                    if (!isNaN(d.getTime())) { 
                        ts = d.getTime(); 
                        fmtDate = formatMyDateTime(d); 
                    }
                }
            } catch(e) {}

            targetArray.push({
                "title": titleM ? stripTags(titleM[1]) : "No Title",
                "source": feedTitle,
                "date": fmtDate,
                "timestamp": ts,
                "link": link
            });
        }
    }

    function decodeEntities(text) {
        if (!text) return text;
        var named = {
            "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
            "nbsp": " ", "mdash": "\u2014", "ndash": "\u2013", "hellip": "\u2026",
            "rsquo": "\u2019", "lsquo": "\u2018", "rdquo": "\u201D", "ldquo": "\u201C"
        };
        var result = text.replace(/&(amp|lt|gt|quot|apos|nbsp|mdash|ndash|hellip|rsquo|lsquo|rdquo|ldquo);/g, function(m, name) {
            return named[name] !== undefined ? named[name] : m;
        });
        result = result.replace(/&#(\d+);/g, function(m, dec) {
            return String.fromCharCode(parseInt(dec, 10));
        });
        result = result.replace(/&#x([0-9a-fA-F]+);/g, function(m, hex) {
            return String.fromCharCode(parseInt(hex, 16));
        });
        return result;
    }

    function stripTags(html) {
        if (!html) return "";
        var clean = html.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
        clean = clean.replace(/<\/?[^>]+(>|$)/g, "");
        return decodeEntities(clean).trim();
    }
    
    Component.onCompleted: {
        root.initializing = true;
        if (instanceSettings.seeded) {
            // Normal startup: restore our values, overwriting whatever KDE left in appletsrc.
            Plasmoid.configuration.sourcesJson      = instanceSettings.sourcesJson;
            Plasmoid.configuration.excludeRegexJson = instanceSettings.excludeRegexJson;
            Plasmoid.configuration.customTitle      = instanceSettings.customTitle;
            Plasmoid.configuration.refreshTime      = instanceSettings.refreshTime;
        } else {
            // First run of this version: seed Settings from Plasmoid.configuration so that
            // any sources already configured (in older versions) are preserved.
            instanceSettings.sourcesJson      = Plasmoid.configuration.sourcesJson;
            instanceSettings.excludeRegexJson = Plasmoid.configuration.excludeRegexJson;
            instanceSettings.customTitle      = Plasmoid.configuration.customTitle;
            instanceSettings.refreshTime      = Plasmoid.configuration.refreshTime;
            instanceSettings.seeded           = true;
        }
        root.initializing = false;
        fetchFeeds();
    }
}
