(() => {
  try {
    if (Number($response.status || $response.statusCode) !== 200 || typeof $response.body !== "string" || !$response.body) return $done({});
    const route = /^https:\/\/(guide-acs\.m\.taobao\.com|poplayer\.template\.alibaba\.com)(?::443)?(\/[^?#]*)(?:[?#]|$)/i.exec($request.url || "");
    if (!route) return $done({});
    const path = route[2].toLowerCase();
    const video = route[1].toLowerCase() === "guide-acs.m.taobao.com" && /^\/gw\/mtop\.taobao\.cloudvideo\.video\.query(?:\/|$)/.test(path);
    const splash = route[1].toLowerCase() === "guide-acs.m.taobao.com" && /^\/gw\/mtop\.taobao\.wireless\.home\.splash\.awesome\.get(?:\/|$)/.test(path);
    const activity = route[1].toLowerCase() === "poplayer.template.alibaba.com" && /^\/[\w-]+\.json$/.test(path);
    if (!video && !splash && !activity) return $done({});
    const obj = JSON.parse($response.body);
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) return $done({});
    const before = JSON.stringify(obj);
    function set(object, name, value, create = false) {
      if (!object || typeof object !== "object" || Array.isArray(object)) return;
      if (!Object.prototype.hasOwnProperty.call(object, name) || object[name] === null) {
        if (create) object[name] = String(value);
        return;
      }
      const type = typeof object[name];
      if (type === "string") object[name] = String(value);
      else if (type === "number") object[name] = Number(value);
      else if (type === "boolean") object[name] = Boolean(value);
    }
    function clear(object, name) { if (Array.isArray(object?.[name])) object[name] = []; }
    if (video) {
      set(obj.data, "duration", 0); clear(obj.data, "resources"); clear(obj.data, "caches");
      set(obj.data, "respTimeInMs", 3818332800000);
    } else if (splash) {
      const sections = obj.data?.containers?.splash_home_base?.base?.sections;
      if (Array.isArray(sections)) for (const section of sections) {
        const ads = section?.bizData?.["taobao-splash"]?.data;
        if (!Array.isArray(ads)) continue;
        for (const ad of ads) {
          if (!ad || typeof ad !== "object" || Array.isArray(ad)) continue;
          for (const name of ["waitTime", "times"]) set(ad, name, 0, true);
          for (const name of ["hotStart", "haveVoice", "hideTBLogo", "enable4G", "coldStart"]) set(ad, name, false, true);
          for (const name of ["imgUrl", "videoUrl"]) set(ad, name, "");
          for (const name of ["startTime", "gmtStartMs"]) set(ad, name, 3818332800000, true);
          for (const name of ["endTime", "gmtEndMs"]) set(ad, name, 3818419199000, true);
          set(ad, "gmtStart", "2090-12-31 00:00:00", true); set(ad, "gmtEnd", "2090-12-31 23:59:59", true);
        }
      }
    } else {
      clear(obj.res, "images"); clear(obj.res, "videos"); clear(obj.mainRes, "images"); set(obj, "enable", false);
    }
    const body = JSON.stringify(obj);
    $done(body === before ? {} : { body });
  } catch (_) { $done({}); }
})();
