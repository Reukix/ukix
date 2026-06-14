let names = "Koco Widgets";
let productName = "Subscription";
let productType = "com.niko.PocketWidgetsApp.lifetime";
let appVersion = null;
let notifyState = true;
let ua = true;

let obj = JSON.parse($response.body);
let $ = new Env(names);

obj.subscriber = {
    non_subscriptions: {},
    first_seen: "2026-06-14T10:52:05Z",
    original_application_version: appVersion,
    other_purchases: {
        [productType]: {
            price: { amount: 0, currency: "USD" },
            display_name: null,
            purchase_date: "2026-06-14T10:52:05Z"
        }
    },
    management_url: null,
    subscriptions: {},
    entitlements: {},
    original_purchase_date: "2026-06-14T10:52:05Z",
    original_app_user_id: "$RCAnonymousID:0400000000000000000000000000000",
    last_seen: "2026-06-14T10:52:05Z"
};

obj.subscriber.non_subscriptions[productType] = [{
    id: "aaaaaaaaaa",
    is_sandbox: false,
    price: { amount: 0, currency: "USD" },
    display_name: null,
    purchase_date: "2026-06-14T10:52:05Z",
    original_purchase_date: "2026-06-14T10:52:05Z",
    store: "app_store",
    store_transaction_id: "280000000000000"
}];

obj.subscriber.entitlements[productName] = {
    grace_period_expires_date: null,
    purchase_date: "2026-06-14T10:52:05Z",
    product_identifier: productType,
    expires_date: null
};

$done({ body: JSON.stringify(obj) });
