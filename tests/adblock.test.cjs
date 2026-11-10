const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");

const root = path.join(__dirname, "..");
const jdSource = fs.readFileSync(path.join(root, "js/adblock/jd.js"), "utf8");
function runJD(body, url = "https://api.m.jd.com/client.action") {
  const results = [];
  vm.runInNewContext(jdSource, {
    $request: { url, method: "POST" },
    $response: { status: 200, body },
    $done: (value) => results.push(value),
    console: { log() {} },
  }, { timeout: 1000 });
  assert.equal(results.length, 1);
  return results[0];
}

test("JD removes old splash images while preserving a successful response", () => {
  const input = { code: "0", images: [{ image: "ad.jpg" }], showTimesDaily: 3, unrelated: "keep" };
  const result = JSON.parse(runJD(JSON.stringify(input), "https://api.m.jd.com/client.action?functionId=start").body);
  assert.deepEqual(result.images, []);
  assert.equal(result.showTimesDaily, 0);
  assert.equal(result.code, "0");
  assert.equal(result.unrelated, "keep");
});

test("JD handles body-routed base64 JSON and keeps Chinese/emoji intact", () => {
  const input = { code: "0", message: "成功🛒", data: { images: [{ image: "ad.jpg" }], showTimesDaily: "2", normal: "商品" } };
  const body = Buffer.from(JSON.stringify(input)).toString("base64");
  const result = JSON.parse(Buffer.from(runJD(body).body, "base64").toString());
  assert.equal(result.message, "成功🛒");
  assert.equal(result.data.normal, "商品");
  assert.deepEqual(result.data.images, []);
  assert.equal(result.data.showTimesDaily, "0");
});

test("JD preserves nested response encodings", () => {
  const data = Buffer.from(JSON.stringify({ images: ["ad"], showTimesDaily: 1 })).toString("base64");
  const result = JSON.parse(runJD(JSON.stringify({ code: 200, data })).body);
  assert.equal(result.code, 200);
  assert.equal(typeof result.data, "string");
  assert.deepEqual(JSON.parse(Buffer.from(result.data, "base64").toString()).images, []);
});

test("JD keeps shopping images and captured diagnostic response shapes untouched", () => {
  for (const input of [
    { code: 200, message: "成功", data: null },
    { code: 200, data: { startupConfig: { enable: 1, frequency: 300 }, crashConfig: { iOSCrash: { enable: 1 } } } },
    { code: "0", data: { images: ["product.jpg"], price: 199, orderId: "example" } },
  ]) {
    const body = JSON.stringify(input);
    assert.equal(Object.keys(runJD(body)).length, 0);
  }
});

test("JD malformed data and invalid URL escaping pass through once", () => {
  for (const body of ["", "<html>error</html>", "not base64?", "e30=invalid", "null", "[]"]) {
    assert.equal(Object.keys(runJD(body)).length, 0);
  }
  assert.equal(Object.keys(runJD("{}", "https://api.m.jd.com/client.action?functionId=%ZZ")).length, 0);
});

test("JD removes identified promotion floors and keeps order/cart/tool floors", () => {
  const input = { data: { floors: [
    { mId: "bannerFloor" }, { mId: "orderIdFloor", data: { orderId: "example" } },
    { mId: "cartFloor" }, { mId: "iconToolFloor" }, { mId: "new-server-floor" },
  ] } };
  const result = JSON.parse(runJD(JSON.stringify(input)).body);
  assert.deepEqual(result.data.floors.map((item) => item.mId), ["orderIdFloor", "cartFloor", "iconToolFloor", "new-server-floor"]);
});

test("Xiaohongshu jq rules produce arrays and objects with their native types", (t) => {
  if (spawnSync("jq", ["--version"]).status !== 0) return t.skip("jq is unavailable");
  const module = fs.readFileSync(path.join(root, "Script/Xiaohongshu.sgmodule"), "utf8");
  const expressions = module.split("\n").filter((line) => line.startsWith("http-response-jq ")).map((line) => line.match(/ '(.*)'$/)[1]);
  const banner = spawnSync("jq", [expressions[0]], {
    input: JSON.stringify({ data: { banner: "ad" } }), encoding: "utf8",
  });
  assert.equal(banner.status, 0, banner.stderr);
  assert.deepEqual(JSON.parse(banner.stdout).data, {});
  let body = JSON.stringify({ data: { items: [1], hint_words: [1], queries: [1], hint_word: { text: "ad" } } });
  for (const expression of expressions.slice(1)) {
    const result = spawnSync("jq", [expression], { input: body, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    body = result.stdout;
  }
  const result = JSON.parse(body);
  assert.deepEqual(result.data.items, []);
  assert.deepEqual(result.data.hint_words, []);
  assert.deepEqual(result.data.queries, []);
  assert.deepEqual(result.data.hint_word, {});
});
