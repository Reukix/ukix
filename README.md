# Reukix

这是 [Reukix](https://github.com/Reukix) 自用的网络规则、代理配置和服务器脚本仓库。

仓库内容以 Surge、Loon、规则列表、脚本模块和自用部署脚本为主。配置会按个人使用习惯调整，不保证适合所有环境，使用前建议先看一遍规则和脚本内容。

## 内容

```text
.
├── Rule/          # 分流规则、域名/IP/服务列表
├── Script/        # Surge 模块
├── js/            # 脚本文件
├── Surge.conf     # Surge 配置
├── loon.lcf       # Loon 配置
├── snell.sh       # Snell v5/v6 交互式部署脚本
└── ss2022.sh      # Shadowsocks 2022 交互式部署脚本
```

## 规则与配置

`Rule/` 里是自用分流规则，包含 Apple、Google、Telegram、Spotify、TikTok、GitHub、PayPal、OKX、Binance、Bybit、MTeam、Speedtest、广告过滤等常见服务规则。

`Surge.conf` 和 `loon.lcf` 是自用客户端配置。直接使用前请按自己的节点、DNS、策略组和本地网络环境修改。

`Script/` 和 `js/` 里放的是 Surge 模块和配套脚本，例如 Spotify、URL Redirect、kocowidgets 等。

## SS2022 脚本

`ss2022.sh` 是基于 `shadowsocks-rust` 的 Shadowsocks 2022 交互式管理脚本，支持安装、重装、更新、修改配置、查看连接信息、查看日志和卸载。

```bash
sudo bash ss2022.sh
```

也可以直接进入安装向导：

```bash
sudo bash ss2022.sh install
```

查看配置和客户端链接：

```bash
sudo bash ss2022.sh show
```

常用命令：

```bash
sudo bash ss2022.sh start
sudo bash ss2022.sh stop
sudo bash ss2022.sh restart
sudo bash ss2022.sh status
sudo bash ss2022.sh log
sudo bash ss2022.sh uninstall
```

说明：

- 默认使用 `2022-blake3-aes-256-gcm`
- 密钥会按 SS2022 要求生成或校验为合法 base64 key
- 服务使用 systemd 管理
- 适用于 Linux VPS，需要 root 权限

## Snell 脚本

`snell.sh` 是 Snell v5/v6 交互式部署脚本，支持自动检测系统架构、安装依赖、下载服务端、生成配置、创建 systemd 服务，并带有基础管理和多用户管理菜单。

```bash
sudo bash snell.sh
```

直接安装：

```bash
sudo bash snell.sh install
```

常用命令：

```bash
sudo bash snell.sh status
sudo bash snell.sh log
sudo bash snell.sh config
sudo bash snell.sh info
sudo bash snell.sh uninstall
```

## 注意

- 本仓库主要服务个人使用场景，规则和脚本可能随时调整。
- 服务器部署脚本默认面向 Linux + systemd 环境。
- 使用代理、分流和解锁相关配置时，请遵守所在地法律法规和服务条款。

## License

MIT License. See [LICENSE](LICENSE).
