const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const crypto = require("node:crypto");
const { test } = require("node:test");

const root = path.join(__dirname, "..");
const code = new vm.Script(fs.readFileSync(path.join(root, "js/Spotify-lyrics.js"), "utf8"));
const key = "UKIX.Spotify.Lyrics.v1";
const id = "1SBbBe4l9i0VdkNkpgVLnG";
const alphabet = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
const gid = Buffer.from([...id].reduce((n, c) => n * 62n + BigInt(alphabet.indexOf(c)), 0n).toString(16).padStart(32, "0"), "hex");
const host = "https://gae2-spclient.spotify.com";
const info = { id, title: "Fixture Song", artists: ["Fixture Artist"], album: "Fixture Album", durationMs: 207229 };
const sample = { sync: 1, lines: [{ start: 1000, words: "First sample", syllables: [] }, { start: 2000, words: "Second sample", syllables: [] }], provider: "Fixture", providerId: "42", alternatives: [] };
const v = n => { const out = []; do { const b = n % 128; n = Math.floor(n / 128); out.push(b | (n ? 128 : 0)); } while (n); return Buffer.from(out); };
const msg = (n, value) => { value = Buffer.from(value); return Buffer.concat([v(n * 8 + 2), v(value.length), value]); };
const scalar = (n, value) => Buffer.concat([v(n * 8), v(value)]);
function parse(buffer) {
  let offset = 0;
  const read = () => { let n = 0n, shift = 0n; do { const b = buffer[offset++]; if (b === undefined) throw Error("truncated"); n |= BigInt(b & 127) << shift; if (!(b & 128)) return Number(n); shift += 7n; } while (shift < 70n); throw Error("overflow"); };
  const result = [];
  while (offset < buffer.length) {
    const start = offset, tag = read(), number = Math.floor(tag / 8), wire = tag % 8;
    let value, data;
    if (wire === 0) value = read();
    else if (wire === 2) { const size = read(); data = buffer.subarray(offset, offset + size); offset += size; }
    else if (wire === 1 || wire === 5) offset += wire === 1 ? 8 : 4;
    else throw Error("wire");
    if (!number || offset > buffer.length) throw Error("bounds");
    result.push({ number, wire, value, data, raw: buffer.subarray(start, offset) });
  }
  return result;
}
const field = (buffer, n, wire = 2) => parse(buffer).find(f => f.number === n && f.wire === wire);
const payload = (buffer, n) => field(buffer, n)?.data;
const text = (buffer, n) => payload(buffer, n)?.toString("utf8");
function store(entry = { info }) {
  return new Map([[key, JSON.stringify({ version: 1, tracks: { [id]: entry }, cooldowns: {} })]]);
}
const positive = () => store({ info, result: sample, expires: Date.now() + 60000 });
function run({ url = host + "/color-lyrics/v2/track/" + id, status = 200, body = Buffer.alloc(0), requestHeaders = { Accept: "application/protobuf" }, responseHeaders = {}, args = "Lyrics=true&Translate=false", storage = store(), http = () => { throw Error("unexpected HTTP request"); } } = {}) {
  return new Promise((resolve, reject) => {
    const calls = []; let completed = 0;
    const timer = setTimeout(() => reject(Error("script did not finish")), 3000);
    const context = {
      Uint8Array, ArrayBuffer, console: { log() {} },
      $argument: args, $request: { url, method: "GET", headers: requestHeaders }, $response: { status, body, headers: responseHeaders },
      $persistentStore: { read(k) { assert.equal(k, key); return storage.get(k) || null; }, write(value, k) { assert.equal(k, key); storage.set(k, value); return true; } },
      $httpClient: { get(req, cb) {
        try { calls.push(req); http(req, (error, response, body) => cb(error, response, typeof body === "object" && body !== null ? JSON.stringify(body) : body)); }
        catch (e) { clearTimeout(timer); reject(e); }
      } },
      $done(result) { completed++; clearTimeout(timer); if (completed !== 1) return reject(Error("multiple completions")); resolve({ result, calls, storage }); },
    };
    try { code.runInNewContext(context, { timeout: 1000 }); } catch (e) { clearTimeout(timer); reject(e); }
  });
}
const ok = (cb, body) => cb(null, { status: 200, headers: {} }, body);
const official = () => {
  const syllable = msg(3, Buffer.concat([scalar(1, 1000), scalar(2, 5)]));
  const line = msg(2, Buffer.concat([scalar(1, 1000), msg(2, "Hello sample"), syllable, msg(70, "line unknown")]));
  return Buffer.concat([msg(1, Buffer.concat([scalar(1, 2), line, msg(3, "Spotify"), msg(600, "lyrics unknown")])), msg(2, "colors"), msg(700, "response unknown")]);
};

