// SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Feed parsing and list building for the widget, kept free of QML items so
// that ci/test-parser.py can run it in Qt's own JavaScript engine (D-015).
// main.qml imports it as FeedParser. Everything here is a pure function: no
// network, no settings, no i18n() (a .pragma library script has no access to
// the widget's context, so translated strings are passed in by the caller).
// Feed text is untrusted input (docs/THREAT_MODEL.md): it is only ever turned
// into plain strings here.

.pragma library

// Reads the feed URLs from the stored sourcesJson setting. Returns an array
// (possibly empty), or null when the text is not valid JSON. Besides the
// current plain array it still reads the formats older versions wrote
// (AGENTS.md 3.1.7): {"v":1,"sources":[...]} and
// {"v":2,"instances":{"<Plasmoid.id>":{"sources":[...]}}}.
function parseSources(jsonStr, plasmoidId) {
    var parsed;
    try {
        parsed = JSON.parse(jsonStr);
    } catch (e) {
        return null;
    }
    var sources = [];
    if (Array.isArray(parsed)) {
        sources = parsed;
    } else if (parsed && typeof parsed === "object") {
        if (parsed.v === 1)
            sources = parsed.sources || [];
        else if (parsed.v === 2)
            sources = ((parsed.instances || {})[String(plasmoidId)] || {}).sources || [];
    }
    return Array.isArray(sources) ? sources : [];
}

// Reads the stored excludeRegexJson setting; anything unreadable is no blacklist.
function parseExcludes(jsonStr) {
    try {
        var parsed = JSON.parse(jsonStr || "[]");
        return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
        return [];
    }
}

// The short time zone name for a date, such as "CET", or "" if unknown.
// QML's engine has no Intl, so the fallback reads it from Date.toString().
function timeZoneName(date) {
    var tz = "";
    try {
        var parts = new Intl.DateTimeFormat('en', {
            timeZoneName: 'short'
        }).formatToParts(date);
        for (var i = 0; i < parts.length; i++) {
            if (parts[i].type === 'timeZoneName') {
                tz = parts[i].value;
                break;
            }
        }
    } catch (e) {
        var match = date.toString().match(/\(([^)]+)\)$/);
        if (match)
            tz = match[1];
    }
    return tz;
}

function pad2(n) {
    return ("0" + n).slice(-2);
}

// "DD.MM.YY HH:MM TZ" in local time, the article date shown in the list.
function formatDateTime(date) {
    if (!date || isNaN(date.getTime()))
        return "";
    var tz = timeZoneName(date);
    return pad2(date.getDate()) + "." + pad2(date.getMonth() + 1) + "." + pad2(date.getFullYear()) + " " + pad2(date.getHours()) + ":" + pad2(date.getMinutes()) + (tz ? " " + tz : "");
}

// "HH:MM TZ" in local time, used for "Last Updated".
function formatTime(date) {
    if (!date || isNaN(date.getTime()))
        return "";
    var tz = timeZoneName(date);
    return pad2(date.getHours()) + ":" + pad2(date.getMinutes()) + (tz ? " " + tz : "");
}

function decodeEntities(text) {
    if (!text)
        return text;
    var named = {
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": " ",
        "mdash": "—",
        "ndash": "–",
        "hellip": "…",
        "rsquo": "’",
        "lsquo": "‘",
        "rdquo": "”",
        "ldquo": "“"
    };
    var result = text.replace(/&(amp|lt|gt|quot|apos|nbsp|mdash|ndash|hellip|rsquo|lsquo|rdquo|ldquo);/g, function (m, name) {
        return named[name] !== undefined ? named[name] : m;
    });
    result = result.replace(/&#(\d+);/g, function (m, dec) {
        return String.fromCharCode(parseInt(dec, 10));
    });
    result = result.replace(/&#x([0-9a-fA-F]+);/g, function (m, hex) {
        return String.fromCharCode(parseInt(hex, 16));
    });
    return result;
}

function stripTags(html) {
    if (!html)
        return "";
    var clean = html.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1");
    clean = clean.replace(/<\/?[^>]+(>|$)/g, "");
    return decodeEntities(clean).trim();
}

// Turns one feed document (RSS <item> or Atom <entry>) into articles:
// {title, source, date, timestamp, link}. noTitle is the (translated) text
// for an item without a title. Returns [] for empty or unreadable text.
function parseFeed(xmlText, sourceUrl, noTitle) {
    var articles = [];
    if (!xmlText)
        return articles;
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
        var altM = content.match(/<link\b[^>]*\brel=["']alternate["'][^>]*\bhref=["']([^"']+)["']/) || content.match(/<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\brel=["']alternate["']/);
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
                if (hM)
                    link = hM[1].trim();
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
                    fmtDate = formatDateTime(d);
                }
            }
        } catch (e) {}

        articles.push({
            "title": titleM ? stripTags(titleM[1]) : noTitle,
            "source": feedTitle,
            "date": fmtDate,
            "timestamp": ts,
            "link": link
        });
    }
    return articles;
}

// Builds the list shown in the widget from all fetched articles: drops those
// whose title or source matches a blacklist pattern (case-insensitive; an
// invalid pattern is skipped), shows duplicates once and sorts newest first.
function mergeArticles(articles, excludePatterns) {
    var compiledExcludes = [];
    var patterns = Array.isArray(excludePatterns) ? excludePatterns : [];
    for (var k = 0; k < patterns.length; k++) {
        try {
            if (patterns[k].trim() !== "") {
                compiledExcludes.push(new RegExp(patterns[k], "i"));
            }
        } catch (err) {}
    }

    var allowedArticles = [];
    for (var i = 0; i < articles.length; i++) {
        var article = articles[i];
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

    dedupedArticles.sort(function (a, b) {
        return b.timestamp - a.timestamp;
    });
    return dedupedArticles;
}

// The articles matching the search box: a case-insensitive regular expression
// on title or source. An empty query matches all; an invalid one matches none.
function filterArticles(articles, query) {
    var q = (query || "").trim();
    if (q === "")
        return articles.slice();
    var regex;
    try {
        regex = new RegExp(q, "i");
    } catch (e) {
        return [];
    }
    var result = [];
    for (var j = 0; j < articles.length; j++) {
        if (regex.test(articles[j].title) || regex.test(articles[j].source))
            result.push(articles[j]);
    }
    return result;
}
