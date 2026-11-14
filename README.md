# Reukix

这是 [Reukix](https://github.com/Reukix) 自用的网络规则、代理配置和服务器脚本仓库。

仓库内容以 Surge、Loon、规则列表、脚本模块和自用部署脚本为主。配置会按个人使用习惯调整，不保证适合所有环境，使用前建议先看一遍规则和脚本内容。

## 内容

```text
.
├── Rule/          # 分流规则、域名/IP/服务列表
├── singbox/       # 自动转换的 sing-box 规则（rule/*.json、*.srs）
├── Script/        # Surge 模块
├── js/            # 脚本文件
├── Surge.conf     # Surge 配置
├── loon.lcf       # Loon 配置
├── snell.sh       # Snell v5/v6 交互式部署脚本
└── ss2022.sh      # Shadowsocks 2022 交互式部署脚本
```

## 规则与配置

`Rule/` 里是自用分流规则，包含 Apple、Google、Telegram、Spotify、TikTok、GitHub、PayPal、OKX、Binance、Bybit、MTeam、Speedtest、广告过滤等常见服务规则。

`singbox/rule/` 提供由 GitHub Actions 自动转换的 sing-box JSON / SRS 规则集。使用方式和转换差异见 [sing-box 说明](singbox/README.md)。

`Surge.conf` 和 `loon.lcf` 是自用客户端配置。直接使用前请按自己的节点、DNS、策略组和本地网络环境修改。

`Script/` 和 `js/` 里放的是 Surge 模块和配套脚本，例如 Spotify、URL Redirect、kocowidgets 等。

`Script/Spotify.sgmodule` 已集成独立歌词脚本，默认保留官方歌词，缺失时按歌名、歌手和时长查找网易云／LRCLIB，并支持逐字歌词与双语翻译。参数 `Lyrics` 控制歌词功能，`Translate` 控制翻译，`TargetLanguage` 默认为 `zh-CN`。使用时请停用其他 Spotify 歌词模块，避免同一接口被优先拦截。

歌词接口返回成功不代表客户端一定显示卡片；部分曲目的入口仍可能受 Spotify 本地元数据影响，需要以手机界面结果为准。

## Snell 脚本

`snell.sh` 是 Snell v5/v6 交互式部署脚本，支持自动检测系统架构、安装依赖、下载服务端、生成配置、创建 systemd 服务，并带有基础管理和多用户管理菜单。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Reukix/ukix/refs/heads/main/snell.sh)
```


## SS2022 脚本

`ss2022.sh` 是基于 `shadowsocks-rust` 的 Shadowsocks 2022 交互式管理脚本，支持安装、重装、更新、修改配置、查看连接信息、查看日志和卸载。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Reukix/ukix/refs/heads/main/ss2022.sh)
```

说明：

- 默认使用 `2022-blake3-aes-256-gcm`
- 密钥会按 SS2022 要求生成或校验为合法 base64 key
- 服务使用 systemd 管理
- 适用于 Linux VPS，需要 root 权限


## 注意

- 本仓库主要服务个人使用场景，规则和脚本可能随时调整。
- 服务器部署脚本默认面向 Linux + systemd 环境。
- 使用代理、分流和解锁相关配置时，请遵守所在地法律法规和服务条款。

## 致谢

感谢以下项目的作者和贡献者提供的规则、插件、数据与工具：

- [MagicRule](https://magicrule.pages.dev/#/c/Surge)：当前主要分流规则来源，提供各服务的 Surge 规则。
- [Loyalsoldier/surge-rules](https://github.com/Loyalsoldier/surge-rules)：完整直连域名列表，用于补充 CN 规则。
- [blackmatrix7/ios_rule_script](https://github.com/blackmatrix7/ios_rule_script)：早期分流规则来源与参考。
- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)：广告过滤规则。
- [Blankwonder/surge-list](https://github.com/Blankwonder/surge-list)：Apple 分流规则。
- [fmz200/wool_scripts](https://github.com/fmz200/wool_scripts)：Loon 去广告与 HTTPDNS 拦截插件。
- [SagerNet/sing-box](https://github.com/SagerNet/sing-box)：sing-box 规则集编译工具与格式文档。
- [RIPE NCC / RIPEstat](https://stat.ripe.net/docs/data-api/api-endpoints/ris-prefixes)：ASN 对应的 IPv4/IPv6 网段数据。
- [Surge / Snell](https://kb.nssurge.com/surge-knowledge-base/release-notes/snell)：Snell 服务端与官方使用文档。
- [shadowsocks/shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust)：Shadowsocks 2022 服务端。

也感谢上述项目的上游数据提供者和社区贡献者。

## License

MIT License. See [LICENSE](LICENSE).
