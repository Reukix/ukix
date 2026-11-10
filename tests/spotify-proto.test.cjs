const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../js/Spotify-proto.js"), "utf8");
const script = new vm.Script(source);
const host = "https://gae2-spclient.spotify.com:443";

function execute(url, method, body, { status = 200, quantumult = false } = {}) {
  const results = [];
  const context = vm.createContext({
    Uint8Array,
    ArrayBuffer,
    console: { log() {} },
    $request: { url, method },
    $response: { status, body, bodyBytes: body },
    $done: (result) => results.push(result),
    ...(quantumult ? { $task: {} } : {}),
  });
  script.runInContext(context, { timeout: 3000 });
  assert.equal(results.length, 1, "each response completes exactly once");
  return { context, result: results[0] };
}

const { context: schemaContext } = execute("", "", undefined, { status: 304 });
const root = vm.runInContext("protobuf.Root.fromJSON(spotifyJson)", schemaContext);
const encode = (name, value) => root.lookupType(name).encode(value).finish();
const decode = (name, value) => root.lookupType(name).decode(Array.from(value));

function accountResponse() {
  return {
    accountAttributes: {
      ads: { boolValue: true },
      catalogue: { stringValue: "free" },
      type: { stringValue: "free" },
      "server-only-attribute": { stringValue: "keep-me" },
    },
  };
}

test("Nebula GET patches account attributes and keeps unrelated attributes", () => {
  const { result } = execute(
    `${host}/nebula/v1/configuration/attributes?revision=2`,
    "GET",
    encode("AccountAttributesResponse", accountResponse()),
  );
  const attributes = decode("AccountAttributesResponse", result.body).accountAttributes;
  assert.equal(attributes.ads.boolValue, false);
  assert.equal(attributes.catalogue.stringValue, "premium");
  assert.equal(attributes.type.stringValue, "premium");
  assert.equal(attributes["server-only-attribute"].stringValue, "keep-me");
});

test("Resolver POST keeps configuration identity and new server flags", () => {
  const input = {
    configuration: {
      configurationAssignmentId: "keep-assignment-id",
      fetchTimeMillis: 12345,
      assignedValues: [{
        propertyId: { scope: "ios-future-feature", name: "server_only_flag" },
        metadata: { policyId: 7, externalRealm: "server", externalRealmId: "8" },
        boolValue: { value: true },
      }],
    },
  };
  const { result } = execute(
    `${host}/remote-config-resolver/v3/configuration`,
    "POST",
    encode("ResolveResponse", input),
  );
  const config = decode("ResolveResponse", result.body).configuration;
  assert.equal(config.configurationAssignmentId, "keep-assignment-id");
  const preserved = config.assignedValues.filter(
    (value) => value.propertyId.scope === "ios-future-feature",
  );
  assert.equal(preserved.length, 1);
  assert.equal(preserved[0].boolValue.value, true);
  assert.equal(preserved[0].metadata.externalRealm, "server");
  assert.ok(config.assignedValues.length > 1, "configured overrides were applied");
});

test("Legacy bootstrap and customize responses remain supported", () => {
  const customization = {
    accountAttributesSuccess: accountResponse(),
    resolveSuccess: { configuration: { assignedValues: [] } },
  };
  for (const [endpoint, type, message] of [
    ["user-customization-service/v1/customize", "UcsResponseWrapper", { success: customization }],
    ["bootstrap/v1/bootstrap", "BootstrapResponse", {
      ucsResponseV0: { success: { customization: { success: customization } } },
      trialsFacadeResponseV1: { success: { field1: 1 } },
    }],
  ]) {
    const { result } = execute(`${host}/${endpoint}`, "POST", encode(type, message));
    const output = decode(type, result.body);
    const attributes = type === "UcsResponseWrapper"
      ? output.success.accountAttributesSuccess.accountAttributes
      : output.ucsResponseV0.success.customization.success.accountAttributesSuccess.accountAttributes;
    assert.equal(attributes.ads.boolValue, false);
    assert.equal(attributes.catalogue.stringValue, "premium");
    if (type === "BootstrapResponse") assert.equal(output.trialsFacadeResponseV1, null);
  }
});

test("304, malformed bodies and unsupported methods pass through", () => {
  for (const args of [
    [`${host}/nebula/v1/configuration/attributes`, "GET", undefined, { status: 304 }],
    [`${host}/nebula/v1/configuration/attributes`, "GET", new Uint8Array([10, 255])],
    [`${host}/nebula/v1/configuration/attributes`, "POST", encode("AccountAttributesResponse", accountResponse())],
    [`${host}/remote-config-resolver/v3/configuration`, "POST", new Uint8Array()],
  ]) {
    const { result } = execute(...args);
    assert.equal(Object.keys(result).length, 0);
  }
});

test("Quantumult X receives a correctly sized binary response", () => {
  const { result } = execute(
    `${host}/nebula/v1/configuration/attributes`, "GET",
    encode("AccountAttributesResponse", accountResponse()), { quantumult: true },
  );
  const attributes = decode("AccountAttributesResponse", new Uint8Array(result.bodyBytes)).accountAttributes;
  assert.equal(attributes.ads.boolValue, false);
});

test("Module matches new endpoints, query strings, ports and regional hosts", () => {
  const moduleText = fs.readFileSync(path.join(__dirname, "../Script/Spotify.sgmodule"), "utf8");
  const pattern = new RegExp(moduleText.match(/^spotify-proto = .*?pattern=([^,]+)/m)[1]);
  const headerPattern = new RegExp(moduleText.match(/^http-request (\S+) header-del if-none-match$/m)[1]);
  for (const hostname of ["gae2-spclient.spotify.com:443", "spclient.wg.spotify.com:443", "gae2-spclient.wg.spotify.com"]) {
    for (const endpoint of ["nebula/v1/configuration/attributes", "remote-config-resolver/v3/configuration"]) {
      const url = `https://${hostname}/${endpoint}?revision=2`;
      assert.ok(pattern.test(url));
      assert.ok(headerPattern.test(url));
    }
  }
  assert.equal(pattern.test(`${host}/remote-config-resolver/v3/unauth/configuration`), false);
  assert.equal(pattern.test("https://example.com/nebula/v1/configuration/attributes"), false);
});
