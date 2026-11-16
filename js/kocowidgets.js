(() => {
  try {
    const productName = "Subscription";
    const productType = "com.niko.PocketWidgetsApp.lifetime";
    const appVersion = null;
    const bundleId = productType.slice(0, productType.lastIndexOf("."));

    function headerValue(headers, name) {
        if (!headers) return null;
        const key = Object.keys(headers).find(item => item.toLowerCase() === name.toLowerCase());
        return key ? headers[key] : null;
    }

    function deleteHeader(headers, name) {
        if (!headers) return;
        const key = Object.keys(headers).find(item => item.toLowerCase() === name.toLowerCase());
        if (key) delete headers[key];
    }

    function rcDateFromRequestTime(headers) {
        const requestTime = headerValue(headers, "x-revenuecat-request-time");
        const timestamp = requestTime ? Number(requestTime) : Date.now();
        const date = Number.isFinite(timestamp) ? new Date(timestamp) : new Date();
        return date.toISOString().replace(/\.\d{3}Z$/, "Z");
    }

    // RevenueCat serves many apps; require positive identity for the target app.
    if (headerValue($request.headers, "x-client-bundle-id") !== bundleId
        || !/^https:\/\/api\.(?:revenuecat|rc-backup)\.com(?::443)?\/v1\/(?:subscribers\/[^/?#]+\/?|receipts\/?)(?:[?#]|$)/i.test($request.url || "")) return $done({});

    if (typeof $response === "undefined") {
        const headers = $request.headers || {};
        deleteHeader(headers, "if-none-match");
        deleteHeader(headers, "x-revenuecat-etag");
        deleteHeader(headers, "x-rc-last-refresh-time");
        return $done({ headers });
    } else {
        const url = $request && $request.url ? $request.url : "";

        if (Number($response.status || $response.statusCode) !== 200 || /\/offerings(?:[/?#]|$)/.test(url) || typeof $response.body !== "string" || !$response.body) {
            return $done({});
        } else {
            let obj;

            try {
                obj = JSON.parse($response.body);
            } catch {
                return $done({});
            }
            if (!obj || typeof obj !== "object" || !obj.subscriber || typeof obj.subscriber !== "object" || Array.isArray(obj.subscriber)) return $done({});

            const purchaseDate = rcDateFromRequestTime($response.headers);

            const original = obj.subscriber;
            obj.subscriber = {
                ...original,
                non_subscriptions: { ...(original.non_subscriptions || {}) },
                first_seen: original.first_seen || purchaseDate,
                original_application_version: original.original_application_version ?? appVersion,
                other_purchases: {
                    ...(original.other_purchases || {}),
                    [productType]: {
                        price: { amount: 0, currency: "USD" },
                        display_name: null,
                        purchase_date: purchaseDate
                    }
                },
                entitlements: { ...(original.entitlements || {}) },
                original_purchase_date: original.original_purchase_date || purchaseDate
            };

            obj.subscriber.non_subscriptions[productType] = [{
                id: "aaaaaaaaaa",
                is_sandbox: false,
                price: { amount: 0, currency: "USD" },
                display_name: null,
                purchase_date: purchaseDate,
                original_purchase_date: purchaseDate,
                store: "app_store",
                store_transaction_id: "280000000000000"
            }];

            obj.subscriber.entitlements[productName] = {
                grace_period_expires_date: null,
                purchase_date: purchaseDate,
                product_identifier: productType,
                expires_date: null
            };

            return $done({ body: JSON.stringify(obj) });
        }
    }
  } catch (_) { return $done({}); }
})();
