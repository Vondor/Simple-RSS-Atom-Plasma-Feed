#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Fabian Drywa <dev@serpentsoftware.de>
# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests for contents/ui/feedparser.js in Qt's own QML engine (D-015).

The file is imported exactly as main.qml imports it (a `.pragma library`
script under `import "feedparser.js"`), so the JavaScript runs in the same
engine and with the same quirks as on the desktop (for example, no `Intl`).
Every feed below is synthetic, written for this test (AGENTS.md 3.1.1).

A case marked `known="#NN"` documents a bug that the issue will fix: it is
expected to fail today and is reported, not counted as a failure. When a fix
makes it pass, the run fails until the marker is removed, so the case then
guards the fix.

Usage:  python3 ci/test-parser.py        (exit code 0 when all cases pass)
Needs:  PySide6 6.12 in the running Python, for example
        python3 -m venv .venv && .venv/bin/pip install pyside6-essentials==6.12.0
        .venv/bin/python ci/test-parser.py
PySide6 is a test tool only; the widget itself does not use it.
"""

import json
import os
import sys
import time
from pathlib import Path

# Dates are formatted in local time and in the user's format; fix the zone
# and the locale (German, the format the widget used before #31) before Qt
# reads them. Qt brings its own locale data, so no system locale is needed.
os.environ["TZ"] = "UTC"
os.environ["LC_ALL"] = "de_DE.UTF-8"
time.tzset()

try:
    from PySide6.QtCore import QCoreApplication, QMetaObject, QUrl, Q_ARG, Q_RETURN_ARG
    from PySide6.QtQml import QQmlComponent, QQmlEngine
except ImportError:
    print("::error::PySide6 is missing: pip install pyside6-essentials==6.12.0 (see the header of ci/test-parser.py)")
    sys.exit(1)

PKG = Path(__file__).resolve().parent.parent
PARSER = PKG / "contents" / "ui" / "feedparser.js"

# --- Load feedparser.js through a QML import ---------------------------------
app = QCoreApplication([])
engine = QQmlEngine()
component = QQmlComponent(engine)
HARNESS = """
import QtQml
import "%s" as FeedParser
QtObject {
    // Arguments and result travel as JSON; a Date argument is written as
    // {"$date": <ms since epoch>} or {"$date": "invalid"}.
    function call(name, argsJson) {
        var args = JSON.parse(argsJson).map(function (value) {
            if (value && typeof value === "object" && value.$date !== undefined)
                return value.$date === "invalid" ? new Date(NaN) : new Date(value.$date);
            return value;
        });
        try {
            return JSON.stringify({ "ok": FeedParser[name].apply(null, args) });
        } catch (e) {
            return JSON.stringify({ "error": String(e) });
        }
    }
}
""" % QUrl.fromLocalFile(str(PARSER)).toString()
component.setData(HARNESS.encode("utf-8"), QUrl.fromLocalFile(str(PKG / "ci" / "test-parser-harness.qml")))
harness = component.create()
if harness is None:
    print("::error file=contents/ui/feedparser.js::does not load in QML: " + component.errorString())
    sys.exit(1)


def call(name, *args):
    raw = QMetaObject.invokeMethod(harness, "call", Q_RETURN_ARG("QVariant"),
                                   Q_ARG("QVariant", name), Q_ARG("QVariant", json.dumps(list(args))))
    result = json.loads(raw)
    if "error" in result:
        raise RuntimeError(result["error"])
    # JSON.stringify drops undefined; keep that visible as None.
    return result.get("ok")


def date(ms):
    return {"$date": ms}


# --- Synthetic feeds ---------------------------------------------------------
RSS2 = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
<title>Example News</title><link>https://example.org/</link>
<item><title>First story</title><link>https://example.org/1</link>
<pubDate>Tue, 17 Nov 2026 10:00:00 GMT</pubDate></item>
<item><title>Second story</title><link> https://example.org/2 </link>
<pubDate>Tue, 17 Nov 2026 12:30:00 +0100</pubDate></item>
</channel></rss>"""

ATOM = """<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<title type="text">Example Atom</title>
<entry><title>Alternate after self</title>
<link rel="self" href="https://example.org/self/1"/>
<link rel="alternate" type="text/html" href="https://example.org/a/1"/>
<updated>2026-11-17T08:15:00Z</updated></entry>
<entry><title>Href before rel</title>
<link href="https://example.org/a/2" rel="alternate"/>
<published>2026-11-16T08:15:00+02:00</published></entry>
<entry><title>Only href</title><link href='https://example.org/a/3'/></entry>
</feed>"""

