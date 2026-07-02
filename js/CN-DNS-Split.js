// Surge DNS script.
// CN domains and non-CN domains are resolved with A-only DoH.
// Returning addresses + ttl lets Surge cache results and reduces repeated script executions.

var STORE_META = "cn_dns_split_meta_v1";
var STORE_BITS = "cn_dns_split_bits_v1";
var STORE_EXACT = "cn_dns_split_exact_v1";
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

function normalizeDomain(domain) {
    return String(domain || "").trim().replace(/\.$/, "").toLowerCase();
}

function objectFromArray(values) {
    var map = Object.create(null);
    for (var i = 0; i < values.length; i++) map[values[i]] = 1;
    return map;
}

function fnv1a(value, seed) {
    var hash = (0x811c9dc5 ^ seed) >>> 0;
    for (var i = 0; i < value.length; i++) {
        hash ^= value.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash >>> 0;
}

function sixBitValue(code) {
    if (code >= 65 && code <= 90) return code - 65;
    if (code >= 97 && code <= 122) return code - 71;
    if (code >= 48 && code <= 57) return code + 4;
    if (code === 45) return 62;
    if (code === 95) return 63;
    return 0;
}

function bitAt(bits, index) {
    var value = sixBitValue(bits.charCodeAt((index / 6) | 0));
    return (value & (1 << (index % 6))) !== 0;
}

function bloomHas(value, bits, meta) {
    var h1 = fnv1a(value, 0);
    var h2 = fnv1a(value, 0x9e3779b9) || 0x27d4eb2d;
    for (var i = 0; i < meta.hashCount; i++) {
        var index = (h1 + Math.imul(i, h2)) >>> 0;
        if (!bitAt(bits, index % meta.bitCount)) return false;
    }
    return true;
}

function loadCnData() {
    try {
        var metaText = $persistentStore.read(STORE_META);
        var bits = $persistentStore.read(STORE_BITS);
        var exactText = $persistentStore.read(STORE_EXACT);
        if (!metaText || !bits) return null;
        var meta = JSON.parse(metaText);
        var exact = exactText ? objectFromArray(JSON.parse(exactText)) : Object.create(null);
        if (!meta.bitCount || !meta.hashCount) return null;
        return { meta: meta, bits: bits, exact: exact };
    } catch (err) {
        log("load CN data failed:", err);
        return null;
    }
}

function isCnDomain(domain, data) {
    domain = normalizeDomain(domain);
    if (!domain) return false;
    if (data && data.exact[domain] === 1) return true;

    var labels = domain.split(".");
    if (!data) {
        return labels.length > 1 && labels[labels.length - 1] === "cn";
    }

    for (var i = 0; i < labels.length; i++) {
        var suffix = labels.slice(i).join(".");
        if (bloomHas(suffix, data.bits, data.meta)) return true;
    }
    return false;
}

function write16(buffer, offset, value) {
    buffer[offset] = (value >> 8) & 255;
    buffer[offset + 1] = value & 255;
}

function encodeDnsQuery(domain) {
    var labels = normalizeDomain(domain).split(".");
    var length = 12 + 1 + 4;
    for (var i = 0; i < labels.length; i++) length += 1 + labels[i].length;

    var id = Math.floor(Math.random() * 65536);
    var buffer = new Uint8Array(length);
    write16(buffer, 0, id);
    write16(buffer, 2, 0x0100);
    write16(buffer, 4, 1);
    write16(buffer, 6, 0);
    write16(buffer, 8, 0);
    write16(buffer, 10, 0);

    var offset = 12;
    for (var j = 0; j < labels.length; j++) {
        var label = labels[j];
        buffer[offset++] = label.length;
        for (var k = 0; k < label.length; k++) buffer[offset++] = label.charCodeAt(k) & 255;
    }
    buffer[offset++] = 0;
    write16(buffer, offset, 1);
    offset += 2;
    write16(buffer, offset, 1);
    return buffer;
}

function base64Url(bytes) {
    var output = "";
    var table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    for (var i = 0; i < bytes.length; i += 3) {
        var a = bytes[i];
        var b = i + 1 < bytes.length ? bytes[i + 1] : 0;
        var c = i + 2 < bytes.length ? bytes[i + 2] : 0;
        var triple = (a << 16) | (b << 8) | c;
        output += table[(triple >> 18) & 63];
        output += table[(triple >> 12) & 63];
        output += i + 1 < bytes.length ? table[(triple >> 6) & 63] : "=";
        output += i + 2 < bytes.length ? table[triple & 63] : "=";
    }
    return output.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function toBytes(body) {
    if (!body) return new Uint8Array(0);
    if (body instanceof Uint8Array) return body;
    if (typeof ArrayBuffer !== "undefined" && body instanceof ArrayBuffer) return new Uint8Array(body);
    if (body.buffer && body.byteLength !== undefined) return new Uint8Array(body.buffer, body.byteOffset || 0, body.byteLength);
    var bytes = new Uint8Array(String(body).length);
    for (var i = 0; i < bytes.length; i++) bytes[i] = String(body).charCodeAt(i) & 255;
    return bytes;
}

function read16(bytes, offset) {
    return ((bytes[offset] << 8) | bytes[offset + 1]) >>> 0;
}

function read32(bytes, offset) {
    return ((bytes[offset] * 16777216) + ((bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3])) >>> 0;
}

function skipName(bytes, offset) {
    var jumped = false;
    var start = offset;
    var guard = 0;
    while (offset < bytes.length && guard++ < 128) {
        var len = bytes[offset];
        if ((len & 0xc0) === 0xc0) {
            offset += 2;
            jumped = true;
            break;
        }
        if (len === 0) {
            offset += 1;
            break;
        }
        offset += len + 1;
    }
    return jumped ? offset : Math.max(offset, start);
}

function parseAResponse(body, defaultTtl) {
    var bytes = toBytes(body);
    if (bytes.length < 12) throw new Error("short DNS response");

    var flags = read16(bytes, 2);
    var rcode = flags & 15;
    if (rcode !== 0) throw new Error("DNS rcode " + rcode);

    var qd = read16(bytes, 4);
    var an = read16(bytes, 6);
    var offset = 12;
    for (var q = 0; q < qd; q++) {
        offset = skipName(bytes, offset) + 4;
    }

    var addresses = [];
    var ttl = defaultTtl;
    for (var i = 0; i < an && offset + 12 <= bytes.length; i++) {
        offset = skipName(bytes, offset);
        if (offset + 10 > bytes.length) break;
        var type = read16(bytes, offset);
        var klass = read16(bytes, offset + 2);
        var answerTtl = read32(bytes, offset + 4);
        var rdlen = read16(bytes, offset + 8);
        offset += 10;
        if (offset + rdlen > bytes.length) break;

        if (type === 1 && klass === 1 && rdlen === 4) {
            addresses.push(bytes[offset] + "." + bytes[offset + 1] + "." + bytes[offset + 2] + "." + bytes[offset + 3]);
            if (answerTtl > 0) ttl = Math.min(ttl, answerTtl);
        }
        offset += rdlen;
    }

    if (!addresses.length) throw new Error("empty A response");
    return { addresses: addresses, ttl: ttl };
}

function queryA(server, domain, timeout, ttl, callback) {
    var query = encodeDnsQuery(domain);
    var separator = server.indexOf("?") >= 0 ? "&" : "?";
    var request = {
        url: server + separator + "dns=" + base64Url(query),
        headers: { Accept: "application/dns-message" },
        timeout: timeout,
        "binary-mode": true,
        encoding: null
    };

    $httpClient.get(request, function (error, response, body) {
        try {
            if (error) throw new Error(error);
            if (!response || response.status < 200 || response.status >= 300) {
                throw new Error("HTTP status " + (response && response.status));
            }
            callback(null, parseAResponse(body, ttl));
        } catch (err) {
            callback(err && err.message ? err.message : err);
        }
    });
}

function queryAnyA(servers, domain, timeout, ttl, callback) {
    var pending = servers.length;
    var lastError = null;
    var finished = false;

    if (!pending) {
        callback("no DoH server");
        return;
    }

    for (var i = 0; i < servers.length; i++) {
        queryA(servers[i], domain, timeout, ttl, function (error, result) {
            if (finished) return;
            if (!error && result && result.addresses && result.addresses.length) {
                finished = true;
                callback(null, result);
                return;
            }
            lastError = error || lastError;
            pending--;
            if (pending === 0) callback(lastError || "all DoH queries failed");
        });
    }
}

var ARGS = parseArgs(typeof $argument === "undefined" ? "" : $argument);
var DOMAIN = normalizeDomain(typeof $domain === "undefined" ? "" : $domain);
var CN_DNS = ARGS.cnDns || "223.5.5.5";
var CN_DOH = String(ARGS.cnDoh || "https://dns.alidns.com/dns-query")
    .split(/\s*,\s*/)
    .filter(function (item) { return /^https?:\/\//.test(item); });
var TTL = parseInt(ARGS.ttl || "60", 10);
var TIMEOUT = parseInt(ARGS.timeout || "2", 10);
var DOH = String(ARGS.doh || "https://1.1.1.1/dns-query,https://8.8.8.8/dns-query")
    .split(/\s*,\s*/)
    .filter(function (item) { return /^https?:\/\//.test(item); });

try {
    var cnData = loadCnData();
    if (isCnDomain(DOMAIN, cnData)) {
        if (CN_DOH.length) {
            log("[CN A-only DoH]", DOMAIN);
            queryAnyA(CN_DOH, DOMAIN, TIMEOUT, TTL, function (error, result) {
                if (error) {
                    log("CN DoH failed:", error);
                    $done({ server: CN_DNS });
                } else {
                    $done(result);
                }
            });
        } else {
            log("[CN server]", DOMAIN, "->", CN_DNS);
            $done({ server: CN_DNS });
        }
    } else {
        log("[A-only DoH]", DOMAIN);
        queryAnyA(DOH, DOMAIN, TIMEOUT, TTL, function (error, result) {
            if (error) {
                log("DoH failed:", error);
                $done(ARGS.fallback === "0" ? { addresses: [] } : {});
            } else {
                $done(result);
            }
        });
    }
} catch (err) {
    log("fatal:", err);
    $done(ARGS.fallback === "0" ? { addresses: [] } : {});
}
