/**
 * Telegram 链接重定向至第三方/官方客户端
 */

// 1. 获取模块中传入的 argument 参数，未设置时默认使用官方的 "tg"
const app = (typeof $argument !== "undefined" && $argument) ? $argument.trim() : "tg";
const url = $request.url;

// 2. 正则匹配规则
// 匹配公开频道、群组、用户名：t.me/username
const publicPattern = /^https?:\/\/t\.me\/([A-Za-z][A-Za-z0-9_]{3,30}[A-Za-z0-9])\/?$/;
// 匹配私有群组/频道邀请短链：t.me/+inviteCode 或 t.me/joinchat/inviteCode
const privatePattern = /^https?:\/\/t\.me\/(?:\+|joinchat\/)([A-Za-z0-9_-]+)\/?$/;

let targetUrl = null;

// 3. 解析与拼接目标 Scheme
const publicMatch = url.match(publicPattern);
const privateMatch = url.match(privatePattern);

if (publicMatch) {
    const domain = publicMatch[1];
    targetUrl = `${app}://resolve?domain=${domain}`;
} else if (privateMatch) {
    const invite = privateMatch[1];
    targetUrl = `${app}://join?invite=${invite}`;
}

// 4. 返回 302 重定向响应
if (targetUrl) {
    $done({
        response: {
            status: 302,
            headers: {
                "Location": targetUrl
            }
        }
    });
} else {
    // 不符合条件的 URL 直接放行
    $done({});
}