RSS1 = """<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://purl.org/rss/1.0/" xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel rdf:about="https://example.org/"><title>Example RDF</title></channel>
<item rdf:about="https://example.org/r/1"><title>RDF item</title><link>https://example.org/r/1</link>
<dc:date>2026-11-17T09:00:00Z</dc:date></item>
</rdf:RDF>"""


def one(xml_item, feed_title="F"):
    """A minimal RSS 2.0 document around one <item> body."""
    return "<rss><channel><title>%s</title><item>%s</item></channel></rss>" % (feed_title, xml_item)


def art(title, source, ts, link=""):
    return {"title": title, "source": source, "date": "", "timestamp": ts, "link": link}


# --- Cases: (name, function, args, expected, known issue or None) -------------
# `expected` is a value to compare, or a function that checks the result.
CASES = []


def case(name, fn, args, expected, known=None):
    CASES.append((name, fn, args, expected, known))


def field(key, value, index=0):
    return lambda r: r[index][key] == value


# Settings: parseSources keeps reading what older versions stored.
case("sources: plain array", "parseSources", ['["https://example.org/feed"]', 7], ["https://example.org/feed"])
case("sources: v1 object", "parseSources", ['{"v":1,"sources":["https://example.org/a"]}', 7], ["https://example.org/a"])
case("sources: v2 object, this instance", "parseSources",
     ['{"v":2,"instances":{"7":{"sources":["https://example.org/7"]},"8":{"sources":["https://example.org/8"]}}}', 7],
     ["https://example.org/7"])
case("sources: v2 object, other instance only", "parseSources", ['{"v":2,"instances":{"8":{"sources":["x"]}}}', 7], [])
case("sources: unknown object", "parseSources", ['{"foo":1}', 7], [])
case("sources: JSON null", "parseSources", ["null", 7], [])
case("sources: invalid JSON", "parseSources", ["[not json", 7], None)
case("excludes: list", "parseExcludes", ['["ad", "sponsored"]'], ["ad", "sponsored"])
case("excludes: empty text", "parseExcludes", [""], [])
case("excludes: invalid JSON", "parseExcludes", ["{oops"], [])
case("excludes: not a list", "parseExcludes", ['{"a":1}'], [])

# RSS 2.0
case("rss2: two items", "parseFeed", [RSS2, "https://example.org/rss", "No Title"], [
    {"title": "First story", "source": "Example News", "date": "17.11.26 10:00",
     "timestamp": 1794909600000, "link": "https://example.org/1"},
    {"title": "Second story", "source": "Example News", "date": "17.11.26 11:30",
     "timestamp": 1794915000000, "link": "https://example.org/2"},
])
# Atom
case("atom: rel=alternate wins over self", "parseFeed", [ATOM, "u", "No Title"], field("link", "https://example.org/a/1"))
case("atom: feed title is the source", "parseFeed", [ATOM, "u", "No Title"], field("source", "Example Atom"))
case("atom: <updated> date", "parseFeed", [ATOM, "u", "No Title"], field("timestamp", 1794903300000))
case("atom: href before rel", "parseFeed", [ATOM, "u", "No Title"], field("link", "https://example.org/a/2", 1))
case("atom: <published> with offset", "parseFeed", [ATOM, "u", "No Title"], field("timestamp", 1794809700000, 1))
case("atom: only href", "parseFeed", [ATOM, "u", "No Title"], field("link", "https://example.org/a/3", 2))
case("atom: no date sorts as 0", "parseFeed", [ATOM, "u", "No Title"], lambda r: r[2]["timestamp"] == 0 and r[2]["date"] == "")
# RSS 1.0
case("rss1: item with attributes is read", "parseFeed", [RSS1, "u", "No Title"],
     lambda r: len(r) == 1 and r[0]["title"] == "RDF item" and r[0]["link"] == "https://example.org/r/1")
case("rss1: dc:date is read", "parseFeed", [RSS1, "u", "No Title"], field("timestamp", 1794906000000))
case("rss1: dc:date is formatted", "parseFeed", [RSS1, "u", "No Title"], field("date", "17.11.26 09:00"))
# Text content
case("title: CDATA", "parseFeed", [one("<title><![CDATA[Fish & Chips]]></title>"), "u", "NT"], field("title", "Fish & Chips"))
case("title: named and numeric entities", "parseFeed",
     [one("<title>A &amp; B &#8211; C &#x2014; &quot;D&quot; &hellip;</title>"), "u", "NT"],
     field("title", "A & B – C — \"D\" …"))
