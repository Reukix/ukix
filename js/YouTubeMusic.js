// YouTube Music iOS: playback ad removal and background playback.
(() => {
  try {
    const url = String($request.url || "");
    const headers = $request.headers || {};
    const userAgent = Object.keys(headers).find(key => key.toLowerCase() === "user-agent");
    const music = /com\.google\.ios\.youtubemusic\//i.test(headers[userAgent] || "");
    if (!music) return $done({});

    if (typeof $response === "undefined") {
      // An empty Onesie result lets this client retry the standard player API.
      // Only the observed Music playback request is affected, never media chunks.
      if ($request.method === "POST"
        && /^https:\/\/[\w-]+\.googlevideo\.com(?::443)?\/initplayback\?/i.test(url)
        && /[?&]c=IOS_MUSIC(?:&|$)/.test(url) && /[?&]ack=1(?:&|$)/.test(url)) {
        console.log("YouTube Music: retry through player API");
        return $done({ response: { status: 200, headers: { "Content-Type": "text/plain", "Cache-Control": "no-store" }, body: "" } });
      }
      return $done({});
    }
    const route = /^https:\/\/youtubei\.googleapis\.com(?::443)?\/youtubei\/v1\/(player|next|get_watch|guide)(?:\?|$)/i.exec(url);
    if (!route || Number($response.status || $response.statusCode) !== 200) return $done({});
    const source = $response.body;
    const input = ArrayBuffer.isView(source)
      ? new Uint8Array(source.buffer, source.byteOffset, source.byteLength)
      : source instanceof ArrayBuffer ? new Uint8Array(source) : null;
    if (!input?.length || input.length > 4194304) return $done({});

    function fields(data) {
      let offset = 0;
      function uint() {
        let value = 0;
        for (let i = 0; i < 5; i++) {
          if (offset >= data.length) throw Error("truncated varint");
          const byte = data[offset++];
          value += (byte & 127) * 2 ** (i * 7);
          if (!(byte & 128)) {
            if (value > 0xffffffff) throw Error("varint overflow");
            return value;
          }
        }
        throw Error("invalid varint");
      }
      const result = [];
      while (offset < data.length) {
        const start = offset, tag = uint(), number = Math.floor(tag / 8), wire = tag % 8;
        if (!number || result.length >= 100000) throw Error("invalid message");
        let payload;
        if (wire === 0) {
          let count = 0, byte;
          do {
            if (offset >= data.length || count === 10) throw Error("invalid scalar");
            byte = data[offset++]; count++;
            if (count === 10 && byte > 1) throw Error("scalar overflow");
          } while (byte & 128);
        } else if (wire === 1 || wire === 5) offset += wire === 1 ? 8 : 4;
        else if (wire === 2) {
          const length = uint();
          if (length > data.length - offset) throw Error("invalid length");
          payload = data.subarray(offset, offset + length); offset += length;
        } else throw Error("unsupported wire type");
        if (offset > data.length) throw Error("truncated field");
        result.push({ number, wire, payload, raw: data.subarray(start, offset) });
      }
      return result;
    }
    function join(parts) {
      const output = new Uint8Array(parts.reduce((size, part) => size + part.length, 0));
      let offset = 0;
      for (const part of parts) { output.set(part, offset); offset += part.length; }
      return output;
    }
    function uint(value) {
      const result = [];
      do { const byte = value % 128; value = Math.floor(value / 128); result.push(byte | (value ? 128 : 0)); } while (value);
      return new Uint8Array(result);
    }
    const blob = (number, data) => join([uint(number * 8 + 2), uint(data.length), data]);
    const enabled = new Uint8Array([8, 1]);
    let ads = 0, background = 0, navigation = 0;
    function replace(list, number, payload) {
      const found = list.filter(field => field.number === number && field.wire === 2);
      if (found.length === 1 && equal(found[0].payload, payload)) return join(list.map(field => field.raw));
      return join([...list.filter(field => field.number !== number || field.wire !== 2).map(field => field.raw), blob(number, payload)]);
    }
    function equal(a, b) { return a.length === b.length && a.every((byte, index) => byte === b[index]); }
    function backgroundAbility(data) {
      const list = fields(data), renderer = list.find(field => field.number === 11 && field.wire === 2);
      const child = renderer ? fields(renderer.payload) : [];
      const ability = child.find(field => field.number === 64657230 && field.wire === 2);
      const values = ability ? fields(ability.payload) : [];
      const patchedAbility = join([...values.filter(field => field.number !== 1 || field.wire !== 0).map(field => field.raw), enabled]);
      let output = replace(list, 11, replace(child, 64657230, patchedAbility));
      if (!equal(output, data)) background++;
      return output;
    }
    function player(data) {
      const list = fields(data), output = [];
      for (const field of list) {
        if ((field.number === 7 || field.number === 68) && field.wire === 2) { ads++; continue; }
        if (field.number === 2 && field.wire === 2) output.push(blob(2, backgroundAbility(field.payload)));
        else output.push(field.raw);
      }
      return join(output);
    }
    function contains(data, needle) {
      outer: for (let i = 0; i <= data.length - needle.length; i++) {
        for (let j = 0; j < needle.length; j++) if (data[i + j] !== needle.charCodeAt(j)) continue outer;
        return true;
      }
      return false;
    }
    function next(data) {
      return join(fields(data).filter(field => {
        // Captured IOS_MUSIC next responses carry an advertiser overlay here.
        if (field.number === 14 && field.wire === 2 && contains(field.payload, "googleadservices.com/pagead/aclk")) { ads++; return false; }
        return true;
      }).map(field => field.raw));
    }
    function watch(data) {
      return join(fields(data).map(field => {
        if (field.number !== 1 || field.wire !== 2) return field.raw;
        return blob(1, join(fields(field.payload).map(child => {
          if (child.wire !== 2) return child.raw;
          if (child.number === 2) return blob(2, player(child.payload));
          if (child.number === 3) return blob(3, next(child.payload));
          return child.raw;
        })));
      }));
    }
    function guide(data) {
      return join(fields(data).map(group => {
        if (group.wire !== 2 || ![4, 6].includes(group.number)) return group.raw;
        return blob(group.number, join(fields(group.payload).map(section => {
          if (section.number !== 117866661 || section.wire !== 2) return section.raw;
          return blob(section.number, join(fields(section.payload).filter(item => {
            if (item.number !== 1 || item.wire !== 2) return true;
            for (const renderer of fields(item.payload)) {
              if (renderer.wire !== 2 || ![117501096, 318370163].includes(renderer.number)) continue;
              const id = fields(renderer.payload).find(field => field.number === 1 && field.wire === 2);
              if (id && equal(id.payload, new Uint8Array([83, 80, 117, 110, 108, 105, 109, 105, 116, 101, 100]))) { navigation++; return false; }
            }
            return true;
          }).map(item => item.raw)));
        })));
      }));
    }
    const output = ({ player, next, get_watch: watch, guide })[route[1].toLowerCase()](input);
    if (equal(input, output)) return $done({});
    console.log("YouTube Music: " + route[1] + ", ads=" + ads + ", background=" + background + ", navigation=" + navigation);
    return $done({ body: output });
  } catch (_) {
    console.log("YouTube Music: unexpected response left unchanged");
    return $done({});
  }
})();