test("official word timings, colors and unknown fields pass through without network when translation is off", async () => {
  const { result, calls } = await run({ body: official() });
  assert.equal(Object.keys(result).length, 0);
  assert.equal(calls.length, 0);
});

test("translation adds native alternatives while preserving official lines and caches by exact source text", async () => {
  const body = official(), storage = store();
  const fixture = { body, storage, args: "Lyrics=true&Translate=true&TargetLanguage=zh-CN", http: (req, cb) => { assert.ok(req.url.startsWith("https://translate.googleapis.com/")); ok(cb, [[["示例翻译", "Hello sample"]]]); } };
  const { result } = await run(fixture);
  const out = Buffer.from(result.body), before = payload(body, 1), after = payload(out, 1);
  assert.deepEqual(payload(after, 2), payload(before, 2));
  assert.deepEqual(payload(after, 600), payload(before, 600));
  assert.deepEqual(payload(out, 700), payload(body, 700));
  assert.deepEqual(payload(out, 2), payload(body, 2));
  assert.equal(text(payload(after, 9), 1), "zh");
  assert.equal(text(payload(after, 9), 2), "示例翻译");
  const cached = await run({ ...fixture, http: () => { throw Error("cached translation must not fetch"); } });
  assert.deepEqual(Buffer.from(cached.result.body), out);
});

test("JSON lyrics preserve official fields and receive the same bilingual alternative", async () => {
  const body = JSON.stringify({ lyrics: { syncType: "LINE_SYNCED", lines: [{ startTimeMs: "1", words: "Hello sample", custom: 7 }], provider: "Spotify", custom: "keep" }, colors: { background: 123 }, opaque: true });
  const { result } = await run({ url: host + "/color-lyrics/v2/track/" + id + "/image/spotify:image:fixture?format=json", body, args: "Translate=true", http: (req, cb) => ok(cb, [[["示例翻译"]]]) });
  const document = JSON.parse(Buffer.from(result.body));
  assert.equal(document.lyrics.provider, "Spotify");
  assert.equal(document.lyrics.lines[0].custom, 7);
  assert.equal(document.lyrics.custom, "keep");
  assert.equal(document.opaque, true);
  assert.deepEqual(document.colors, { background: 123 });
  assert.deepEqual(document.lyrics.alternatives, [{ language: "zh", lines: ["示例翻译"] }]);
});

test("a protobuf request with a JSON 404 receives independently encoded word lyrics after strict matching", async () => {
  const calls = [];
  const { result } = await run({ status: 404, body: '{"error":{"status":404}}', responseHeaders: { "Content-Type": "application/json", "Content-Encoding": "br", ETag: "stale" }, requestHeaders: { Accept: "application/protobuf", Authorization: "Bearer fixture", Cookie: "fixture", "Client-Token": "fixture" }, http: (req, cb) => {
    calls.push(req);
    for (const h of Object.keys(req.headers)) assert.ok(!/authorization|cookie|client-token/i.test(h));
    assert.equal(req["auto-cookie"], false);
    if (req.url.includes("cloudsearch")) return ok(cb, { code: 200, result: { songs: [{ id: 1, name: info.title, ar: [{ name: info.artists[0] }], dt: 999000 }, { id: 2, name: info.title, ar: [{ name: info.artists[0] }], dt: 207000 }] } });
    assert.ok(req.url.includes("id=2&"));
    ok(cb, { code: 200, yrc: { lyric: "[1000,1200](1000,400,0)Hello (echo) (1400,800,0)sample" } });
  } });
  assert.equal(result.status, 200);
  assert.equal(result.headers["Content-Encoding"], undefined);
  assert.equal(result.headers.ETag, undefined);
  const lyrics = payload(Buffer.from(result.body), 1), line = payload(lyrics, 2);
  assert.equal(field(lyrics, 1, 0).value, 2);
  assert.equal(text(line, 2), "Hello (echo) sample");
  assert.equal(field(payload(line, 3), 1, 0).value, 1000);
  assert.equal(field(payload(line, 3), 2, 0).value, "Hello (echo) ".length);
  assert.equal(calls.length, 2);
});

test("a failed first provider falls back to LRCLIB, keeping untimed lyrics untimed", async () => {
  const { result } = await run({ status: 404, http: (req, cb) => {
    if (req.url.includes("music.163.com")) return cb("network unavailable", null, "");
    assert.ok(req.url.startsWith("https://lrclib.net/api/get?"));
    ok(cb, { id: 42, trackName: info.title, artistName: info.artists[0], duration: 207, plainLyrics: "First sample\nSecond sample", instrumental: false });
  } });
  const lyrics = payload(Buffer.from(result.body), 1);
  assert.equal(field(lyrics, 1, 0).value, 0);
  assert.equal(text(lyrics, 3), "LRCLIB");
  assert.equal(parse(lyrics).filter(f => f.number === 2).length, 2);
});

