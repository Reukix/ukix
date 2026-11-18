const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const source = new vm.Script(fs.readFileSync(path.join(__dirname, "../js/YouTubeMusic.js"), "utf8"));
const agent = "com.google.ios.youtubemusic/9.46.3";
const api = "https://youtubei.googleapis.com/youtubei/v1/";
function uint(n) { const out = []; do { const b = n % 128; n = Math.floor(n / 128); out.push(b | (n ? 128 : 0)); } while (n); return Buffer.from(out); }
const scalar = (n, value) => Buffer.concat([uint(n * 8), uint(value)]);
function blob(n, value) { value = Buffer.from(value); return Buffer.concat([uint(n * 8 + 2), uint(value.length), value]); }
function run({ url = api + "player", body = Buffer.alloc(0), ua = agent, method = "POST", status = 200, request = false } = {}) {
  const calls = [];
  const context = { Uint8Array, ArrayBuffer, $request: { url, method, headers: { "User-Agent": ua } }, console: { log() {} }, $done: value => calls.push(value) };
  if (!request) context.$response = { status, body };
  source.runInNewContext(context, { timeout: 1000 });
  assert.equal(calls.length, 1);
  return calls[0];
}
const background = blob(11, blob(64657230, scalar(1, 1)));

test("player removes ad placements and enables background without rewriting other wire fields", () => {
  const unknown64 = Buffer.from([0xa0, 0x06, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]);
  const status = Buffer.concat([scalar(1, 0), blob(700, "keep status")]);
  const input = Buffer.concat([blob(2, status), blob(7, "pre-roll"), blob(68, "ad slot"), blob(11, "keep track"), unknown64]);
  const expected = Buffer.concat([blob(2, Buffer.concat([status, background])), blob(11, "keep track"), unknown64]);
  const result = run({ body: input });
  assert.deepEqual(Buffer.from(result.body), expected);
  assert.equal(Object.keys(run({ body: result.body })).length, 0);
});

test("Music advertiser overlay removal preserves normal next content", () => {
  const normal = blob(7, "queue metadata"), opaque = blob(777, "keep unknown");
  const ad = blob(14, blob(62960614, blob(1, "https://www.googleadservices.com/pagead/aclk?fixture=1")));
  assert.deepEqual(Buffer.from(run({ url: api + "next?alt=proto", body: Buffer.concat([normal, ad, opaque]) }).body), Buffer.concat([normal, opaque]));
  assert.equal(Object.keys(run({ url: api + "next", body: blob(14, "normal overlay") })).length, 0);
});

test("get_watch patches embedded players and preserves queue and unrelated content", () => {
  const normal = blob(13, "queue"), ad = blob(14, "https://www.googleadservices.com/pagead/aclk");
  const input = Buffer.concat([blob(1, Buffer.concat([blob(2, blob(2, scalar(1, 0))), blob(3, Buffer.concat([normal, ad])), blob(9, "keep item")])), blob(99, "keep root")]);
  const expected = Buffer.concat([blob(1, Buffer.concat([blob(2, blob(2, Buffer.concat([scalar(1, 0), background]))), blob(3, normal), blob(9, "keep item")])), blob(99, "keep root")]);
  assert.deepEqual(Buffer.from(run({ url: api + "get_watch", body: input }).body), expected);
});

test("guide removes only the upgrade tab, retaining home, library and unknown navigation fields", () => {
  const item = id => blob(1, blob(117501096, Buffer.concat([blob(1, id), blob(3, "label")])));
  const home = item("FEmusic_home"), library = item("FEmusic_library_landing"), upgrade = item("SPunlimited");
  const unknown = blob(777, "keep unknown root"), otherGroup = blob(4, blob(123267149, "keep unrelated group"));
  const input = Buffer.concat([otherGroup, blob(4, blob(117866661, Buffer.concat([home, upgrade, library, blob(9, "keep section")]))), unknown]);
  const expected = Buffer.concat([otherGroup, blob(4, blob(117866661, Buffer.concat([home, library, blob(9, "keep section")]))), unknown]);
  const result = run({ url: api + "guide", body: input });
  assert.deepEqual(Buffer.from(result.body), expected);
  assert.equal(Object.keys(run({ url: api + "guide", body: result.body })).length, 0);
});

test("video switching instructions and subscription callbacks remain intact", () => {
  const renderer = blob(16, blob(96149696, Buffer.concat([scalar(1, 0), scalar(5, 1), blob(7, "PApremium_upsell"), blob(90, "keep unknown")])));
  const status = Buffer.concat([scalar(1, 0), renderer]);
  const streaming = blob(4, blob(3, blob(5, "video/mp4")));
  const result = run({ body: Buffer.concat([blob(2, status), streaming]) });
  assert.deepEqual(Buffer.from(result.body), Buffer.concat([blob(2, Buffer.concat([status, background])), streaming]));
});

test("fallback targets only the observed Music Onesie POST and leaves media and ordinary YouTube alone", () => {
  const url = "https://rr1---fixture.googlevideo.com/initplayback?c=IOS_MUSIC&ack=1&rn=1";
  assert.equal(run({ url, request: true }).response.status, 200);
  for (const fixture of [{ method: "GET" }, { ua: "com.google.ios.youtube/20" }, { url: url.replace("IOS_MUSIC", "IOS") }, { url: url.replace("ack=1", "ack=0") }, { url: url.replace("initplayback", "videoplayback") }]) {
    assert.equal(Object.keys(run({ url, request: true, ...fixture })).length, 0);
  }
});

test("unrelated responses, failed requests and malformed protobuf pass through exactly once", () => {
  for (const fixture of [{ url: api.replace("youtubei.googleapis.com", "example.com") + "player" }, { url: api + "browse" }, { ua: "com.google.ios.youtube/20" }, { status: 403 }, { body: Buffer.from([0xff]) }, { body: "not binary" }]) {
    assert.equal(Object.keys(run(fixture)).length, 0);
  }
});
