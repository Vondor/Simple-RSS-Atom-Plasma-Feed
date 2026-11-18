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

// The stored sourcesJson as the plain array text the settings page reads.
// A value in one of the older formats is converted, so the page lists those
// feeds instead of an empty list (issue #34); a plain array and text that is
// not valid JSON come back unchanged, so nothing is lost by converting.
function plainSourcesJson(jsonStr, plasmoidId) {
    var parsed;
    try {
        parsed = JSON.parse(jsonStr);
    } catch (e) {
        return jsonStr;
    }
    if (Array.isArray(parsed))
        return jsonStr;
    return JSON.stringify(parseSources(jsonStr, plasmoidId));
}

// Whether a starting widget takes over the settings stored under its
// Plasmoid.id (D-022). Plasma hands the id of a removed widget to a new one,
// so settings marked as removed belong to a widget that no longer exists and
// are not taken over; the new widget then starts from its defaults.
function restoresStoredSettings(seeded, removed) {
    return seeded === true && removed !== true;
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

// Locale.ShortFormat. The Locale enum is not visible in a .pragma library
// script, so its value (documented as 1 in the QML Locale type) is used.
var SHORT_FORMAT = 1;

// The locale to format with: the named one (used by the tests), otherwise
// the user's own, which Plasma takes from the Region & Language settings.
function formatLocale(localeName) {
    return localeName ? Qt.locale(localeName) : Qt.locale();
}

// The article date shown in the list: date and time in local time, in the
// user's short date-time format (for example "17.11.26 10:00" in German,
// "11/17/26 10:00 AM" in US English). QML's engine has no Intl, so the
// time zone name is not shown.
function formatDateTime(date, localeName) {
    if (!date || isNaN(date.getTime()))
        return "";
    return date.toLocaleString(formatLocale(localeName), SHORT_FORMAT);
}

// The time of day in the user's short time format, used for "Last Updated".
function formatTime(date, localeName) {
    if (!date || isNaN(date.getTime()))
        return "";
    return date.toLocaleTimeString(formatLocale(localeName), SHORT_FORMAT);
}

var MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

// Offsets in minutes of the zone names RFC 822 defines, plus a few that
// feeds use anyway. A name not listed here counts as UTC.
var ZONE_OFFSETS = {
    "ut": 0,
    "utc": 0,
    "gmt": 0,
    "z": 0,
    "est": -300,
    "edt": -240,
    "cst": -360,
    "cdt": -300,
    "mst": -420,
    "mdt": -360,
    "pst": -480,
    "pdt": -420,
    "akst": -540,
    "akdt": -480,
    "hst": -600,
    "bst": 60,
    "ist": 60,
    "wet": 0,
    "west": 60,
    "cet": 60,
    "cest": 120,
    "met": 60,
    "mest": 120,
    "eet": 120,
    "eest": 180,
    "msk": 180,
    "jst": 540,
    "kst": 540,
    "aest": 600,
    "aedt": 660
};

// Reads an RFC 822 / RFC 2822 date as RSS uses it, such as
// "Tue, 3 Jun 2025 09:00:00 GMT": the weekday is optional, seconds are
// optional, the zone is a name ("PDT", "UT"), an offset ("+0200", "-07:00")
// or missing (then UTC), and a trailing comment like "(PDT)" is ignored.
// Returns milliseconds since the epoch, or NaN when the text is not such a date.
function parseRfc822Date(text) {
    var m = /^\s*(?:[A-Za-z]+\.?,?\s*)?(\d{1,2})[\s-]+([A-Za-z]{3,})\.?[\s-]+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]{1,5}|[+-]\d{2}:?\d{2})?\s*(?:\([^)]*\))?\s*$/.exec(text);
    if (!m)
        return NaN;
    var month = MONTHS.indexOf(m[2].slice(0, 3).toLowerCase());
    var day = parseInt(m[1], 10);
    var year = parseInt(m[3], 10);
    var hour = parseInt(m[4], 10);
    var minute = parseInt(m[5], 10);
    var second = m[6] ? parseInt(m[6], 10) : 0;
    if (month < 0 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60)
        return NaN;
    if (m[3].length === 2)
        year += year < 50 ? 2000 : 1900;
    else if (m[3].length === 3)
        year += 1900;
    var offset = 0;
    var zone = m[7] || "";
    if (/^[+-]/.test(zone)) {
        var digits = zone.replace(":", "");
        offset = (parseInt(digits.slice(1, 3), 10) * 60 + parseInt(digits.slice(3, 5), 10)) * (zone.charAt(0) === "-" ? -1 : 1);
    } else if (zone !== "") {
        offset = ZONE_OFFSETS[zone.toLowerCase()] || 0;
    }
    // A leap second (60) is read as 59, as Date cannot hold it.
    return Date.UTC(year, month, day, hour, minute, Math.min(second, 59)) - offset * 60000;
}

