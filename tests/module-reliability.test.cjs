const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");
const { createHash } = require("node:crypto");
const root = path.join(__dirname, "..");
const read = name => fs.readFileSync(path.join(root, name), "utf8");
function run(name, { url, body = "{}", status = 200, headers = {}, requestOnly = false, cache = new Map() }) {
  const results = [];
  const context = {
    $request: { url, headers, method: "GET" },
    $persistentStore: { read: key => cache.get(key) || null, write: (value, key) => { cache.set(key, value); return true; } },
    $done: result => results.push(result), console: { log() {} },
  };
  if (!requestOnly) context.$response = { status, body, headers: {} };
  vm.runInNewContext(read(name), context, { timeout: 1000 });
  assert.equal(results.length, 1, "script must finish exactly once");
  return results[0];
}
const unchanged = result => assert.equal(Object.keys(result).length, 0);
const regexp = pattern => new RegExp(pattern.replace(/^\(\?i\)/, ""), pattern.startsWith("(?i)") ? "i" : "");
function scriptPattern(file, needle) {
  const line = read(file).split("\n").find(line => line.includes(needle) && line.includes("pattern="));
  assert.ok(line, needle);
  return regexp(line.split("pattern=")[1].split(/,\s*script-path=/)[0]);
}
function runJq(file, needle, input) {
  const line = read(file).split("\n").find(line => line.startsWith("http-response-jq ") && line.includes(needle));
  assert.ok(line, needle);
  const result = spawnSync("jq", [line.split(" '")[1].slice(0, -1)], { input: JSON.stringify(input), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}

test("HTTPDNS leaves the reported Bilibili resolver and normal IP traffic alone", () => {
  const module = read("Script/HTTPDNS.sgmodule");
  const rules = module.split("\n").filter(line => line.startsWith('URL-REGEX,"')).map(line => regexp(line.match(/^URL-REGEX,"(.*)",REJECT$/)[1]));
  for (const url of [
    "http://117.144.238.29/resolve?host=xy61x170x60x32xy.mcdn.bilivideo.cn&query=4,6",
    "http://8.8.8.8/resolve?host=normal.example",
    "http://203.107.1.55/api/orders",
    "http://[240e:928:1400:10::25]/business",
    "http://xmc.ximalaya.com/xmlymain-login-web/login/normal",
  ]) assert.equal(rules.some(rule => rule.test(url)), false, url);
  for (const url of [
    "http://203.107.1.55/123/sign_d?host=example.com",
    "http://119.29.29.98/d?dn=example.com",
    "http://180.76.76.200/v1/resolv?host=example.com",
    "http://[240e:928:1400:10::25]:8080/httpdns/query?host=example.com",
  ]) assert.ok(rules.some(rule => rule.test(url)), url);
  assert.doesNotMatch(module, /^(?:IP-CIDR6?|DOMAIN-KEYWORD|USER-AGENT),/m);
  assert.doesNotMatch(module, /,DIRECT(?:,|$)/m);
  assert.doesNotMatch(module, /^DOMAIN,httpdns\.bilivideo\.com,REJECT/m);
});

test("KocoWidgets ignores other apps and missing app identity in both script phases", () => {
  const url = "https://api.revenuecat.com/v1/subscribers/fixture";
  for (const headers of [{}, { "X-Client-Bundle-ID": "com.example.OtherApp", "If-None-Match": "keep" }]) {
    const before = JSON.stringify(headers);
    unchanged(run("js/kocowidgets.js", { url, headers, requestOnly: true }));
    unchanged(run("js/kocowidgets.js", { url, headers, body: JSON.stringify({ subscriber: {} }) }));
    assert.equal(JSON.stringify(headers), before);
  }
});

test("KocoWidgets scopes cache-header changes and preserves unrelated subscriber data", () => {
  const url = "https://api.revenuecat.com:443/v1/subscribers/fixture?platform=ios";
  const headers = { "x-client-bundle-id": "com.niko.PocketWidgetsApp", "If-None-Match": "old", "X-RevenueCat-ETag": "old", Authorization: "fixture" };
  const request = run("js/kocowidgets.js", { url, headers: { ...headers }, requestOnly: true });
  assert.equal(request.headers["If-None-Match"], undefined);
  assert.equal(request.headers.Authorization, "fixture");
  const input = { subscriber: { original_app_user_id: "fixture-owner", management_url: "https://example.com/manage", subscriptions: { other: { keep: true } }, entitlements: { other: { keep: true } } } };
  const result = JSON.parse(run("js/kocowidgets.js", { url, headers, body: JSON.stringify(input) }).body);
  assert.equal(result.subscriber.original_app_user_id, input.subscriber.original_app_user_id);
  assert.deepEqual(result.subscriber.subscriptions, input.subscriber.subscriptions);
  assert.deepEqual(result.subscriber.entitlements.other, input.subscriber.entitlements.other);
  assert.equal(result.subscriber.management_url, input.subscriber.management_url);
  assert.ok(result.subscriber.entitlements.Subscription);
});

test("KocoWidgets malformed responses and subscriber subroutes pass through once", () => {
  const headers = { "X-Client-Bundle-ID": "com.niko.PocketWidgetsApp" };
  for (const body of ["", "not json", "null", "[]", "{}", '{"subscriber":[]}']) unchanged(run("js/kocowidgets.js", { url: "https://api.revenuecat.com/v1/subscribers/fixture", headers, body }));
  unchanged(run("js/kocowidgets.js", { url: "https://api.revenuecat.com/v1/subscribers/fixture/offerings", headers, body: '{"subscriber":{}}' }));
  unchanged(run("js/kocowidgets.js", { url: "https://api.revenuecat.com/v1/subscribers/fixture", headers, body: '{"subscriber":{}}', status: 500 }));
});

test("Taobao handles explicit ports and keeps primitive types in splash configuration", () => {
  const video = "https://guide-acs.m.taobao.com:443/gw/mtop.taobao.cloudvideo.video.query/1.0?fixture=1";
  const result = JSON.parse(run("js/adblock/taobao.js", { url: video, body: JSON.stringify({ data: { duration: 8, resources: ["ad"], caches: ["ad"], unrelated: true } }) }).body);
  assert.equal(result.data.duration, 0); assert.deepEqual(result.data.resources, []); assert.equal(result.data.unrelated, true);
  const splash = "https://guide-acs.m.taobao.com/gw/mtop.taobao.wireless.home.splash.awesome.get/1.0";
  const fixture = { data: { containers: { splash_home_base: { base: { sections: [null, {}, { bizData: { "taobao-splash": { data: [{ waitTime: "5", hotStart: true, coldStart: "true", imgUrl: "ad.jpg" }] } } }] } } } } };
  const ad = JSON.parse(run("js/adblock/taobao.js", { url: splash, body: JSON.stringify(fixture) }).body).data.containers.splash_home_base.base.sections[2].bizData["taobao-splash"].data[0];
  assert.equal(ad.waitTime, "0"); assert.equal(ad.hotStart, false); assert.equal(ad.coldStart, "false"); assert.equal(ad.imgUrl, "");
});

test("Taobao retains its video timestamp override and fills missing splash suppression fields", () => {
  const url = "https://guide-acs.m.taobao.com/gw/mtop.taobao.cloudvideo.video.query/1.0";
  for (const timestamp of ["1760000000000", 1760000000000]) {
    const result = JSON.parse(run("js/adblock/taobao.js", { url, body: JSON.stringify({ data: { duration: "8", respTimeInMs: timestamp, resources: ["ad"], normal: "keep" } }) }).body);
    assert.equal(result.data.respTimeInMs, typeof timestamp === "string" ? "3818332800000" : 3818332800000);
    assert.equal(result.data.normal, "keep");
  }
  const fixture = { data: { containers: { splash_home_base: { base: { sections: [{ bizData: { "taobao-splash": { data: [{ imgUrl: "ad.jpg" }] } } }] } } } } };
  const result = JSON.parse(run("js/adblock/taobao.js", { url: url.replace("cloudvideo.video.query", "wireless.home.splash.awesome.get"), body: JSON.stringify(fixture) }).body);
  const ad = result.data.containers.splash_home_base.base.sections[0].bizData["taobao-splash"].data[0];
  assert.equal(ad.hotStart, "false"); assert.equal(ad.coldStart, "false");
  assert.equal(ad.waitTime, "0"); assert.equal(ad.gmtStartMs, "3818332800000");
});

test("Taobao unknown paths, unchanged data and parse failures finish once without rewriting", () => {
  const url = "https://guide-acs.m.taobao.com/gw/mtop.taobao.cloudvideo.video.query/1.0";
  for (const body of ["", "<html>error</html>", "null", "[]", '{ "data": { "normal": 1 } }']) unchanged(run("js/adblock/taobao.js", { url, body }));
  unchanged(run("js/adblock/taobao.js", { url: url.replace(".query/", ".queryOther/"), body: '{"data":{"resources":["normal"]}}' }));
});

test("Xiaohongshu parser failures and unknown paths finish once", () => {
  const url = "https://edith.xiaohongshu.com/api/sns/v6/homefeed?fixture=1";
  for (const body of ["", "<html>error</html>", "null", "[]"]) unchanged(run("js/adblock/xiaohongshu.js", { url, body }));
  unchanged(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v99/unrelated", body: '{"normal":true}' }));
});

test("Xiaohongshu keeps comment identifiers and handles malformed nested cache/media JSON", () => {
  const url = "https://edith.xiaohongshu.com:443/api/sns/v5/note/comment/list";
  const input = { data: { comments: [{ red_id: "keep-id", note_id: "fixture", comment_type: 3, media_source_type: 1, pictures: [{ video_id: "broken", video_info: "not-json" }], sub_comments: [{ comment_type: 3, media_source_type: 1 }] }] } };
  const result = JSON.parse(run("js/adblock/xiaohongshu.js", { url, body: JSON.stringify(input), cache: new Map([["redBookCommentLivePhoto", "bad-json"]]) }).body);
  assert.equal(result.data.comments[0].red_id, "keep-id");
  assert.equal(result.data.comments[0].fmz200, undefined);
  assert.equal(result.data.comments[0].sub_comments[0].comment_type, 2);
  assert.equal(result.data.comments[0].sub_comments[0].media_source_type, 0);
  unchanged(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v1/note/live_photo/save", body: '{"data":{"datas":[]}}', cache: new Map([["redBookLivePhoto", "bad-json"]]) }));
});

test("Xiaohongshu can remove an all-ad video list", () => {
  const result = JSON.parse(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v4/note/videofeed", body: '{"data":[{"model_type":"note","ad":{"fixture":true}}]}' }).body);
  assert.deepEqual(result.data, []);
});

test("Xiaohongshu keeps normal notes with empty ad metadata and ordinary note attributes", () => {
  const fixture = { data: [
    { id: "normal", model_type: "note", ads_info: null, card_icon: {}, note_attributes: ["normal"] },
    { id: "ad", model_type: "note", ads_info: { id: "fixture-ad" } },
    { id: "goods", model_type: "note", note_attributes: ["goods"] },
  ] };
  const result = JSON.parse(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v6/homefeed", body: JSON.stringify(fixture) }).body);
  assert.deepEqual(result.data, [fixture.data[0]]);
});

test("pickup page keeps current bundles and business data across build hashes", () => {
  const url = "https://m.pinduoduo.net:443/mdkd/package?foo=1&from_app_scan=1&bar=2";
  const state = { props: { pageProps: { serverData: [{ key: "queryStationPackageInfo", value: "parcel" }, { key: "queryContactAddress", value: "keep" }, { key: "unknownFutureFeature", value: "keep" }, { key: "queryStationAd", value: "remove" }, { key: "queryGoodsRecommend", value: "remove" }] } } };
  const bundle = "https://pfile.pddpic.com/mdkd/mdkd/_next/static/chunks/1111-future-build.js";
  const body = '<html><head><script nonce="fixtureNonce" src="' + bundle + '"></script></head><body><div id="business">parcel</div><div class="index_gif-container__NEW"><div>ad</div></div><div class="index_goods-list-big-container__NEW">goods</div><script>const sample=\'<div class="index_gif-container__text">keep script</div>\';</script><script type="application/json" id=\'__NEXT_DATA__\'>' + JSON.stringify(state) + '</script></body></html>';
  const result = run("js/adblock/pinduoduo.js", { url, body });
  assert.ok(result.body.includes(bundle));
  assert.ok(result.body.includes('<div id="business">parcel</div>'));
  assert.ok(result.body.includes("keep script"));
  assert.ok(!result.body.includes('<div class="index_gif-container__NEW">'));
  assert.match(result.body, /<style id="ukix-pickup-adblock" nonce="fixtureNonce">/);
  const parsed = JSON.parse(result.body.match(/id='__NEXT_DATA__'>(.*?)<\/script>/s)[1]);
  assert.deepEqual(parsed.props.pageProps.serverData.map(item => item.key), ["queryStationPackageInfo", "queryContactAddress", "unknownFutureFeature"]);
  unchanged(run("js/adblock/pinduoduo.js", { url, body: result.body }));
  unchanged(run("js/adblock/pinduoduo.js", { url: url.replace("from_app_scan", "not_from_app_scan"), body }));
});

test("pickup page suppresses promotions loaded after an initially ad-free HTML shell", () => {
  const url = "https://m.pinduoduo.net/mdkd/package?from_app_scan=1";
  const body = '<html><head><script nonce="fixtureNonce" src="/current-bundle.js"></script></head><body><div id="business">parcel</div></body></html>';
  const result = run("js/adblock/pinduoduo.js", { url, body });
  assert.match(result.body, /<style id="ukix-pickup-adblock" nonce="fixtureNonce">/);
  assert.ok(result.body.includes('index_goods-list-big-container__'));
  assert.ok(result.body.includes('/current-bundle.js'));
  assert.ok(result.body.includes('<div id="business">parcel</div>'));
  unchanged(run("js/adblock/pinduoduo.js", { url, body: result.body }));
  unchanged(run("js/adblock/pinduoduo.js", { url, body: '{"message":"keep"}' }));
});

test("Xiaohongshu search banners clear array responses and splash filtering tolerates null entries", () => {
  assert.deepEqual(runJq("Script/Xiaohongshu.sgmodule", "banner_list", { data: ["ad"], success: true }), { data: {}, success: true });
  const input = { data: { ads_groups: [null, { start_time: 1760000000, end_time: 1760000010, ads: [null, { start_time: 1760000000, end_time: 1760000010 }] }] } };
  const result = JSON.parse(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v2/system_service/splash_config", body: JSON.stringify(input) }).body);
  assert.equal(result.data.ads_groups[0], null);
  assert.equal(result.data.ads_groups[1].start_time, 3818332800);
  assert.equal(result.data.ads_groups[1].ads[1].start_time, 3818332800);
});

test("FleaMarket filters feed ads when top configuration is absent or an unrelated item is malformed", () => {
  const item = (id, cardType) => ({ id, template: { name: "idlefish_home_new_commodity_card" }, data: { clickParam: { args: { cardType } } } });
  const input = { data: { sections: ["unknown", item("keep", "normal"), item("ad", "mamaAD")], normal: "keep" } };
  const result = runJq("Script/FleaMarket.sgmodule", "nextfresh", input);
  assert.deepEqual(result.data.sections, input.data.sections.slice(0, 2));
  assert.equal(result.data.normal, "keep");
  assert.equal(Object.hasOwn(result.data, "homeTopList"), false);
  const circle = { data: { circleList: [{ showInfo: { titleImage: "ad.jpg", text: "keep" } }] } };
  assert.deepEqual(runJq("Script/FleaMarket.sgmodule", "circle", circle), { data: { circleList: [{ showInfo: { text: "keep" } }] } });
  const personal = { data: { container: { sections: [{ template: { name: "my_fy1_header" }, item: {} }, { template: { name: "my_fy1_banner" } }, { template: { name: "my_fy1_tools" }, sectionBizCode: "entry2025", item: { tool: { exContent: { tools: null } } } }] }, ability: "ad" } };
  const cleaned = runJq("Script/FleaMarket.sgmodule", "adapter", personal);
  assert.deepEqual(cleaned.data.container.sections, [personal.data.container.sections[0], personal.data.container.sections[2]]);
  assert.equal(cleaned.data.ability, undefined);
});

test("Pinduoduo cleans independent sections despite missing or malformed neighboring data", () => {
  const input = { orders: [{ id: "first" }, { id: "second", order_buttons: [{ text: "查看物流", order_growth_tip: "ad" }] }] };
  assert.deepEqual(runJq("Script/Pinduoduo.sgmodule", "order_list_v4", input), { orders: [{ id: "first" }, { id: "second", order_buttons: [{ text: "查看物流" }] }] });
  const home = { result: { bottom_tabs: ["unknown", { link: "index.html" }, { link: "promotion.html" }], buffer_bottom_tabs: [{ link: "chat_list.html" }, { link: "promotion.html" }], all_top_opts: [{ name: "keep", image: "ad.jpg" }] } };
  assert.deepEqual(runJq("Script/Pinduoduo.sgmodule", "homepage", home), { result: { bottom_tabs: ["unknown", { link: "index.html" }], buffer_bottom_tabs: [{ link: "chat_list.html" }], all_top_opts: [{ name: "keep" }] } });
});

test("Xiaohongshu video ads are removed despite an unrelated malformed share configuration", () => {
  const input = { data: [{ id: "keep", model_type: "note", share_info: { function_entries: "unknown" } }, { id: "ad", model_type: "note", ad: { id: "fixture" } }] };
  const result = JSON.parse(run("js/adblock/xiaohongshu.js", { url: "https://edith.xiaohongshu.com/api/sns/v4/note/videofeed", body: JSON.stringify(input) }).body);
  assert.deepEqual(result.data, [input.data[0]]);
});

test("updated module patterns accept query order and explicit HTTPS ports without prefix collisions", () => {
  const pdd = scriptPattern("Script/Pinduoduo.sgmodule", "type=http-response");
  for (const query of ["from_app_scan=1", "foo=1&from_app_scan=1&bar=2", "from_app_scan"]) assert.ok(pdd.test("https://m.pinduoduo.net:443/mdkd/package?" + query));
  assert.equal(pdd.test("https://m.pinduoduo.net/mdkd/package?not_from_app_scan=1"), false);
  const tao = scriptPattern("Script/Taobao.sgmodule", "移除淘宝开屏广告 =");
  assert.ok(tao.test("https://guide-acs.m.taobao.com:443/gw/mtop.taobao.cloudvideo.video.query/1.0?x=1"));
  assert.equal(tao.test("https://guide-acs.m.taobao.com/gw/mtop.taobao.cloudvideo.video.queryOther/1.0"), false);
  const xhs = scriptPattern("Script/Xiaohongshu.sgmodule", "移除整体配置 ui");
  for (const suffix of ["", "?fixture=1"]) assert.ok(xhs.test("https://edith.xiaohongshu.com:443/api/sns/v1/system/service/ui/config" + suffix));
});

test("Meituan preserves legacy splash URL coverage and mock response behavior", () => {
  const rules = read("Script/meituan.sgmodule").split("\n").filter(line => line.includes(" data-type="));
  const expected = 'data-type=text data="{}" status-code=200 header="Content-Type:application/json"';
  const urls = [
    "http://wmapi.meituan.com/api/v7/loadInfo",
    "http://wmapi.meituan.com/api/v7/openscreen",
    "http://wmapi.meituan.com/api/v7/startpicture",
    "http://wmapi.meituan.com/api/v7/startpicture.json",
    "https://flowplus.meituan.net/v1/mss_fixture/linglong/123.jpg",
    "https://img.meituan.net/bizad/bizad_brandCpt_123.jpg",
    "https://s3plus.meituan.net/ocean-blk-index/index/blk_conf_123.json",
    "https://s3plus.meituan.net/v1/mss_fixture/brandcpt-vedio/fixture.zip",
    "https://s3plus.meituan.net/v1/mss_fixture/waimai-alita/fixture.zip",
  ];
  for (const original of urls) {
    const explicitPort = original.replace(/(\.com|\.net)(?=\/)/, original.startsWith("https:") ? "$1:443" : "$1:80");
    for (const url of [original, original + "?fixture=1", explicitPort, explicitPort + "?fixture=1"]) {
      const matches = rules.filter(line => regexp(line.split(" data-type=")[0]).test(url));
      assert.equal(matches.length, 1, url);
      assert.equal(matches[0].slice(matches[0].indexOf(" data-type=") + 1), expected, url);
    }
  }
  for (const url of ["https://s3plus.meituan.net/v1/mss_fixture/orders/fixture.zip", "https://img.meituan.net/order/123.jpg"]) {
    assert.equal(rules.some(line => regexp(line.split(" data-type=")[0]).test(url)), false, url);
  }
});

test("Taobao retains the legacy splash image mock and scripts have bounded response sizes", () => {
  for (const [name, url] of [
    ["Taobao", "https://gw.alicdn.com:443/imgextra/i1/123/abc-1-tps-1080-1920.jpg_1000x1000q90"],
  ]) {
    const matches = read("Script/" + name + ".sgmodule").split("\n").filter(line => line.includes(" data-type=") && regexp(line.split(" data-type=")[0]).test(url));
    assert.equal(matches.length, 1, url);
    assert.ok(matches[0].includes('data-type=text data="{}" status-code=200 header="Content-Type:application/json"'));
  }
  for (const file of fs.readdirSync(path.join(root, "Script"))) {
    for (const line of read("Script/" + file).split("\n")) if (line.includes("type=http-response")) {
      const limit = Number(line.match(/max-size=(\d+)/)?.[1]);
      assert.ok(limit > 0 && limit <= (file === "YouTubeMusic.sgmodule" ? 4194304 : 2097152), file);
    }
  }
});

test("combined jq rules keep schema mismatches intact and still remove the expected promotion fields", () => {
  assert.equal(spawnSync("jq", ["--version"]).status, 0, "jq is required for module verification");
  for (const name of ["Pinduoduo", "FleaMarket", "Xiaohongshu"]) {
    for (const line of read("Script/" + name + ".sgmodule").split("\n").filter(line => line.startsWith("http-response-jq "))) {
      const expr = line.split(" '")[1].slice(0, -1);
      for (const fixture of [{ code: 500, message: "keep" }, { data: null }, { result: null }]) {
        const result = spawnSync("jq", [expr], { input: JSON.stringify(fixture), encoding: "utf8" });
        assert.equal(result.status, 0, result.stderr);
        if (result.stdout.trim()) assert.deepEqual(JSON.parse(result.stdout), fixture);
      }
    }
  }
  const line = read("Script/Pinduoduo.sgmodule").split("\n").find(line => line.startsWith("http-response-jq ") && line.includes("homepage"));
  const fixture = { result: { dy_module: { irregular_banner_dy: ["ad"], parcel: "keep" }, icon_set: ["ad"], search_bar_hot_query: ["ad"], normal: true } };
  const result = spawnSync("jq", [line.split(" '")[1].slice(0, -1)], { input: JSON.stringify(fixture), encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { result: { dy_module: { parcel: "keep" }, normal: true } });
});

test("JD script alone replaces its former duplicate jq monitor changes", () => {
  const fixture = { data: { JDMessage: { socketmonitor: { isSocketEstablishedAhead: 1, isSocketReport: 1, keep: true } }, JDHttpToolKit: { httpdns: { httpdns: 1, keep: true } }, normal: "keep" } };
  const result = JSON.parse(run("js/adblock/jd.js", { url: "https://api.m.jd.com/client.action?functionId=basicConfig", body: JSON.stringify(fixture) }).body);
  assert.equal(result.data.JDMessage.socketmonitor.isSocketEstablishedAhead, 0);
  assert.equal(result.data.JDMessage.socketmonitor.isSocketReport, 0);
  assert.equal(result.data.JDHttpToolKit.httpdns.httpdns, 0);
  assert.equal(result.data.JDMessage.socketmonitor.keep, true);
  assert.equal(result.data.normal, "keep");
  assert.doesNotMatch(read("Script/JD.sgmodule"), /http-response-jq/);
});

test("published script URLs match local contents and no module references a missing local script", () => {
  for (const file of fs.readdirSync(path.join(root, "Script"))) {
    const text = read("Script/" + file);
    for (const match of text.matchAll(/script-path=https:\/\/raw\.githubusercontent\.com\/Reukix\/ukix\/refs\/heads\/main\/([^?,\s]+)(?:\?v=([a-f0-9]{12}))?/g)) {
      assert.ok(fs.existsSync(path.join(root, match[1])), match[1]);
      if (match[2]) assert.equal(match[2], createHash("sha256").update(fs.readFileSync(path.join(root, match[1]))).digest("hex").slice(0, 12));
    }
  }
  assert.equal(fs.existsSync(path.join(root, "js/adblock/pinduoduo-web-chunk.js")), false);
});
