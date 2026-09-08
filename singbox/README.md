# sing-box 规则

`rule/` 中每个同名 `.json` / `.srs` 对应仓库 `Rule/` 中的一份 `.list`。推荐使用体积较小的 `.srs`。规则集格式版本为 2，需要 sing-box 1.10.0 或更新版本；构建固定使用 1.14.0。

例如在 sing-box 的 `route.rule_set` 中添加：

```json
{
  "type": "remote",
  "tag": "Intelligence",
  "format": "binary",
  "url": "https://raw.githubusercontent.com/reukix/ukix/main/singbox/rule/Intelligence.srs",
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
- main 分支的源规则或该 workflow 修改后，直接转换当前 Rule/，避免覆盖手动修改的源文件。
- 可以在 GitHub Actions 中选择 **Update Rules and sing-box → Run workflow** 手动执行完整抓取与转换。
- workflow 使用 Node.js 24，内嵌 JavaScript 转换器和测试；官方 sing-box 编译器固定版本并验证 SHA-256。
- 每次构建刷新 ASN 快照，转换所有 .list 并编译全部 JSON。任何未知规则、无效网段、ASN 查询失败或空规则集都会使构建失败，保留已提交的旧产物。
- 源文件删除后，同名生成文件也会清理。请修改 Rule/，不要直接编辑生成文件。

## 转换方式与差异

- `DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` 与 IPv4/IPv6 CIDR 转为对应字段。列表行之间保持 OR，AND/OR 表达式保留嵌套结构。同类型的独立叶子规则去重合并，不把进程条件和域名条件放进同一个默认规则。
- `IP-ASN` 使用 [RIPEstat RIS Prefixes](https://stat.ripe.net/docs/data-api/api-endpoints/ris-prefixes) 最新可用快照中的 originating IPv4/IPv6 网段展开。`asn.json` 保存来源、查询时间和完整网段，离线转换可重现结果；网段不变时保留原快照时间。BGP 快照与其他客户端的 ASN 数据库可能存在差异。
- 普通 `PROCESS-NAME` 转为 `process_name`，绝对路径转为 `process_path`。以 `.app/` 结尾的目录转为锚定的 `process_path_regex` 前缀匹配。
- 至少三个 Java 标识符组成的包名形式（例如 `com.spotify.music`）转为 `process_name OR package_name`，用于兼容 Android。上述应用目录和包名处理是有意的兼容性扩展；平台是否支持进程/包匹配仍以客户端为准。
- sing-box headless rule set 不支持 `USER-AGENT`，仅跳过顶层该类规则；逻辑组合中出现该规则会报错，避免改变组合条件。
- `no-resolve` 无法写入 headless rule set，转换时移除。是否解析域名需由使用方的 DNS/路由配置控制。
- `conversion-report.json` 记录每份源文件的 SHA-256、规则数、跳过的 User-Agent、进程兼容映射，以及移除的 `no-resolve` 数量。

格式依据：[sing-box Source Format](https://sing-box.sagernet.org/configuration/rule-set/source-format/) 与 [Headless Rule](https://sing-box.sagernet.org/configuration/rule-set/headless-rule/)。
