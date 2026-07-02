// Surge cron script.
// Fetches a Surge rule list, builds a compact Bloom filter for DOMAIN-SUFFIX,
// and stores it in $persistentStore for CN-DNS-Split.js.

var STORE_META = "cn_dns_split_meta_v1";
var STORE_BITS = "cn_dns_split_bits_v1";
var STORE_EXACT = "cn_dns_split_exact_v1";
var DEFAULT_SOURCE = "https://raw.githubusercontent.com/Reukix/ukix/refs/heads/main/Rule/CN.list";
var DEFAULT_FPR = 0.000001;
var ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

function parseArgs(input) {
    var result = {};
    String(input || "").split("&").forEach(function (part) {
        if (!part) return;
        var index = part.indexOf("=");
        var key = index >= 0 ? part.slice(0, index) : part;
        var value = index >= 0 ? part.slice(index + 1) : "";
        if (!key) return;
        result[decodeURIComponent(key)] = decodeURIComponent(value);
    });
    return result;
}

function log() {
    if (ARGS.log === "1") console.log(Array.prototype.join.call(arguments, " "));
}

function cleanDomain(value) {
    return String(value || "").trim().replace(/\.$/, "").toLowerCase();
}

function isDomain(value) {
    return /^[a-z0-9-]+(\.[a-z0-9-]+)*$/.test(value);
}

function fnv1a(value, seed) {
    var hash = (0x811c9dc5 ^ seed) >>> 0;
    for (var i = 0; i < value.length; i++) {
        hash ^= value.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash >>> 0;
}

function hasParentSuffix(domain, suffixMap) {
    var labels = domain.split(".");
    for (var i = 1; i < labels.length; i++) {
        if (suffixMap[labels.slice(i).join(".")] === 1) return true;
    }
    return false;
}

function exactCoveredBySuffix(domain, suffixMap) {
    var labels = domain.split(".");
    for (var i = 0; i < labels.length; i++) {
        if (suffixMap[labels.slice(i).join(".")] === 1) return true;
    }
    return false;
}

function objectKeys(object) {
    var keys = [];
    for (var key in object) {
        if (Object.prototype.hasOwnProperty.call(object, key)) keys.push(key);
    }
    return keys;
}

function parseRuleList(text) {
    var exactMap = Object.create(null);
    var suffixMap = Object.create(null);
    var ignored = Object.create(null);
    var invalid = 0;
    var total = 0;
    var lines = String(text || "").split(/\r?\n/);

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line || line.charAt(0) === "#" || line.indexOf(",") < 0) continue;

        total++;
        var parts = line.split(",");
        var type = String(parts[0] || "").trim().toUpperCase();
        var value = cleanDomain(parts[1]);

        if (!value || !isDomain(value)) {
            invalid++;
            continue;
        }

        if (type === "DOMAIN") {
            exactMap[value] = 1;
        } else if (type === "DOMAIN-SUFFIX") {
            suffixMap[value] = 1;
        } else {
            ignored[type] = (ignored[type] || 0) + 1;
        }
    }

    var suffixes = objectKeys(suffixMap);
    var minimizedSuffixMap = Object.create(null);
    suffixes.sort(function (a, b) {
        return a.split(".").length - b.split(".").length || (a < b ? -1 : a > b ? 1 : 0);
    });

    for (var s = 0; s < suffixes.length; s++) {
        var suffix = suffixes[s];
        if (!hasParentSuffix(suffix, minimizedSuffixMap)) minimizedSuffixMap[suffix] = 1;
    }

    var minimizedExactMap = Object.create(null);
    var exacts = objectKeys(exactMap);
    for (var e = 0; e < exacts.length; e++) {
        var exact = exacts[e];
        if (!exactCoveredBySuffix(exact, minimizedSuffixMap)) minimizedExactMap[exact] = 1;
    }

    return {
        total: total,
        invalid: invalid,
        ignored: ignored,
        suffixes: objectKeys(minimizedSuffixMap).sort(),
        exacts: objectKeys(minimizedExactMap).sort()
    };
}

function buildBloom(values, falsePositiveRate) {
    var n = Math.max(1, values.length);
    var rate = Math.max(0.0000001, Math.min(0.01, falsePositiveRate || DEFAULT_FPR));
    var bitCount = Math.max(8, Math.ceil(-(n * Math.log(rate)) / (Math.LN2 * Math.LN2)));
    var hashCount = Math.max(1, Math.round((bitCount / n) * Math.LN2));
    var cells = new Uint8Array(Math.ceil(bitCount / 6));

    function setBit(index) {
        cells[(index / 6) | 0] |= 1 << (index % 6);
    }

    for (var i = 0; i < values.length; i++) {
        var value = values[i];
        var h1 = fnv1a(value, 0);
        var h2 = fnv1a(value, 0x9e3779b9) || 0x27d4eb2d;
        for (var j = 0; j < hashCount; j++) {
            setBit(((h1 + Math.imul(j, h2)) >>> 0) % bitCount);
        }
    }

    var chunks = [];
    var chunk = "";
    for (var c = 0; c < cells.length; c++) {
        chunk += ALPHABET.charAt(cells[c]);
        if (chunk.length >= 8192) {
            chunks.push(chunk);
            chunk = "";
        }
    }
    if (chunk) chunks.push(chunk);

    return {
        bits: chunks.join(""),
        bitCount: bitCount,
        hashCount: hashCount
    };
}

function finish(error, info) {
    if (error) {
        console.log("[CN-DNS-Update] " + error);
        if (ARGS.notify === "1") $notification.post("CN DNS Update", "Failed", String(error));
        $done();
        return;
    }

    var message = "suffix=" + info.suffixCount + ", exact=" + info.exactCount + ", size=" + info.bitsLength;
    console.log("[CN-DNS-Update] " + message);
    if (ARGS.notify === "1") $notification.post("CN DNS Update", "Success", message);
    $done();
}

var ARGS = parseArgs(typeof $argument === "undefined" ? "" : $argument);
var SOURCE = ARGS.source || DEFAULT_SOURCE;
var FPR = parseFloat(ARGS.fpr || DEFAULT_FPR);

$httpClient.get({ url: SOURCE, timeout: parseInt(ARGS.timeout || "30", 10) }, function (error, response, data) {
    try {
        if (error) throw new Error(error);
        if (!response || response.status < 200 || response.status >= 300) {
            throw new Error("HTTP status " + (response && response.status));
        }

        var parsed = parseRuleList(data);
        var bloom = buildBloom(parsed.suffixes, FPR);
        var now = new Date().toISOString();
        var meta = {
            version: 1,
            updatedAt: now,
            source: SOURCE,
            falsePositiveRate: FPR,
            totalRules: parsed.total,
            invalidRules: parsed.invalid,
            ignoredRules: parsed.ignored,
            suffixCount: parsed.suffixes.length,
            exactCount: parsed.exacts.length,
            bitCount: bloom.bitCount,
            hashCount: bloom.hashCount,
            bitsLength: bloom.bits.length
        };

        if (!$persistentStore.write(JSON.stringify(meta), STORE_META)) throw new Error("write meta failed");
        if (!$persistentStore.write(bloom.bits, STORE_BITS)) throw new Error("write bloom bits failed");
        if (!$persistentStore.write(JSON.stringify(parsed.exacts), STORE_EXACT)) throw new Error("write exact list failed");

        log(JSON.stringify(meta));
        finish(null, meta);
    } catch (err) {
        finish(err && err.message ? err.message : err);
    }
});