test("LRC offsets and repeated timestamps keep their distinct native line times", async () => {
  const { result } = await run({ status: 404, http: (req, cb) => {
    if (req.url.includes("cloudsearch")) return ok(cb, { code: 200, result: { songs: [{ id: 2, name: info.title, ar: [{ name: info.artists[0] }], dt: 207000 }] } });
    ok(cb, { code: 200, lrc: { lyric: "[offset:-100]\n[00:01.10][00:02.10]Sample line" } });
  } });
  const lines = parse(payload(Buffer.from(result.body), 1)).filter(f => f.number === 2);
  assert.deepEqual(lines.map(f => field(f.data, 1, 0).value), [1000, 2000]);
});

test("wrong recordings and instrumental results leave the original 404 intact", async () => {
  for (const lr of [{ id: 1, trackName: info.title, artistName: "Another Artist", duration: 207, plainLyrics: "Wrong song" }, { id: 2, trackName: info.title, artistName: info.artists[0], duration: 207, instrumental: true }]) {
    const { result } = await run({ status: 404, http: (req, cb) => {
      if (req.url.includes("music.163.com")) return ok(cb, { code: 200, result: { songs: [] } });
      ok(cb, lr);
    } });
    assert.equal(Object.keys(result).length, 0);
  }
});

test("LRCLIB Retry-After suppresses both immediate and subsequent requests", async () => {
  const storage = store(); let lrCalls = 0;
  const http = (req, cb) => {
    if (req.url.includes("music.163.com")) return ok(cb, { code: 200, result: { songs: [] } });
    lrCalls++; cb(null, { status: 429, headers: { "Retry-After": "120" } }, "rate limited");
  };
  await run({ status: 404, storage, http });
  await run({ status: 404, storage, http });
  assert.equal(lrCalls, 1);
  assert.ok(JSON.parse(storage.get(key)).cooldowns.lrclib > Date.now() + 119000);
});

test("cold lookup obtains public catalog metadata without sending Spotify credentials", async () => {
  const { result, storage } = await run({ status: 404, storage: new Map(), requestHeaders: { Accept: "application/json", Authorization: "Bearer fixture" }, http: (req, cb) => {
    assert.equal(req.headers.Authorization, undefined);
    if (req.url.includes("/embed/track/")) return ok(cb, '<script id="__NEXT_DATA__">' + JSON.stringify({ props: { pageProps: { state: { data: { entity: { id, uri: "spotify:track:" + id, name: info.title, artists: [{ name: info.artists[0] }], duration: 207229 } } } } } }) + "</script>");
    if (req.url.includes("music.163.com")) return ok(cb, { code: 200, result: { songs: [] } });
    ok(cb, { id: 3, trackName: info.title, artistName: info.artists[0], duration: 207, syncedLyrics: "[00:01.00]Sample lyric" });
  } });
  assert.equal(JSON.parse(Buffer.from(result.body)).lyrics.provider, "LRCLIB");
  assert.equal(JSON.parse(storage.get(key)).tracks[id].info.title, info.title);
});

test("scroll inserts the observed native lyrics card and removes ads without damaging other wire fields", async () => {
  const artist = msg(1, Buffer.concat([msg(3, "artist payload"), msg(23, msg(1, "artist identity"))]));
  const ad = msg(1, msg(30, "advertisement"));
  const unknown = msg(700, "opaque root");
  const { result } = await run({ url: host + "/scrollsita/v1/scroll/spotify:track:" + id, body: Buffer.concat([msg(1, Buffer.concat([artist, ad])), unknown]), storage: positive() });
  const expected = msg(1, Buffer.concat([msg(5, msg(1, "spotify:track:" + id)), msg(23, msg(1, "spotify:section:0JQ5DB6s3cssW5Bo6cGq21"))]));
  assert.deepEqual(Buffer.from(result.body), Buffer.concat([msg(1, Buffer.concat([expected, artist])), unknown]));
});

test("disabling lyrics retains scroll ad removal and makes no external request", async () => {
  const keep = msg(1, msg(3, "artist"));
  const { result } = await run({ url: host + "/scrollsita/v1/scroll/spotify:track:" + id, body: msg(1, Buffer.concat([keep, msg(1, msg(30, "ad"))])), args: "Lyrics=false&Translate=true" });
  assert.deepEqual(Buffer.from(result.body), msg(1, keep));
});