case("title: markup is stripped to text", "parseFeed", [one("<title><b>Bold</b> <script>x</script>news</title>"), "u", "NT"],
     field("title", "Bold xnews"))
case("title: missing uses the given text", "parseFeed", [one("<link>https://example.org/x</link>"), "u", "No Title"], field("title", "No Title"))
case("title: emoji as numeric entity", "parseFeed", [one("<title>Hi &#128512;</title>"), "u", "NT"], field("title", "Hi \U0001F600"))
case("source: feed title with entity", "parseFeed", [one("<title>x</title>", "Tom &amp; Jerry"), "u", "NT"], field("source", "Tom & Jerry"))
case("source: no title falls back to the URL", "parseFeed", ["<rss><item><link>https://example.org/1</link></item></rss>", "https://example.org/rss", "NT"],
     field("source", "https://example.org/rss"))
case("link: entity in Atom href is decoded", "parseFeed",
     [one('<title>x</title><link rel="alternate" href="https://example.org/?a=1&amp;b=2"/>'), "u", "NT"],
     field("link", "https://example.org/?a=1&b=2"))
case("title: emoji as hex entity", "parseFeed", [one("<title>Party &#x1F600;</title>"), "u", "NT"], field("title", "Party \U0001F600"))
case("title: invalid numeric entity stays as written", "parseFeed", [one("<title>a &#0; b &#x110000; c &#xD800;</title>"), "u", "NT"],
     field("title", "a &#0; b &#x110000; c &#xD800;"))
case("title: unknown named entity stays as written", "parseFeed", [one("<title>x &bogus; y</title>"), "u", "NT"], field("title", "x &bogus; y"))
case("title: entities are decoded only once", "parseFeed", [one("<title>use &amp;#60;b&amp;#62; &amp;amp;</title>"), "u", "NT"],
     field("title", "use &#60;b&#62; &amp;"))
case("title: < and > inside CDATA are text", "parseFeed", [one("<title><![CDATA[Why 3 < 5 and 7 > 2 matters]]></title>"), "u", "NT"],
     field("title", "Why 3 < 5 and 7 > 2 matters"))
case("title: markup inside CDATA is stripped", "parseFeed", [one("<title><![CDATA[<b>Bold</b> news]]></title>"), "u", "NT"],
     field("title", "Bold news"))
case("title: text around CDATA is kept", "parseFeed", [one("<title>Re: <![CDATA[a < b]]> &amp; more</title>"), "u", "NT"],
     field("title", "Re: a < b & more"))
case("title: escaped markup is shown as text", "parseFeed", [one("<title>The &lt;b&gt; tag</title>"), "u", "NT"], field("title", "The <b> tag"))
case("title: line breaks and indentation collapse", "parseFeed", [one("<title>\n    Two\n    lines\t here\n</title>"), "u", "NT"],
     field("title", "Two lines here"))
case("source: image title before the channel title is skipped", "parseFeed",
     ["<rss><channel><image><title>Logo</title><url>https://example.org/l.png</url></image><title>Real Name</title>"
      "<item><title>x</title></item></channel></rss>", "u", "NT"], field("source", "Real Name"))
case("source: an item title is never the source", "parseFeed",
     ["<rss><channel><item><title>Item</title></item></channel></rss>", "https://example.org/rss", "NT"],
     field("source", "https://example.org/rss"))
case("rss1: <items> list is not an item", "parseFeed",
     ['<rdf:RDF><channel><title>R</title><items><rdf:Seq><rdf:li resource="https://example.org/r/1"/></rdf:Seq></items></channel>'
      '<item><title>One</title><link>https://example.org/r/1</link></item><item><title>Two</title><link>https://example.org/r/2</link></item></rdf:RDF>', "u", "NT"],
     lambda r: [a["title"] for a in r] == ["One", "Two"])
case("link: entities in Atom href, rel after href", "parseFeed",
     [one('<title>x</title><link href="https://wiki.example/index.php?title=X&amp;diff=2&amp;oldid=1" rel="alternate"/>'), "u", "NT"],
     field("link", "https://wiki.example/index.php?title=X&diff=2&oldid=1"))
case("link: entities in Atom href without rel", "parseFeed", [one("<title>x</title><link href='https://example.org/?a=1&amp;b=2'/>"), "u", "NT"],
     field("link", "https://example.org/?a=1&b=2"))
case("link: entity in RSS link is decoded", "parseFeed", [one("<title>x</title><link>https://example.org/?a=1&amp;b=2</link>"), "u", "NT"],
     field("link", "https://example.org/?a=1&b=2"))