// Reads a feed date: RFC 822 as in RSS, otherwise whatever the engine's own
// Date understands (ISO 8601 as in Atom and dc:date). Returns milliseconds
// since the epoch, or NaN when the text is not a date.
function parseDate(text) {
    if (!text)
        return NaN;
    var ms = parseRfc822Date(text);
    if (isNaN(ms)) {
        try {
            ms = new Date(text).getTime();
        } catch (e) {
            ms = NaN;
        }
    }
    return ms;
}

// Named entities that feeds commonly use. XML itself only defines the first
// five; the rest come from HTML and appear in feeds anyway.
var NAMED_ENTITIES = {
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

// Decodes named and numeric character references in one pass, so that a
// decoded "&" never starts a second reference ("&amp;#60;" is the text
// "&#60;", issue #30). Code points above U+FFFF (emoji) are kept whole; an
// unknown name or an invalid number is left as written.
function decodeEntities(text) {
    if (!text)
        return text;
    return text.replace(/&(?:#[xX]([0-9a-fA-F]+)|#([0-9]+)|([a-zA-Z]+));/g, function (m, hex, dec, name) {
        if (name !== undefined && name !== "")
            return NAMED_ENTITIES[name] !== undefined ? NAMED_ENTITIES[name] : m;
        var code = (hex !== undefined && hex !== "") ? parseInt(hex, 16) : parseInt(dec, 10);
        if (!(code > 0) || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF))
            return m;
        return String.fromCodePoint(code);
    });
}

// Removes markup: comments, and tags that start like a real tag ("<b>",
// "</b>", "<br/>"). A "<" followed by a space or digit is text ("3 < 5").
function removeTags(text) {
    return text.replace(/<!--[\s\S]*?(-->|$)/g, "").replace(/<\/?[A-Za-z][^>]*(>|$)/g, "");
}

// Turns the content of an element into plain text to show: tags removed,
// entities decoded once, runs of whitespace (line breaks, indentation)
// collapsed to one space. A CDATA section is cut out before the tags are
// removed, so a "<" inside it can never swallow the text around it; its own
// content is treated like HTML (tags removed, entities decoded), which is how
// feeds use CDATA in practice.
function stripTags(html) {
    if (!html)
        return "";
    var out = "";
    var cdataRegex = /<!\[CDATA\[([\s\S]*?)(\]\]>|$)/g;
    var last = 0;
    var m;
    while ((m = cdataRegex.exec(html)) !== null) {
        out += decodeEntities(removeTags(html.slice(last, m.index)));
        out += decodeEntities(removeTags(m[1]));
        last = cdataRegex.lastIndex;
        if (m[0] === "")
            break;
    }
    out += decodeEntities(removeTags(html.slice(last)));
    return out.replace(/\s+/g, " ").trim();
}

// The text of an attribute value: entities decoded, whitespace trimmed.
function attributeText(value) {
    return decodeEntities(value || "").trim();
}