const track = () => Buffer.concat([msg(1, gid), msg(2, info.title), msg(4, msg(2, info.artists[0])), scalar(7, 207229 * 2), msg(700, "opaque audio data")]);
test("classic native metadata caches catalog data and enables only verified, unexpired lyrics", async () => {
  const body = track(), url = host + "/metadata/4/track/" + gid.toString("hex");
  const { result, storage } = await run({ url, body, storage: positive() });
  assert.deepEqual(Buffer.from(result.body), Buffer.concat([body, scalar(18, 1)]));
  assert.equal(JSON.parse(storage.get(key)).tracks[id].info.durationMs, 207229);
  const expired = await run({ url, body, storage: store({ info, result: sample, expires: Date.now() - 1 }) });
  assert.equal(Object.keys(expired.result).length, 0);
});

test("extended metadata preserves unrelated extension kinds and rejects mismatched catalog IDs", async () => {
  const envelope = (uri, raw) => msg(2, Buffer.concat([scalar(2, 10), msg(3, Buffer.concat([msg(2, uri), msg(3, msg(2, raw))]))]));
  const unrelated = msg(2, Buffer.concat([scalar(2, 21), msg(3, "opaque episode transcript")]));
  const good = envelope("spotify:track:" + id, track());
  const { result } = await run({ url: host + "/extended-metadata/v0/extended-metadata", body: Buffer.concat([good, unrelated]), storage: positive() });
  assert.deepEqual(Buffer.from(result.body), Buffer.concat([envelope("spotify:track:" + id, Buffer.concat([track(), scalar(18, 1)])), unrelated]));
  const bad = await run({ url: host + "/extended-metadata/v0/extended-metadata", body: envelope("spotify:track:" + "0".repeat(22), track()), storage: positive() });
  assert.equal(Object.keys(bad.result).length, 0);
});

test("playback state changes only the current verified track's lyrics metadata", async () => {
  const originalTrack = Buffer.concat([msg(1, "spotify:track:" + id), msg(3, Buffer.concat([msg(1, "provider"), msg(2, "context")])), msg(700, "opaque")]);
  const rootUnknown = msg(500, "cluster metadata");
  const { result } = await run({ url: host + "/connect-state/v1/devices/fixture-device", body: Buffer.concat([msg(3, msg(7, originalTrack)), rootUnknown]), storage: positive() });
  const expected = Buffer.concat([originalTrack, msg(3, Buffer.concat([msg(1, "has_lyrics"), msg(2, "true")]))]);
  assert.deepEqual(Buffer.from(result.body), Buffer.concat([msg(3, msg(7, expected)), rootUnknown]));
});

test("malformed wire data, unrelated hosts and authentication failures pass through", async () => {
  for (const fixture of [
    { body: Buffer.from([0xff, 0xff]) },
    { url: "https://gae2-spclient.spotify.com.example.net/color-lyrics/v2/track/" + id, status: 404 },
    { status: 401 }, { status: 403 },
  ]) {
    const { result } = await run(fixture);
    assert.equal(Object.keys(result).length, 0);
  }
});

test("integrated module routes all four handlers to one independent, versioned script", () => {
  const module = fs.readFileSync(path.join(root, "Script/Spotify.sgmodule"), "utf8");
  assert.doesNotMatch(module, /DualSubs|\.bundle\.js|PreferencePanes/);
  const version = crypto.createHash("sha256").update(fs.readFileSync(path.join(root, "js/Spotify-lyrics.js"))).digest("hex").slice(0, 12);
  const names = ["spotify-scroll", "spotify-lyrics", "spotify-lyrics-metadata", "spotify-lyrics-playback"];
  for (const name of names) {
    const line = module.split("\n").find(s => s.startsWith(name + "="));
    assert.ok(line);
    assert.ok(line.includes("Spotify-lyrics.js?v=" + version));
    assert.ok(line.includes("binary-body-mode=true"));
  }
  const regex = new RegExp(module.match(/^spotify-lyrics=.*?pattern=([^,]+)/m)[1]);
  for (const server of ["gae2-spclient.spotify.com:443", "spclient.wg.spotify.com", "gae2-spclient.wg.spotify.com"]) {
    for (const suffix of ["", "?format=json", "/image/spotify:image:fixture?clientLanguage=zh-CN"]) assert.ok(regex.test(`https://${server}/color-lyrics/v2/track/${id}${suffix}`));
  }
  assert.equal(regex.test(`https://spclient.wg.spotify.com.evil.example/color-lyrics/v2/track/${id}`), false);
});
