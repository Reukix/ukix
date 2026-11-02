/**
 * Telegram302 — Surge http-request script
 *
 * 配套模块：Telegram302.sgmodule
 * argument：tg / sg / turrit / ime / ng / lingo / rg
 * 格式依据：https://core.telegram.org/api/links
 *
 * 使用纯 JavaScript，不依赖 URL / URLSearchParams 等 Web API。
 * 未支持或无法解析的链接原样放行，不发送任何额外网络请求。
 */
(function () {
    "use strict";

    var apps = ["tg", "sg", "turrit", "ime", "ng", "lingo", "rg"];
    var argument = typeof $argument === "string" ? $argument : "";
    var app = argument.trim().toLowerCase().replace(/:(?:\/\/)?$/, "");
    if (apps.indexOf(app) === -1) app = "tg";

    // 特殊用途路径不能被当作普通用户名；未实现的类型交回原网页处理。
    var reserved = (
        "addemoji addlist addstickers addstyle addtheme auction auth boost call " +
        "confirmphone contact giftcode invoice joinchat login m nft oauth proxy " +
        "setlanguage share socks web a k z c s iv msg msg_url bg"
    ).split(" ");

    function isUsername(value) {
        return /^[A-Za-z0-9_]{1,32}$/.test(value) &&
            reserved.indexOf(value.toLowerCase()) === -1;
    }

    function isID(value) {
        // ID 保留为字符串，避免大整数精度损失。
        return /^[1-9][0-9]*$/.test(value);
    }

    function parseQuery(raw) {
        if (!raw) return [];
        return raw.split("&").filter(function (part) {
            return part !== "";
        }).map(function (part) {
            var index = part.indexOf("=");
            // URI 中的字面 + 保留为 +；Telegram 的 choose 参数用 + 分隔。
            // %20、%2B、Unicode 会在生成目标地址时统一编码，避免重复编码。
            return {
                name: decodeURIComponent(index < 0 ? part : part.slice(0, index)),
                value: index < 0 ? null : decodeURIComponent(part.slice(index + 1))
            };
        });
    }

    function parseURL(url) {
        if (typeof url !== "string" || /[\x00-\x20\x7f]/.test(url)) return null;
        var match = /^https?:\/\/([^/?#]+)(\/[^?#]*)?(?:\?([^#]*))?(?:#.*)?$/i.exec(url);
        if (!match || !/^(?:t\.me|telegram\.me|telegram\.dog)(?::(?:80|443))?$/i.test(match[1])) {
            return null;
        }
        var path = (match[2] || "/").replace(/\/$/, "");
        if (!path) return null;
        var segments = path.slice(1).split("/").map(function (part) {
            return decodeURIComponent(part);
        });
        if (segments.some(function (part) {
            return !part || /[/\\\x00-\x1f\x7f]/.test(part);
        })) return null;
        return { segments: segments, query: parseQuery(match[3] || "") };
    }

    function queryValue(query, name) {
        for (var i = 0; i < query.length; i++) {
            if (query[i].name === name) return query[i];
        }
        return null;
    }

    function makeTarget(action, fields, query, omitted) {
        var seen = Object.create(null);
        // 路径决定目标，查询参数不能替换目标用户名、手机号或消息 ID。
        ["domain", "phone", "channel", "post", "invite"].concat(omitted || []).forEach(function (name) {
            seen[name] = true;
        });
        var result = fields.map(function (field) {
            seen[field[0].toLowerCase()] = true;
            return encodeURIComponent(field[0]) + "=" + encodeURIComponent(field[1]);
        });
        query.forEach(function (parameter) {
            var key = parameter.name.toLowerCase();
            if (!key || seen[key]) return;
            seen[key] = true;
            result.push(encodeURIComponent(parameter.name) +
                (parameter.value === null ? "" : "=" + encodeURIComponent(parameter.value)));
        });
        return app + "://" + action + "?" + result.join("&");
    }

    function convert(url) {
        var parsed = parseURL(url);
        if (!parsed) return null;
        var parts = parsed.segments;
        var query = parsed.query;
        var first = parts[0].toLowerCase();
        var match;
        var fields;

        // 网页预览形式：/s/username 或 /s/username/message。
        if (first === "s") {
            parts = parts.slice(1);
            if (!parts.length || !isUsername(parts[0])) return null;
            first = parts[0].toLowerCase();
        }

        if (parts.length === 1 && (match = /^\+([0-9]+)$/.exec(parts[0]))) {
            return makeTarget("resolve", [["phone", match[1]]], query);
        }
        if (parts.length === 1 && (match = /^\+([A-Za-z0-9_-]+)$/.exec(parts[0]))) {
            return makeTarget("join", [["invite", match[1]]], query);
        }
        if (first === "joinchat" && parts.length === 2 && /^[A-Za-z0-9_-]+$/.test(parts[1])) {
            return makeTarget("join", [["invite", parts[1]]], query);
        }

        // 私有消息 /c/channel/post、私有话题 /c/channel/thread/post。
        if (first === "c") {
            if (!isID(parts[1])) return null;
            if (parts.length === 2 && queryValue(query, "boost")) {
                return makeTarget("boost", [["channel", parts[1]]], query, ["boost"]);
            }
            if (parts.length === 3 && isID(parts[2])) {
                return makeTarget("privatepost", [["channel", parts[1]], ["post", parts[2]]], query);
            }
            if (parts.length === 4 && isID(parts[2]) && isID(parts[3])) {
                return makeTarget("privatepost", [
                    ["channel", parts[1]], ["post", parts[3]], ["thread", parts[2]]
                ], query);
            }
            return null;
        }

        // 加成链接使用独立动作，不能把 ?boost 简单附加到 resolve。
        if (first === "boost") {
            if (parts.length === 2 && isUsername(parts[1])) {
                return makeTarget("boost", [["domain", parts[1]]], query, ["boost"]);
            }
            var channel = queryValue(query, "c");
            if (parts.length === 1 && channel && isID(channel.value)) {
                return makeTarget("boost", [["channel", channel.value]], query, ["c", "boost"]);
            }
            return null;
        }

        if (!isUsername(parts[0])) return null;
        fields = [["domain", parts[0]]];
        if (parts.length === 1) {
            return queryValue(query, "boost") ?
                makeTarget("boost", fields, query, ["boost"]) :
                makeTarget("resolve", fields, query);
        }
        if (parts.length === 2 && isID(parts[1])) {
            return makeTarget("resolve", fields.concat([["post", parts[1]]]), query);
        }
        if (parts.length === 3 && isID(parts[1]) && isID(parts[2])) {
            return makeTarget("resolve", fields.concat([
                ["post", parts[2]], ["thread", parts[1]]
            ]), query);
        }
        // 指定名称的 Mini App：/bot/appname?startapp=...。
        if (parts.length === 2 && /^[A-Za-z][A-Za-z0-9_]{0,63}$/.test(parts[1])) {
            return makeTarget("resolve", fields.concat([["appname", parts[1]]]), query);
        }
        return null;
    }

    var result = {};
    try {
        var request = typeof $request === "object" && $request ? $request : {};
        var method = (request.method || "GET").toUpperCase();
        var target = method === "GET" || method === "HEAD" ? convert(request.url) : null;
        if (target) {
            result = {
                response: {
                    status: 302,
                    headers: {
                        "Location": target,
                        "Cache-Control": "no-store",
                        "Pragma": "no-cache"
                    },
                    body: ""
                }
            };
        }
    } catch (error) {
        console.log("[Telegram302] 链接无法解析，已放行：" + error.message);
    }
    $done(result);
})();
