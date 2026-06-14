const productName = "Subscription";
const productType = "com.niko.PocketWidgetsApp.lifetime";
const appVersion = null;

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

if (typeof $response === "undefined") {
    const headers = $request.headers || {};
    deleteHeader(headers, "if-none-match");
    deleteHeader(headers, "x-revenuecat-etag");
    deleteHeader(headers, "x-rc-last-refresh-time");
    $done({ headers });
} else {
    const url = $request && $request.url ? $request.url : "";

    if (/\/offerings(?:[/?#]|$)/.test(url) || !$response.body) {
        $done({});
    } else {
        let obj;

        try {
            obj = JSON.parse($response.body);
        } catch {
            $done({});
        }

        const purchaseDate = rcDateFromRequestTime($response.headers);

        obj.subscriber = {
            non_subscriptions: {},
            first_seen: purchaseDate,
            original_application_version: appVersion,
            other_purchases: {
                [productType]: {
                    price: { amount: 0, currency: "USD" },
                    display_name: null,
                    purchase_date: purchaseDate
                }
            },
            management_url: null,
            subscriptions: {},
            entitlements: {},
            original_purchase_date: purchaseDate,
            original_app_user_id: "$RCAnonymousID:0400000000000000000000000000000",
            last_seen: purchaseDate
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

        $done({ body: JSON.stringify(obj) });
    }
}
