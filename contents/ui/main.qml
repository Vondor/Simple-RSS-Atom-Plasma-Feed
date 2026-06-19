import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    property string lastUpdatedText: i18n("Never")
    property var allArticlesRaw: [] 
    property string searchQuery: "" 
    
    property string currentTitle: {
        try {
            return root.Plasmoid.configuration.customTitle.trim();
        } catch(e) {
            return "";
        }
    }

    onSearchQueryChanged: filterArticles()

    switchWidth: Kirigami.Units.gridUnit * 15
    switchHeight: Kirigami.Units.gridUnit * 20

    ListModel { id: articlesModel }

    Timer {
        id: refreshTimer
        interval: {
            try {
                return root.Plasmoid.configuration.refreshTime * 60 * 1000;
            } catch(e) {
                return 900000; 
            }
        }
        running: true
        repeat: true
        onTriggered: fetchFeeds()
    }

    Connections {
        target: root.Plasmoid.configuration
        ignoreUnknownSignals: true
        function onSourcesJsonChanged() { fetchFeeds(); }
        function onRefreshTimeChanged() { refreshTimer.restart(); fetchFeeds(); }
        function onExcludeRegexJsonChanged() { fetchFeeds(); } 
    }

    // CUSTOM FORMATTERS FOR TIME, DATE, AND TIMEZONES
    function formatMyDateTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        
        var day = ("0" + date.getDate()).slice(-2);
        var month = ("0" + (date.getMonth() + 1)).slice(-2);
        var year = ("0" + date.getFullYear()).slice(-2); // Short year version (yy)
        
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

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        spacing: 0

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
                    onClicked: root.searchQuery = "" 
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
                model: articlesModel
                spacing: Kirigami.Units.smallSpacing
                
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
            }
        }
    }

    function fetchFeeds() {
        var jsonStr = "";
        try {
            jsonStr = root.Plasmoid.configuration.sourcesJson;
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

        var sources = [];
        try {
            sources = JSON.parse(jsonStr);
        } catch(e) {
            lastUpdatedText = i18n("JSON Parse Error");
            return;
        }

        if (!Array.isArray(sources) || sources.length === 0) {
            lastUpdatedText = i18n("No sources configured");
            articlesModel.clear();
            allArticlesRaw = [];
            return;
        }

        var completedRequests = 0;
        var fetchedArticles = [];

        function checkCompletion() {
            if (completedRequests === sources.length) {
                var excludePatterns = [];
                try {
                    var exJson = root.Plasmoid.configuration.excludeRegexJson;
                    if (exJson) {
                        excludePatterns = JSON.parse(exJson);
                    }
                } catch(e) {
                    console.error("Failed parsing exclude rules json:", e);
                }

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

                allowedArticles.sort(function(a, b) { return b.timestamp - a.timestamp; });
                allArticlesRaw = allowedArticles;
                filterArticles(); 
                
                // FIXED: Formats widget header layout update time with hh:mm ShortTZ rule
                lastUpdatedText = formatMyTime(new Date());
            }
        }

        sources.forEach(function(url) {
            if (!url || url.trim() === "") {
                completedRequests++;
                checkCompletion();
                return;
            }

            try {
                var xhr = new XMLHttpRequest();
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        if (xhr.status === 200) {
                            parseFeed(xhr.responseText, url, fetchedArticles);
                        }
                        completedRequests++;
                        checkCompletion();
                    }
                };
                xhr.open("GET", url, true);
                xhr.send();
            } catch (e) {
                completedRequests++;
                checkCompletion();
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
            var linkM = content.match(/<link[^>]*>([\s\S]*?)<\/link>/);
            if (linkM && linkM[1].trim() !== "") {
                link = stripTags(linkM[1]).trim();
            } else {
                var hM = content.match(/<link[^+ href=["']([^"']+)["']/);
                if (hM) link = hM[1].trim();
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
                        // FIXED: Formats article date strings strictly to dd.mm.yy hh:mm ShortTZ
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

    function stripTags(html) {
        if (!html) return "";
        var clean = html.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
        return clean.replace(/<\/?[^>]+(>|$)/g, "").trim();
    }
    
    Component.onCompleted: fetchFeeds()
}
