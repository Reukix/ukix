# sing-box 规则

`rule/` 中每个同名 `.json` / `.srs` 对应仓库 `Rule/` 中的一份 `.list`。推荐使用体积较小的 `.srs`。规则集格式版本为 2，需要 sing-box 1.10.0 或更新版本；构建固定使用 1.14.0。

例如在 sing-box 的 `route.rule_set` 中添加：

```json
{
  "type": "remote",
  "tag": "Intelligence",
  "format": "binary",
  "url": "https://raw.githubusercontent.com/Reukix/ukix/main/singbox/rule/Intelligence.srs",
  "update_interval": "1d"
}
```

然后在 `route.rules` 中引用（`proxy` 替换成自己的出站标签）：

```json
{
  "rule_set": ["Intelligence"],
  "action": "route",
  "outbound": "proxy"
}
```

此引用示例使用 sing-box 1.11+ 的 action 写法。如果使用 JSON，将 URL 后缀改为 `.json`，并将 `format` 改为 `source`。其他规则只需替换文件名和标签，注意大小写。

## 自动更新

所有抓取、转换、测试、编译和提交逻辑都在一个文件中：[.github/workflows/Workspace_specific_rules.yml](../.github/workflows/Workspace_specific_rules.yml)。无需独立脚本、composite action、Python 或 npm 依赖。

- 每日 UTC 19:00（北京时间 / 新加坡时间次日 03:00）调度，先抓取更新 Rule/，再生成 sing-box 规则，一起提交。
- 从 MagicRule 的 Surge 目录及 manifest 动态查找完整规则，校验规则总数和各类型数量；Apple 和广告规则沿用独立来源。
- CN 合并 Loyalsoldier 的完整直连域名库及 MagicRule 的 China / ChinaIPs / Baidu / DouYin / MeiTuan / WeChat，覆盖 DeepSeek、豆包、Kimi、通义、智谱、元宝等国内 AI。完整域名库少于 10,000 条或出现无效类型时停止更新，避免意外缩减覆盖。
- Intelligence 逐个抓取 OpenAI、Gemini、Anthropic、Copilot、Grok、Groq、Perplexity、Cursor、Windsurf、JetBrainsAI、HuggingFace、Poe、ByteDanceAI 的独立规则源，并合并到同一份列表。Copilot 上游分类混入了其他 AI，因此仅保留其自身的服务域名。Muse、Meta AI、Manus、Mistral、Midjourney、Suno、Apple Intelligence 和 Dia 按服务单独补充域名。
- 路由先匹配 Intelligence 等专用策略，随后匹配 CN 直连和通用 Proxy。国内 AI 由 CN 处理，无需额外的优先直连列表；仓库的 Surge / Loon 配置已采用此顺序。
- Proxy 合并 MagicRule 的 Global 和 Cloudflare 完整规则，包含 Cloudflare 服务域名及公共 CDN 的 IPv4/IPv6 网段，沿用现有 Proxy 策略。
- 使用 `RULE_UPDATE_TOKEN` 以 Reukix 账号提交和推送，提交标记 `[skip ci]` 防止重复构建。
- main 分支的源规则或该 workflow 修改后，直接转换当前 Rule/，避免覆盖手动修改的源文件。
- 可以在 GitHub Actions 中选择 **Update Rules and sing-box → Run workflow** 手动执行完整抓取与转换。
- workflow 使用 Node.js 24，内嵌 JavaScript 转换器和测试；官方 sing-box 编译器固定版本并验证 SHA-256。
- 每次构建尝试刷新 ASN 快照，转换所有 .list 并编译全部 JSON。单个 ASN 查询连续尝试 3 次仍失败时，沿用该 ASN 已保存的有效网段和原查询时间，记录警告并继续更新其他规则；没有有效旧快照时仍会失败，避免遗漏 IP 分流。任何未知规则、无效网段或空规则集也会使构建失败，保留已提交的旧产物。
- 源文件删除后，同名生成文件也会清理。请修改 Rule/，不要直接编辑生成文件。

## 转换方式与差异

- `DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` 与 IPv4/IPv6 CIDR 转为对应字段。列表行之间保持 OR，AND/OR 表达式保留嵌套结构。同类型的独立叶子规则去重合并，不把进程条件和域名条件放进同一个默认规则。
- `DOMAIN-WILDCARD` 转为忽略大小写、首尾锚定的 `domain_regex`，支持 `*`（任意数量字符，可跨点）和 `?`（单个字符）。没有通配符时仅匹配完整域名；字符类和转义暂不支持，遇到时会报错。
- `IP-ASN` 使用 [RIPEstat RIS Prefixes](https://stat.ripe.net/docs/data-api/api-endpoints/ris-prefixes) 最新可用快照中的 originating IPv4/IPv6 网段展开。`asn.json` 保存来源、查询时间和完整网段，离线转换可重现结果；网段不变时保留原快照时间。BGP 快照与其他客户端的 ASN 数据库可能存在差异。
- 普通 `PROCESS-NAME` 转为 `process_name`，绝对路径转为 `process_path`。以 `.app/` 结尾的目录转为锚定的 `process_path_regex` 前缀匹配。
- 至少三个 Java 标识符组成的包名形式（例如 `com.spotify.music`）转为 `process_name OR package_name`，用于兼容 Android。上述应用目录和包名处理是有意的兼容性扩展；平台是否支持进程/包匹配仍以客户端为准。
- sing-box headless rule set 不支持 `USER-AGENT`，仅跳过顶层该类规则；逻辑组合中出现该规则会报错，避免改变组合条件。
- `no-resolve` 无法写入 headless rule set，转换时移除。是否解析域名需由使用方的 DNS/路由配置控制。
- MagicRule 的 China 列表包含 `GEOIP,CN`。导入时移除这一行，并合并 ChinaIPs 中的 IPv4/IPv6 网段供两种客户端使用；ChinaIPs 中的数千条 ASN 不导入，避免逐一查询展开。Surge 配置另有独立的 `GEOIP,CN,DIRECT`。
- `conversion-report.json` 记录每份源文件的 SHA-256、规则数、跳过的 User-Agent、进程兼容映射，以及移除的 `no-resolve` 数量。

格式依据：[sing-box Source Format](https://sing-box.sagernet.org/configuration/rule-set/source-format/) 与 [Headless Rule](https://sing-box.sagernet.org/configuration/rule-set/headless-rule/)。