// Limits that keep one big feed from freezing plasmashell while it is parsed
// on the interface thread (D-018). A feed is read up to MAX_FEED_CHARS
// characters and at most MAX_ITEMS_PER_FEED articles are taken, in document
// order: feeds list their newest articles first. About 100 articles per feed
// parse in well under a second; the 2 MB cap also bounds a feed of very long
// articles. An article cut off by the size limit is dropped.
var MAX_FEED_CHARS = 2000000;
var MAX_ITEMS_PER_FEED = 100;

// Turns one feed document (RSS <item> or Atom <entry>) into articles:
// {title, source, date, timestamp, link}. noTitle is the (translated) text
// for an item without a title. Returns [] for empty or unreadable text.
// limits is optional ({maxChars, maxItems}, for tests); it defaults to the
// two limits above.
function parseFeed(xmlText, sourceUrl, noTitle, limits) {
    var articles = [];
    if (!xmlText)
        return articles;
    var maxChars = limits && limits.maxChars > 0 ? limits.maxChars : MAX_FEED_CHARS;
    var maxItems = limits && limits.maxItems > 0 ? limits.maxItems : MAX_ITEMS_PER_FEED;
    if (xmlText.length > maxChars)
        xmlText = xmlText.slice(0, maxChars);
    // The source name is the feed's own <title>: the first one before the
    // first item, not counting the <title> of a channel <image>.
    var firstItem = xmlText.search(/<(item|entry)\b/);
    var head = (firstItem >= 0 ? xmlText.slice(0, firstItem) : xmlText).replace(/<image\b[^>]*>[\s\S]*?<\/image>/g, "");
    var feedTitleMatch = head.match(/<title\b[^>]*>([\s\S]*?)<\/title>/);
    var feedTitle = feedTitleMatch ? stripTags(feedTitleMatch[1]) : "";
    if (feedTitle === "")
        feedTitle = sourceUrl;
    // "\b" keeps RSS 1.0's <items> list from being read as an item.
    var itemRegex = /<(item|entry)\b[^>]*>([\s\S]*?)<\/\1>/g;
    var match;

    while (articles.length < maxItems && (match = itemRegex.exec(xmlText)) !== null) {
        var content = match[2];
        var titleM = content.match(/<title\b[^>]*>([\s\S]*?)<\/title>/);

        var link = "";
        // Atom entries can list multiple self-closing <link> tags (rel="alternate",
        // "self", "edit", etc). Prefer rel="alternate" - the actual article URL -
        // regardless of whether "rel" or "href" comes first in the tag.
        var altM = content.match(/<link\b[^>]*\brel=["']alternate["'][^>]*\bhref=["']([^"']+)["']/) || content.match(/<link\b[^>]*\bhref=["']([^"']+)["'][^>]*\brel=["']alternate["']/);
        if (altM) {
            link = attributeText(altM[1]);
        } else {
            var linkM = content.match(/<link[^>]*>([\s\S]*?)<\/link>/);
            if (linkM && linkM[1].trim() !== "" && !linkM[1].includes("href=")) {
                // RSS-style: <link>http://example.com</link>
                link = stripTags(linkM[1]).trim();
            } else {
                // Atom fallback: no rel="alternate" found, take the first href present
                var hM = content.match(/<link[^>]+href=["']([^"']+)["']/);
                if (hM)
                    link = attributeText(hM[1]);
            }
        }
        if (link === "") {
            // RSS 2.0: an item without <link> may name its address in <guid>,
            // which is a permalink unless isPermaLink="false". Only a web
            // address is taken, as a guid is often just an id.
            var gM = content.match(/<guid\b([^>]*)>([\s\S]*?)<\/guid>/);
            if (gM && !/\bisPermaLink=["']false["']/i.test(gM[1])) {
                var guid = stripTags(gM[2]);
                if (/^https?:\/\//i.test(guid))
                    link = guid;
            }
        }

        // The first date found, in this order: when the article was
        // published (Atom <published>, RSS 2.0 <pubDate>, RSS 1.0 <dc:date>),
        // and only then when it was last changed (Atom <updated>).
        var pubDate = "";
        var dateTags = ["published", "pubDate", "dc:date", "updated"];
        for (var t = 0; t < dateTags.length && pubDate === ""; t++) {
            var dM = content.match(new RegExp("<" + dateTags[t] + "\\b[^>]*>([\\s\\S]*?)</" + dateTags[t] + ">"));
            if (dM)
                pubDate = stripTags(dM[1]);
        }
        var ts = parseDate(pubDate);
        var fmtDate = pubDate;
        if (isNaN(ts))
            ts = 0;
        else
            fmtDate = formatDateTime(new Date(ts));

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

// Whether a document is an RSS or Atom feed at all, so a page that answers
// with HTML (a login page, an error page) is reported instead of being taken
// for a feed without articles.
function isFeedText(xmlText) {
    return /<(rss|feed|rdf:RDF)\b/.test(xmlText || "");
}

// Combines one refresh with the articles kept from earlier refreshes, so a
// feed that fails keeps showing what it showed before (issue #32, D-019).
// urls: the configured addresses. results: {url: {articles: [...]}} for a feed
// that answered, {url: {error: "text"}} for one that failed. previous: the
// articles kept per address by the last refresh ({url: [...]}), in memory only.
// Returns {kept, articles, failed: [{url, error}], answered}; kept holds only
// the configured addresses, so a removed feed's articles are forgotten.
function combineResults(urls, results, previous) {
    var before = previous || {};
    var kept = {};
    var articles = [];
    var failed = [];
    var answered = 0;
    for (var i = 0; i < urls.length; i++) {
        var url = urls[i];
        var result = results[url] || {
            error: ""
        };
        if (result.articles) {
            answered++;
            kept[url] = result.articles;
        } else {
            failed.push({
                url: url,
                error: result.error || ""
            });
            if (before[url])
                kept[url] = before[url];
        }
        if (kept[url])
            articles = articles.concat(kept[url]);
    }
    return {
        kept: kept,
        articles: articles,
        failed: failed,
        answered: answered
    };
}

// The articles matching the search box: plain text, not case-sensitive, found
// anywhere in the title or source (D-020). An empty query matches all. Typed
// text is never read as a regular expression, so "C++" or "what?" find
// exactly what was typed.
function filterArticles(articles, query) {
    var q = (query || "").trim().toLowerCase();
    if (q === "")
        return articles.slice();
    var result = [];
    for (var j = 0; j < articles.length; j++) {
        var title = String(articles[j].title || "").toLowerCase();
        var source = String(articles[j].source || "").toLowerCase();
        if (title.indexOf(q) !== -1 || source.indexOf(q) !== -1)
            result.push(articles[j]);
    }
    return result;
}

// The address to store for what the user typed as a feed address, or "" when
// it is not a web address (D-020). Without a scheme, https:// is put in front
// ("kde.org/feed"), and then the host needs a dot, so a half-typed "kde" is
// not taken; only http and https are accepted; the host may not hold spaces,
// "@" or ":" (apart from a port number).
function normalizeFeedUrl(text) {
    var t = String(text || "").trim();
    if (t === "")
        return "";
    if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(t)) {
        if (!/^[^\/?#]*\./.test(t))
            return "";
        t = "https://" + t;
    }
    if (!/^https?:\/\/([^\s\/?#:@\[\]]+|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?([\/?#]\S*)?$/i.test(t))
        return "";
    return t;
}

// Whether text is a valid case-insensitive regular expression.
function isValidPattern(text) {
    try {
        new RegExp(text, "i");
        return true;
    } catch (e) {
        return false;
    }
}

// The blacklist entry to store for what the user typed (D-020): a valid
// regular expression as it is, anything else (such as "C++") turned into one
// that matches the typed text literally. Stored entries keep their meaning.
function blacklistPattern(text) {
    var t = String(text || "").trim();
    if (t === "" || isValidPattern(t))
        return t;
    return t.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
}