case("link: permalink guid when there is no link", "parseFeed",
     [one('<title>x</title><guid isPermaLink="true">https://example.org/g/1</guid>'), "u", "NT"], field("link", "https://example.org/g/1"))
case("link: guid without isPermaLink counts as permalink", "parseFeed",
     [one("<title>x</title><guid>https://example.org/g/2</guid>"), "u", "NT"], field("link", "https://example.org/g/2"))
case("link: guid with isPermaLink=false is not a link", "parseFeed",
     [one('<title>x</title><guid isPermaLink="false">https://example.org/g/3</guid>'), "u", "NT"], field("link", ""))
case("link: guid that is no web address is not a link", "parseFeed",
     [one("<title>x</title><guid>tag:example.org,2026:1</guid>"), "u", "NT"], field("link", ""))
case("link: <link> wins over guid", "parseFeed",
     [one("<title>x</title><link>https://example.org/l</link><guid>https://example.org/g</guid>"), "u", "NT"], field("link", "https://example.org/l"))
# Dates
case("date: unreadable text is shown as is", "parseFeed", [one("<title>x</title><pubDate>sometime</pubDate>"), "u", "NT"],
     lambda r: r[0]["timestamp"] == 0 and r[0]["date"] == "sometime")
case("date: US zone name PDT", "parseFeed", [one("<title>x</title><pubDate>Tue, 17 Nov 2026 02:00:00 PDT</pubDate>"), "u", "NT"],
     field("timestamp", 1794906000000))
case("date: PDT is shown in local time", "parseFeed", [one("<title>x</title><pubDate>Tue, 17 Nov 2026 02:00:00 PDT</pubDate>"), "u", "NT"],
     field("date", "17.11.26 09:00"))


def stamp(text, ts, name=None):
    case(name or "date: %s" % text, "parseFeed", [one("<title>x</title><pubDate>%s</pubDate>" % text), "u", "NT"], field("timestamp", ts))


# 17 Nov 2026 10:00 UTC is 1794909600000.
stamp("Tue, 17 Nov 2026 10:00:00 UT", 1794909600000)
stamp("Tue, 17 Nov 2026 10:00:00 GMT", 1794909600000)
stamp("Tue, 17 Nov 2026 05:00:00 EST", 1794909600000)
stamp("Tue, 17 Nov 2026 11:00:00 CET", 1794909600000)
stamp("Tue, 17 Nov 2026 03:00:00 -0700 (PDT)", 1794909600000)
stamp("Tue, 17 Nov 2026 12:00:00 +02:00", 1794909600000)
stamp("Tue, 17 Nov 2026 10:00 GMT", 1794909600000)
stamp("Tue, 17 Nov 2026 10:00", 1794909600000, "date: no zone counts as UTC")
stamp("17 Nov 2026 10:00:00 +0000", 1794909600000, "date: no weekday")
stamp("Tue,  17  Nov  2026  10:00:00  GMT ", 1794909600000, "date: extra spaces")
stamp("Tue, 17 nov 26 10:00:00 gmt", 1794909600000, "date: two-digit year, lower case")
stamp("Tuesday, 17 November 2026 10:00:00 GMT", 1794909600000, "date: full day and month names")
stamp("Tue, 17 Nov 2026 10:00:00 XYZ", 1794909600000, "date: unknown zone name counts as UTC")
stamp("Tue, 3 Nov 2026 10:00:00 +0000", 1793700000000, "date: one-digit day")
stamp("2026-11-17T10:00:00Z", 1794909600000, "date: ISO 8601 in pubDate")
stamp("2026-11-17T12:00:00.500+02:00", 1794909600500, "date: ISO 8601 with fraction and offset")
case("date: day 32 is not a date", "parseFeed", [one("<title>x</title><pubDate>Tue, 32 Nov 2026 10:00:00 GMT</pubDate>"), "u", "NT"],
     lambda r: r[0]["timestamp"] == 0 and r[0]["date"] == "Tue, 32 Nov 2026 10:00:00 GMT")
case("date: unknown month is not a date", "parseFeed", [one("<title>x</title><pubDate>Tue, 17 Foo 2026 10:00:00 GMT</pubDate>"), "u", "NT"],
     field("timestamp", 0))
case("date: <pubDateX> is not a date", "parseFeed", [one("<title>x</title><pubDateX>Tue, 17 Nov 2026 10:00:00 GMT</pubDateX>"), "u", "NT"],
     field("timestamp", 0))
