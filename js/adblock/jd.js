/*
 * JD response cleanup for Surge, 2026.11.10.1.
 * Handles plaintext and base64 JSON without changing unrelated API responses.
 */
(function () {
  const request = $request;
  const response = $response;
  if (!/^https?:\/\/api\.m\.jd\.com(?::443)?\/client\.action(?:\?|$)/i.test(request.url)
    || typeof response.body !== "string"
    || (response.status && Number(response.status) !== 200)) {
    return $done({});
  }

  const base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const floorAds = new Set([
    "banner", "jdDeliveryBanner", "bannerFloor", "bpDynamicFloor", "plusFloor",
    "bigSaleFloor", "buyOften", "newAttentionCard", "newBigSaleFloor",
    "newStyleAttentionCard", "newsFloor", "noticeFloor", "recommendfloor",
  ]);
  const homeAds = new Set([
    "bottomXview", "float", "photoCeiling", "ruleFloat", "searchIcon",
    "topRotate", "tabBarAtmosphere",
  ]);
  const functionMatch = /[?&]functionId=([^&#]*)/i.exec(request.url);
  let functionId = "";
  try {
    functionId = functionMatch ? decodeURIComponent(functionMatch[1]) : "";
  } catch (_) { /* Invalid URL escapes must not prevent a pass-through. */ }
  let splashChanged = false;

  function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
  }

  function decodeBase64(text) {
    text = text.replace(/\s+/g, "").replace(/-/g, "+").replace(/_/g, "/");
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(text) || text.length % 4 === 1) {
      throw new Error("unsupported base64");
    }
    let accumulator = 0;
    let bits = 0;
    let escaped = "";
    for (const character of text.replace(/=+$/, "")) {
      accumulator = (accumulator << 6) | base64.indexOf(character);
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        escaped += "%" + ((accumulator >>> bits) & 255).toString(16).padStart(2, "0");
        accumulator &= (1 << bits) - 1;
      }
    }
    return decodeURIComponent(escaped);
  }

  function encodeBase64(text) {
    const bytes = encodeURIComponent(text).replace(/%([0-9A-F]{2})/g,
      (_, hex) => String.fromCharCode(parseInt(hex, 16)));
    let result = "";
    for (let index = 0; index < bytes.length; index += 3) {
      const a = bytes.charCodeAt(index);
      const b = bytes.charCodeAt(index + 1);
      const c = bytes.charCodeAt(index + 2);
      result += base64[a >>> 2];
      result += base64[((a & 3) << 4) | (Number.isNaN(b) ? 0 : b >>> 4)];
      result += Number.isNaN(b) ? "=" : base64[((b & 15) << 2) | (Number.isNaN(c) ? 0 : c >>> 6)];
      result += Number.isNaN(c) ? "=" : base64[c & 63];
    }
    return result;
  }

  function unpack(text) {
    try {
      const value = JSON.parse(text);
      if (isObject(value)) return { value, pack: JSON.stringify };
      if (typeof value === "string") {
        const inner = JSON.parse(decodeBase64(value));
        if (isObject(inner)) return {
          value: inner,
          pack: (object) => JSON.stringify(encodeBase64(JSON.stringify(object))),
        };
      }
    } catch (_) {
      const value = JSON.parse(decodeBase64(text));
      if (isObject(value)) return {
        value,
        pack: (object) => encodeBase64(JSON.stringify(object)),
      };
    }
    return null;
  }

  function clearList(object, key) {
    if (!Array.isArray(object[key]) || !object[key].length) return false;
    object[key] = [];
    return true;
  }

  function remove(object, key) {
    if (!Object.prototype.hasOwnProperty.call(object, key)) return false;
    delete object[key];
    return true;
  }

  function cleanPayload(payload) {
    let changed = false;
    // A bare `images` array also occurs in normal shopping responses.
    const splash = Array.isArray(payload.images)
      && (Object.prototype.hasOwnProperty.call(payload, "showTimesDaily")
        || ["start", "startup", "getSplash"].includes(functionId));
    if (splash) {
      changed = clearList(payload, "images") || changed;
      if (Object.prototype.hasOwnProperty.call(payload, "showTimesDaily")
        && Number(payload.showTimesDaily) !== 0) {
        payload.showTimesDaily = typeof payload.showTimesDaily === "string" ? "0" : 0;
        changed = true;
      }
      splashChanged = changed || splashChanged;
    }
    if (Array.isArray(payload.floorList)) {
      const kept = payload.floorList.filter((floor) => !homeAds.has(floor?.type));
      if (kept.length !== payload.floorList.length) {
        payload.floorList = kept;
        changed = true;
      }
      changed = clearList(payload, "webViewFloorList") || changed;
    }
    if (Array.isArray(payload.floors)) {
      const kept = payload.floors.filter((floor) => !floorAds.has(floor?.mId));
      if (kept.length !== payload.floors.length) {
        payload.floors = kept;
        changed = true;
      }
      changed = remove(payload, "bannerInfo") || changed;
      for (const floor of payload.floors) {
        const data = floor?.data;
        if (!isObject(data)) continue;
        if (floor.mId === "basefloorinfo") {
          for (const key of ["commonPopup", "commonPopup_dynamic", "floatLayer"]) {
            changed = remove(data, key) || changed;
          }
          for (const key of ["commonTips", "commonWindows"]) {
            changed = clearList(data, key) || changed;
          }
        } else if (floor.mId === "userinfo") {
          changed = remove(data, "newPlusBlackCard") || changed;
        }
      }
    }
    if (functionId === "getTabHomeInfo" && isObject(payload.result)) {
      changed = remove(payload.result, "iconInfo") || changed;
      changed = remove(payload.result, "roofTop") || changed;
    }
    const monitors = [
      [payload.JDMessage?.socketmonitor, "isSocketEstablishedAhead"],
      [payload.JDMessage?.socketmonitor, "isSocketReport"],
      [payload.JDHttpToolKit?.httpdns, "httpdns"],
    ];
    for (const [object, key] of monitors) {
      if (isObject(object) && Object.prototype.hasOwnProperty.call(object, key)
        && Number(object[key]) !== 0) {
        object[key] = 0;
        changed = true;
      }
    }
    return changed;
  }

  function cleanContainer(object, depth = 0) {
    let changed = cleanPayload(object);
    if (depth >= 2) return changed;
    for (const key of ["data", "result"]) {
      if (isObject(object[key])) {
        changed = cleanContainer(object[key], depth + 1) || changed;
      } else if (typeof object[key] === "string" && object[key].length) {
        try {
          const nested = unpack(object[key]);
          if (nested && cleanContainer(nested.value, depth + 1)) {
            object[key] = nested.pack(nested.value);
            changed = true;
          }
        } catch (_) { /* Non-JSON data fields stay untouched. */ }
      }
    }
    return changed;
  }

  try {
    const decoded = unpack(response.body);
    if (!decoded || !cleanContainer(decoded.value)) return $done({});
    console.log(`JD adblock 2026.11.10.1: ${splashChanged ? "splash" : "promotion/config"} updated`);
    return $done({ body: decoded.pack(decoded.value) });
  } catch (_) {
    return $done({});
  }
})();
