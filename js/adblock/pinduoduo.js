// Clean the pickup page without replacing its versioned application bundles.
(() => {
  try {
    const url = $request.url || "", original = $response.body;
    if (Number($response.status || $response.statusCode) !== 200 || typeof original !== "string"
      || !/^https:\/\/m\.pinduoduo\.net(?::443)?\/mdkd\/package\/?(?:\?|$)/i.test(url)
      || !/[?&]from_app_scan(?:=[^&#]*|)(?:&|#|$)/i.test(url)) return $done({});
    const promotionClass = /(?:^|\s)index_(?:gif-container|goods-list-big-container)(?:__[^\s]*)?(?=\s|$)/;
    let body = original, recognized = false;
    body = body.replace(/(<script\b(?=[^>]*\bid\s*=\s*["']__NEXT_DATA__["'])[^>]*>)([\s\S]*?)(<\/script\s*>)/i, (all, open, raw, close) => {
      try {
        const data = JSON.parse(raw), serverData = data?.props?.pageProps?.serverData;
        if (!Array.isArray(serverData)) return all;
        recognized = true;
        data.props.pageProps.serverData = serverData.filter(item => {
          if (typeof item?.key !== "string") return true;
          const parts = item.key.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/);
          return !parts.some(p => ["ad", "ads", "advert", "advertisement", "advertising", "promotion", "marketing", "splash"].includes(p))
            && !(parts.some(p => ["goods", "product"].includes(p)) && parts.some(p => ["recommend", "recommendation", "recommendations"].includes(p)));
        });
        return open + JSON.stringify(data).replace(/</g, "\\u003c") + close;
      } catch (_) { return all; }
    });
    // Scripts and comments are opaque tokens, not real page elements.
    const tags = /<script\b[^>]*>[\s\S]*?<\/script\s*>|<!--[\s\S]*?-->|<\/?div\b[^>]*>/gi;
    const ranges = []; let start = -1, depth = 0, match;
    while ((match = tags.exec(body))) {
      const tag = match[0];
      if (!/^<\/?div\b/i.test(tag)) continue;
      const closing = /^<\/div\b/i.test(tag);
      if (start < 0 && !closing) {
        const classes = /\bclass\s*=\s*(["'])(.*?)\1/i.exec(tag)?.[2] || "";
        if (promotionClass.test(classes)) { recognized = true; start = match.index; depth = 1; }
      } else if (start >= 0) {
        depth += closing ? -1 : 1;
        if (!depth) { ranges.push([start, tags.lastIndex]); start = -1; }
      }
    }
    for (const [from, to] of ranges.reverse()) body = body.slice(0, from) + body.slice(to);
    // Prefix selectors survive CSS-module hash changes and cover hydration.
    // Reuse an existing nonce where available; keep the site's CSP unchanged.
    if ((recognized || /<(?:html|head|body)\b/i.test(body)) && !/\bid=["']ukix-pickup-adblock["']/i.test(body)) {
      const nonce = /<style\b[^>]*\bnonce=["']([A-Za-z0-9+/_=-]{1,256})["']/i.exec(body)?.[1]
        || /<script\b[^>]*\bnonce=["']([A-Za-z0-9+/_=-]{1,256})["']/i.exec(body)?.[1];
      const selectors = ["index_gif-container", "index_goods-list-big-container"].flatMap(name => ['[class~="' + name + '"]', '[class^="' + name + '__"]', '[class*=" ' + name + '__"]']).join(",");
      const style = '<style id="ukix-pickup-adblock"' + (nonce ? ' nonce="' + nonce + '"' : "") + '>' + selectors + '{display:none!important}</style>';
      body = /<\/head\s*>/i.test(body) ? body.replace(/<\/head\s*>/i, style + "$&") : style + body;
    }
    $done(body === original ? {} : { body });
  } catch (_) { $done({}); }
})();