case("date: Atom <published> wins over an earlier <updated>", "parseFeed",
     ['<feed xmlns="http://www.w3.org/2005/Atom"><title>A</title><entry><title>x</title>'
      '<updated>2026-11-18T10:00:00Z</updated><published>2026-11-17T10:00:00Z</published></entry></feed>', "u", "NT"],
     field("timestamp", 1794909600000))
# Broken input never throws
case("empty document", "parseFeed", ["", "u", "NT"], [])
case("null document", "parseFeed", [None, "u", "NT"], [])
case("broken document (unclosed item)", "parseFeed", ["<rss><channel><title>T</title><item><title>x", "u", "NT"], [])
case("not a feed (HTML page)", "parseFeed", ["<html><head><title>Hi</title></head><body>no</body></html>", "u", "NT"], [])

# Building the list: blacklist, duplicates, order
A = [art("Old news", "Feed A", 100, "https://example.org/old"),
     art("New SPONSORED post", "Feed A", 300, "https://example.org/ad"),
     art("Middle", "Ads Weekly", 200, "https://example.org/mid"),
     art("Newest", "Feed B", 400, "https://example.org/new")]
case("merge: newest first", "mergeArticles", [A, []], lambda r: [a["timestamp"] for a in r] == [400, 300, 200, 100])
case("merge: blacklist on title, case-insensitive", "mergeArticles", [A, ["sponsored"]],
     lambda r: "New SPONSORED post" not in [a["title"] for a in r] and len(r) == 3)
case("merge: blacklist on source", "mergeArticles", [A, ["^ads "]], lambda r: "Ads Weekly" not in [a["source"] for a in r])
case("merge: invalid and empty patterns are ignored", "mergeArticles", [A, ["(unclosed", "  ", "newest"]],
     lambda r: [a["title"] for a in r] == ["New SPONSORED post", "Middle", "Old news"])
case("merge: same link shown once", "mergeArticles",
     [[art("One", "Feed A", 1, "https://example.org/same"), art("One again", "Feed B", 2, "https://example.org/same")], []],
     lambda r: len(r) == 1 and r[0]["title"] == "One")
case("merge: no link, same source and title shown once", "mergeArticles",
     [[art("T", "S", 1), art("T", "S", 2), art("T", "Other", 3)], []], lambda r: len(r) == 2)
case("merge: no blacklist value", "mergeArticles", [A, None], lambda r: len(r) == 4)
# Search box
case("search: empty shows all", "filterArticles", [A, "  "], lambda r: len(r) == 4)
case("search: regex on title, case-insensitive", "filterArticles", [A, "^new"], lambda r: [a["title"] for a in r] == ["New SPONSORED post", "Newest"])
case("search: matches the source too", "filterArticles", [A, "feed b"], lambda r: [a["title"] for a in r] == ["Newest"])
case("search: invalid regex shows none", "filterArticles", [A, "[oops"], [])
# Formatting
case("format: date and time", "formatDateTime", [date(1794909600000)], "17.11.26 10:00")
case("format: time", "formatTime", [date(1794915000000)], "11:30")
case("format: US date and time", "formatDateTime", [date(1794909600000), "en_US"], "11/17/26 10:00\u202fAM")
case("format: British date and time", "formatDateTime", [date(1794909600000), "en_GB"], "17/11/2026 10:00")
case("format: Japanese date and time", "formatDateTime", [date(1794909600000), "ja_JP"], "2026/11/17 10:00")
case("format: US time", "formatTime", [date(1794915000000), "en_US"], "11:30\u202fAM")
case("format: invalid date", "formatDateTime", [{"$date": "invalid"}], "")
case("format: no date", "formatTime", [None], "")


# --- Run ---------------------------------------------------------------------
failed = 0
known_open = 0
for name, fn, args, expected, known in CASES:
    try:
        result = call(fn, *args)
        passed = expected(result) if callable(expected) else result == expected
        detail = "" if passed else "got %s" % json.dumps(result, ensure_ascii=False)
    except Exception as exc:  # a check that cannot even index the result fails too
        passed, detail = False, "error: %s" % exc
    if known:
        if passed:
            failed += 1
            print("::error file=ci/test-parser.py::%s now passes: remove known=\"%s\" so it guards the fix" % (name, known))
        else:
            known_open += 1
            print("[known %s] %s (%s)" % (known, name, detail))
    elif passed:
        print("[ok] %s" % name)
    else:
        failed += 1
        print("::error file=contents/ui/feedparser.js::%s: %s" % (name, detail))

print("%d cases, %d failed, %d known issues still open" % (len(CASES), failed, known_open))
sys.exit(1 if failed else 0)
