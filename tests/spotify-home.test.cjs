const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const script = new vm.Script(fs.readFileSync(path.join(__dirname, "../js/Spotify-home.js"), "utf8"));

function varint(value) {
  const bytes = [];
  do {
    const byte = value % 128;
    value = Math.floor(value / 128);
    bytes.push(byte | (value ? 128 : 0));
  } while (value);
  return Buffer.from(bytes);
}

function field(number, payload) {
  payload = Buffer.from(payload);
  return Buffer.concat([varint(number * 8 + 2), varint(payload.length), payload]);
}

function section(id, payload = Buffer.from("normal content"), contentField = 3) {
  return field(1, Buffer.concat([field(1, field(1, id)), field(contentField, payload)]));
}

function home(sections, extra = Buffer.alloc(0)) {
  return Buffer.concat([field(1, Buffer.concat(sections)), extra]);
}

function execute(body, status = 200) {
  const results = [];
  script.runInNewContext({
    ArrayBuffer,
    Uint8Array,
    console: { log() {} },
    $response: { body, status },
    $done: (result) => results.push(result),
  }, { timeout: 1000 });
  assert.equal(results.length, 1, "complete exactly once");
  return results[0];
}

test("Casita removes the brand-ad section while preserving all other wire bytes", () => {
  const shortcuts = section("spotify:section:shortcuts", Buffer.alloc(1400, 65));
  const recommendations = section("spotify:section:recommendations");
  const ad = section("spotify:section:campaign|brand-ad", "Topsify", 21);
  const unknownFields = Buffer.concat([
    field(2, "opaque home metadata"),
    Buffer.from([0x98, 0x06, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01]),
    field(999, ""),
  ]);
  const input = home([shortcuts, ad, recommendations], unknownFields);
  assert.ok(input.indexOf("|brand-ad") > 666, "ad need not be near the start");
  assert.deepEqual(Buffer.from(execute(input).body), home([shortcuts, recommendations], unknownFields));
});

test("Multiple brand ads are removed and an empty section list stays valid", () => {
  const ads = ["first", "second"].map((id) => section(`spotify:section:${id}|brand-ad`, "ad", 21));
  assert.deepEqual(Buffer.from(execute(home(ads)).body), home([]));
});

test("Ad text outside the exact section identifier does not remove normal content", () => {
  const input = home([
    section("spotify:section:recommendations", "spotify:section:other|brand-ad"),
    section("spotify:section:brand-ad-collection"),
    section("other:section:test|brand-ad"),
  ], field(2, "spotify:section:metadata|brand-ad"));
  assert.equal(Object.keys(execute(input)).length, 0);
});

test("Malformed or non-success responses pass through without a partial rewrite", () => {
  const validAd = home([section("spotify:section:campaign|brand-ad", "ad", 21)]);
  for (const body of [
    Buffer.from([0x0a, 0xff]),
    Buffer.from([0x0a, 0x02, 0x0a]),
    Buffer.from([0x0a, 0x06, 0x0a, 0x04, 0x0a, 0x02, 0x0a, 0xff]),
    Buffer.concat([validAd, Buffer.from([0x12, 0xff])]),
    "not a binary response",
    undefined,
  ]) {
    assert.equal(Object.keys(execute(body)).length, 0);
  }
  for (const status of [204, 304, 500]) {
    assert.equal(Object.keys(execute(validAd, status)).length, 0);
  }
});

test("Binary views respect their offsets and ArrayBuffers are supported", () => {
  const kept = section("spotify:section:recommendations");
  const input = home([kept, section("spotify:section:campaign|brand-ad", "ad", 21)]);
  const storage = new Uint8Array(input.length + 10);
  storage.set(input, 5);
  for (const body of [storage.subarray(5, 5 + input.length), new Uint8Array(input).buffer]) {
    assert.deepEqual(Buffer.from(execute(body).body), home([kept]));
  }
});

test("Module routes the captured Casita endpoint to the new home script", () => {
  const moduleText = fs.readFileSync(path.join(__dirname, "../Script/Spotify.sgmodule"), "utf8");
  const line = moduleText.match(/^spotify-home = .*$/m)?.[0];
  assert.ok(line);
  const pattern = new RegExp(line.match(/pattern=([^,]+)/)[1]);
  for (const hostname of ["gae2-spclient.spotify.com:443", "spclient.wg.spotify.com", "gae2-spclient.wg.spotify.com"]) {
    assert.ok(pattern.test(`https://${hostname}/casita/v1/home/default?eagerload=true&timezone=Asia%2FSingapore`));
  }
  for (const url of [
    "https://example.com/casita/v1/home/default",
    "https://gae2-spclient.spotify.com/casita/v1/home/default/other",
    "https://gae2-spclient.spotify.com/collection/v2/delta",
  ]) {
    assert.equal(pattern.test(url), false);
  }
  assert.match(line, /binary-body-mode=1/);
  assert.match(line, /script-path=https:\/\/raw\.githubusercontent\.com\/Reukix\/ukix\/refs\/heads\/main\/js\/Spotify-home\.js\?v=[a-f0-9]{12}/);
});
