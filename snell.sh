#!/usr/bin/env bash
#
# OpenSnell 服务器安装脚本 (汉化版)
#
# 子命令:
#   install        交互式安装 (默认操作)
#   reconfigure    交互式重新配置并重启服务
#   update         就地更新二进制文件
#   uninstall      停止服务 + 删除二进制文件 + (可选) 删除配置文件
#   start | stop | restart | enable | disable | status
#   info           显示当前已安装服务器的连接/节点信息
#   help           显示帮助信息
#
# 不带任何参数运行时，将显示交互式菜单。
#
# 两种安装变体:
#   1) OpenSnell (默认, GPLv3 协议, 跨平台, 开源版本)
#   2) Surge 官方 snell-server v5.0.1 (闭源, 仅限 Linux)
#
# 原项目地址: https://github.com/missuo/opensnell
# SPDX-License-Identifier: GPL-3.0-or-later

set -uo pipefail

# ============================================================================
# 终端高亮配色
# ============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

print_header()  { echo; echo -e "${BOLD}${BLUE}===========================================================${NC}"; echo -e "${BOLD}${BLUE}  $1${NC}"; echo -e "${BOLD}${BLUE}===========================================================${NC}"; echo; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_error()   { echo -e "${RED}[错误]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_info()    { echo -e "${CYAN}[信息]${NC} $1"; }

# ============================================================================
# 路径定义
# ============================================================================
INSTALL_BIN="/usr/local/bin/snell-server"
CONFIG_DIR="/etc/snell"
CONFIG_FILE="$CONFIG_DIR/snell-server.conf"
META_FILE="$CONFIG_DIR/.install_meta"
SERVICE_NAME="snell-server"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

OPENSNELL_REPO="missuo/opensnell"
# CHANNEL (通道) = stable (稳定版) | alpha (测试版)
CHANNEL="stable"
OPENSNELL_RELEASE_API_STABLE="https://api.github.com/repos/${OPENSNELL_REPO}/releases/latest"
OPENSNELL_RELEASE_API_ALPHA="https://api.github.com/repos/${OPENSNELL_REPO}/releases/tags/alpha"
SURGE_VERSION="v5.0.1"
SURGE_BASE_URL="https://dl.nssurge.com/snell"

opensnell_release_api() {
    case "$CHANNEL" in
        alpha) echo "$OPENSNELL_RELEASE_API_ALPHA" ;;
        *)     echo "$OPENSNELL_RELEASE_API_STABLE" ;;
    esac
}

# ============================================================================
# 环境预检 (Preflight)
# ============================================================================
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "此脚本必须以 root 权限运行 (请尝试 sudo bash install.sh ...)。"
        exit 1
    fi
}

check_linux() {
    if [ "$(uname -s)" != "Linux" ]; then
        print_error "此安装脚本仅支持 Linux 系统。"
        print_info  "检测到的操作系统：$(uname -s) — 不支持。"
        print_info  "在 macOS / Windows / *BSD 上，请选择源码编译安装："
        print_info  "    go install github.com/missuo/opensnell/cmd/snell-server@latest"
        print_info  "并使用您平台的原生工具 (launchd, NSSM, rc.d 等) 进行配置和守护运行。"
        print_info  "OpenSnell 服务端本身是跨平台的，仅当前一键脚本限 Linux 使用。"
        exit 1
    fi
}

detect_arch_opensnell() {
    case "$(uname -m)" in
        x86_64)         echo "amd64"  ;;
        aarch64|arm64)  echo "arm64"  ;;
        i386|i686)      echo "386"    ;;
        armv7l|armv7)   echo "armv7"  ;;
        *) print_error "不支持的架构: $(uname -m)"; exit 1 ;;
    esac
}

detect_arch_surge() {
    case "$(uname -m)" in
        x86_64)         echo "amd64"   ;;
        aarch64|arm64)  echo "aarch64" ;;
        i386|i686)      echo "i386"    ;;
        armv7l|armv7)   echo "armv7l"  ;;
        *) print_error "Surge 官方二进制文件不支持此架构: $(uname -m)。"; exit 1 ;;
    esac
}

ensure_tools() {
    local missing=()
    for t in curl unzip openssl ss; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        print_info "正在安装缺失的工具包: ${missing[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y "${missing[@]}" || {
                print_error "安装失败: ${missing[*]}"; exit 1; }
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y "${missing[@]}" || { print_error "安装失败"; exit 1; }
        elif command -v yum >/dev/null 2>&1; then
            yum install -y "${missing[@]}" || { print_error "安装失败"; exit 1; }
        else
            print_error "不支持的包管理器。请手动安装: ${missing[*]}"
            exit 1
        fi
    fi
}

# ============================================================================
# 辅助函数 (Helpers)
# ============================================================================
gen_psk() { openssl rand -base64 18 | tr -d '/+=' | cut -c1-24; }

base64_encode() {
    if command -v base64 >/dev/null 2>&1; then
        printf '%s' "$1" | base64 | tr -d '\n'
    else
        printf '%s' "$1" | openssl base64 -A
    fi
}

url_encode() {
    local byte dec ch byte_upper out=""
    for byte in $(printf '%s' "$1" | od -An -tx1 -v); do
        dec=$((16#$byte))
        if { [ "$dec" -ge 48 ] && [ "$dec" -le 57 ]; } \
            || { [ "$dec" -ge 65 ] && [ "$dec" -le 90 ]; } \
            || { [ "$dec" -ge 97 ] && [ "$dec" -le 122 ]; } \
            || [ "$dec" -eq 45 ] || [ "$dec" -eq 46 ] \
            || [ "$dec" -eq 95 ] || [ "$dec" -eq 126 ]; then
            printf -v ch '%b' "\\x${byte}"
            out+="$ch"
        else
            printf -v byte_upper '%02X' "$dec"
            out+="%${byte_upper}"
        fi
    done
    printf '%s' "$out"
}

yaml_double_quote_escape() {
    local value="${1//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

# 随机挑选一个 10000 到 60000 之间未被占用的端口
pick_free_port() {
    local p
    for _ in $(seq 1 50); do
        p=$(( RANDOM % 50000 + 10000 ))
        if ! ss -lnt -lnu 2>/dev/null | awk '{print $5}' | grep -qE "[:.]$p\$"; then
            echo "$p"; return 0
        fi
    done
    print_error "尝试 50 次后仍未找到可用的空闲端口"
    return 1
}

get_ipv4() {
    curl -s -4 --max-time 5 ifconfig.me 2>/dev/null \
        || curl -s -4 --max-time 5 ip.sb 2>/dev/null \
        || curl -s -4 --max-time 5 ipinfo.io/ip 2>/dev/null \
        || echo "您的服务器_IP"
}

# 将两位字母的国家代码转为对应的 Emoji 国旗
cc_to_flag() {
    local cc
    cc=$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')
    [ "${#cc}" = 2 ] || return 0
    case "$cc" in *[!A-Z]*) return 0 ;; esac
    local a_ord b_ord hex_a hex_b
    a_ord=$(printf '%d' "'${cc:0:1}")
    b_ord=$(printf '%d' "'${cc:1:1}")
    hex_a=$(printf '%08x' $(( 0x1F1E6 + a_ord - 65 )))
    hex_b=$(printf '%08x' $(( 0x1F1E6 + b_ord - 65 )))
    printf "\\U${hex_a}\\U${hex_b}"
}

# 获取服务器 IP 及所在国家信息
fetch_geo() {
    GEO_IP=""
    GEO_COUNTRY=""
    GEO_IP=$(curl -s -4 --max-time 5 https://ip.sb 2>/dev/null | tr -d '[:space:]')
    case "$GEO_IP" in
        *[!0-9.]*|"") GEO_IP="" ;;
    esac
    [ -z "$GEO_IP" ] && return 0
    local json
    json=$(curl -s -4 --max-time 5 "https://api.ipinfo.es/ipinfo?ip=${GEO_IP}" 2>/dev/null || true)
    GEO_COUNTRY=$(echo "$json" | grep -o '"country":"[^"]*"' | head -1 | cut -d'"' -f4)
    case "$GEO_COUNTRY" in *[!A-Za-z]*) GEO_COUNTRY="" ;; esac
}

# 自动生成代理节点名称（例如: 🇯🇵 JP A1B2）
generate_node_name() {
    local flag suffix
    flag=$(cc_to_flag "${GEO_COUNTRY:-}")
    suffix=$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom 2>/dev/null | head -c 4)
    [ -z "$suffix" ] && suffix=$(date +%s | tail -c 5)
    if [ -n "$flag" ] && [ -n "${GEO_COUNTRY:-}" ]; then
        printf '%s %s %s' "$flag" "$GEO_COUNTRY" "$suffix"
    elif [ -n "${GEO_COUNTRY:-}" ]; then
        printf '%s %s' "$GEO_COUNTRY" "$suffix"
    else
        printf 'OpenSnell %s' "$suffix"
    fi
}

# 启用内核 TFO (TCP Fast Open) 支持
enable_tfo_sysctl() {
    local current
    current=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "")

    if [ "$current" = "3" ]; then
        print_info "系统内核 net.ipv4.tcp_fastopen=3 已经就绪，无需修改"
        return 0
    fi

    print_warning "当前内核 net.ipv4.tcp_fastopen=${current:-未知} (TFO 功能需要值为 3)"
    local confirm
    confirm=$(prompt_yesno "是否将其设置为 3？ (将写入 /etc/sysctl.conf 并通过 sysctl -p 生效)" "y")
    if [ "$confirm" != "y" ]; then
        print_warning "已跳过设置；OpenSnell 会配置 Socket，但由于系统未开启，TFO 实际上不会生效"
        return 0
    fi

    local sysctl_conf="/etc/sysctl.conf"
    local setting="net.ipv4.tcp_fastopen = 3"
    if [ -f "$sysctl_conf" ] && grep -qE '^[[:space:]]*net\.ipv4\.tcp_fastopen' "$sysctl_conf"; then
        sed -i "s|^[[:space:]]*net\.ipv4\.tcp_fastopen.*|$setting|" "$sysctl_conf"
        print_success "已更新 $sysctl_conf 中的现有条目"
    else
        echo "$setting" >> "$sysctl_conf"
        print_success "已追加到 $sysctl_conf 尾部"
    fi

    if sysctl -p >/dev/null 2>&1; then
        local after
        after=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo "?")
        if [ "$after" = "3" ]; then
            print_success "系统内核现已汇报 net.ipv4.tcp_fastopen=3"
        else
            print_warning "sysctl -p 运行成功，但内核报告值为 $after (预期为 3)"
        fi
    else
        print_warning "sysctl -p 运行失败；可能需要重启服务器或手动执行以生效"
    fi
}

get_installed_version() {
    [ -f "$META_FILE" ] && grep '^version=' "$META_FILE" | cut -d= -f2 || true
}

get_install_variant() {
    [ -f "$META_FILE" ] && grep '^variant=' "$META_FILE" | cut -d= -f2 || true
}

get_install_channel() {
    [ -f "$META_FILE" ] && grep '^channel=' "$META_FILE" | cut -d= -f2 || true
}

prompt_default() {
    local question="$1" default="$2" reply
    if [ -n "$default" ]; then
        read -r -p "$(echo -e "${CYAN}${question} [默认值: ${BOLD}${default}${NC}${CYAN}]: ${NC}")" reply
    else
        read -r -p "$(echo -e "${CYAN}${question}: ${NC}")" reply
    fi
    echo "${reply:-$default}"
}

prompt_yesno() {
    local question="$1" default="$2" reply
    read -r -p "$(echo -e "${CYAN}${question} (y/n) [默认值: ${BOLD}${default}${NC}${CYAN}]: ${NC}")" reply
    reply="${reply:-$default}"
    case "${reply,,}" in y|yes) echo "y" ;; *) echo "n" ;; esac
}

# ============================================================================
# 下载与安装
# ============================================================================
download_opensnell() {
    print_header "正在下载 OpenSnell 服务端"
    mkdir -p "$CONFIG_DIR"
    local arch tag url api channel_label
    arch=$(detect_arch_opensnell)
    api=$(opensnell_release_api)
    tag=$(curl -fsSL "$api" | grep '"tag_name":' | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
    if [ -z "$tag" ]; then
        if [ "$CHANNEL" = "alpha" ]; then
            print_error "无法通过 GitHub API 解析滚动测试版的 'alpha' 标签。"
            print_info "可能是 Alpha 分支尚未构建完成，请检查："
            print_info "    https://github.com/${OPENSNELL_REPO}/releases/tag/alpha"
        else
            print_error "无法通过 GitHub API 获取最新版本。"
        fi
        print_info "请尝试从源码编译: go install github.com/${OPENSNELL_REPO}/cmd/snell-server@latest"
        exit 1
    fi
    url="https://github.com/${OPENSNELL_REPO}/releases/download/${tag}/snell-server-linux-${arch}"

    if [ "$CHANNEL" = "alpha" ]; then
        channel_label="OpenSnell (Alpha 通道 — 滚动测试版)"
    else
        channel_label="OpenSnell (自托管开源版, GPLv3)"
    fi
    print_info "安装变体: ${channel_label}"
    print_info "系统架构: linux/${arch}"
    print_info "软件版本: ${tag}"
    print_info "下载来源: ${url}"

    local tmp
    tmp=$(mktemp)
    if ! curl -fL --progress-bar -o "$tmp" "$url"; then
        rm -f "$tmp"
        print_error "下载失败。"
        print_info "如果您正在安装第一个 Release 版本，GitHub Actions 可能尚未生成二进制文件。"
        print_info "您也可以通过源码编译: go install github.com/${OPENSNELL_REPO}/cmd/snell-server@latest"
        exit 1
    fi
    install -m 0755 "$tmp" "$INSTALL_BIN"
    rm -f "$tmp"
    print_success "已安装 OpenSnell ${tag} → ${INSTALL_BIN}"

    echo "variant=opensnell" >  "$META_FILE.tmp"
    echo "version=$tag"      >> "$META_FILE.tmp"
    echo "channel=$CHANNEL"  >> "$META_FILE.tmp"
}

download_surge() {
    print_header "正在下载 Surge 官方 snell-server"
    mkdir -p "$CONFIG_DIR"
    local arch url workdir
    arch=$(detect_arch_surge)
    url="${SURGE_BASE_URL}/snell-server-${SURGE_VERSION}-linux-${arch}.zip"

    print_info "安装变体: Surge 官方原版 (闭源, 仅限 Linux)"
    print_info "系统架构: linux/${arch}"
    print_info "软件版本: ${SURGE_VERSION}"
    print_info "下载来源: ${url}"
    print_warning "继续操作即表示您接受 Surge 官方的许可条款。"

    workdir=$(mktemp -d)
    if ! curl -fL --progress-bar -o "$workdir/snell.zip" "$url"; then
        rm -rf "$workdir"
        print_error "从 $url 下载失败"
        exit 1
    fi
    unzip -q "$workdir/snell.zip" -d "$workdir"
    install -m 0755 "$workdir/snell-server" "$INSTALL_BIN"
    rm -rf "$workdir"
    print_success "已安装 Surge snell-server ${SURGE_VERSION} → ${INSTALL_BIN}"

    echo "variant=surge"             >  "$META_FILE.tmp"
    echo "version=${SURGE_VERSION}"  >> "$META_FILE.tmp"
}

# ============================================================================
# 交互式构建配置
# ============================================================================
build_config() {
    local variant=""
    if [ -f "$META_FILE.tmp" ]; then
        variant=$(grep '^variant=' "$META_FILE.tmp" | cut -d= -f2)
    elif [ -f "$META_FILE" ]; then
        variant=$(grep '^variant=' "$META_FILE" | cut -d= -f2)
    fi
    variant="${variant:-opensnell}"

    print_header "Snell 服务端参数配置"
    mkdir -p "$CONFIG_DIR"

    # --- 端口 ---
    local default_port port
    default_port=$(pick_free_port)
    port=$(prompt_default "请输入监听端口 (留空则随机分配未占用端口)" "$default_port")
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        print_error "无效的端口号: $port"; exit 1
    fi

    # --- 密码 PSK ---
    local psk
    psk=$(prompt_default "请输入 PSK 共享密钥 (留空则自动随机生成)" "")
    if [ -z "$psk" ]; then
        psk=$(gen_psk)
        print_info "自动生成的 PSK: ${BOLD}${psk}${NC}"
    fi

    # --- 混淆 obfs ---
    local obfs
    obfs=$(prompt_default "请选择 obfs 混淆模式 (off/http/tls)" "off")
    case "$obfs" in off|http|tls) ;; *) print_error "obfs 必须是 off, http, 或 tls 之一"; exit 1 ;; esac

    # --- IPv6 ---
    local ipv6_choice ipv6
    ipv6_choice=$(prompt_yesno "是否允许访问 IPv6 目标网站？ (服务端出站)" "y")
    if [ "$ipv6_choice" = "y" ]; then ipv6="true"; else ipv6="false"; fi

    # OpenSnell 特有配置项
    local udp="true" quic="true" egress="" tfo="false"
    if [ "$variant" = "opensnell" ]; then
        local udp_choice quic_choice tfo_choice
        udp_choice=$(prompt_yesno "是否开启 UDP-over-TCP 支持？ (snell 数据报转发)" "y")
        [ "$udp_choice" = "n" ] && udp="false"

        quic_choice=$(prompt_yesno "是否开启 QUIC 代理模式？ (在同端口处理 UDP；这是 Surge HTTP/3 必备)" "y")
        [ "$quic_choice" = "n" ] && quic="false"

        egress=$(prompt_default "绑定上游出口网卡 (留空则使用系统默认路由，不懂请留空)" "")

        tfo_choice=$(prompt_yesno "是否启用 TCP Fast Open 优化？ (可以降低 1 延迟/RTT；仅限 Linux)" "n")
        [ "$tfo_choice" = "y" ] && tfo="true"
    fi

    # --- 写入配置文件 ---
    cat > "$CONFIG_FILE" <<EOF
[snell-server]
listen = 0.0.0.0:${port}
psk = ${psk}
obfs = ${obfs}
ipv6 = ${ipv6}
EOF
    if [ "$variant" = "opensnell" ]; then
        cat >> "$CONFIG_FILE" <<EOF
udp = ${udp}
quic = ${quic}
egress-interface = ${egress}
tfo = ${tfo}
EOF
    fi

    # 仅在 OpenSnell 环境下修改系统 TFO 属性
    if [ "$variant" = "opensnell" ] && [ "$tfo" = "true" ]; then
        enable_tfo_sysctl
    fi
    chmod 600 "$CONFIG_FILE"
    print_success "配置文件已写入至 $CONFIG_FILE"

    # --- 尝试解析公网 IP 及国家，方便生成节点配置文件 ---
    print_info "正在通过 ip.sb 获取公网 IP 与地理位置..."
    fetch_geo
    local node_name
    node_name=$(generate_node_name)
    print_info "服务器公网 IP: ${BOLD}${GEO_IP}${NC}${GEO_COUNTRY:+  国家/地区: ${GEO_COUNTRY}}"
    print_info "自动生成的节点名: ${BOLD}${node_name}${NC}"

    # --- 持久化元数据 ---
    if [ -f "$META_FILE.tmp" ]; then mv "$META_FILE.tmp" "$META_FILE"; fi
    {
        grep -vE '^(port|psk|obfs|ipv6|tfo|node_name|geo_ip|geo_country)=' "$META_FILE" 2>/dev/null || true
        echo "port=$port"
        echo "psk=$psk"
        echo "obfs=$obfs"
        echo "ipv6=$ipv6"
        echo "tfo=$tfo"
        echo "node_name=$node_name"
        echo "geo_ip=$GEO_IP"
        echo "geo_country=$GEO_COUNTRY"
    } > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "$META_FILE"
    chmod 600 "$META_FILE"
}

# ============================================================================
# systemd 进程守护
# ============================================================================
write_systemd_unit() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Snell server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_BIN} -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    print_success "systemd 服务文件已安装 → $SERVICE_FILE"
}

# ============================================================================
# 防火墙设置
# ============================================================================
configure_firewall() {
    [ -f "$META_FILE" ] || return 0
    local port quic
    port=$(grep '^port=' "$META_FILE" | cut -d= -f2)
    [ -z "$port" ] && return 0
    quic=$(grep -E '^quic\s*=' "$CONFIG_FILE" 2>/dev/null | awk -F= '{gsub(/ /,"",$2); print $2}')

    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        print_info "检测到 UFW 防火墙；正在放行端口 $port"
        ufw allow "${port}/tcp" >/dev/null 2>&1 || true
        [ "$quic" = "true" ] && ufw allow "${port}/udp" >/dev/null 2>&1 || true
        print_success "UFW: 端口 TCP/${port}${quic:+ + UDP/${port}} 已放行"
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        print_info "检测到 firewalld 防火墙；正在放行端口 $port"
        firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
        [ "$quic" = "true" ] && firewall-cmd --permanent --add-port="${port}/udp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        print_success "firewalld: 端口 TCP/${port}${quic:+ + UDP/${port}} 已放行"
    else
        print_info "未检测到活跃的系统防火墙；跳过防火墙配置"
    fi
}

# ============================================================================
# 服务生命周期管理
# ============================================================================
start_service()   { systemctl start   "$SERVICE_NAME" && print_success "服务已启动";   }
stop_service()    { systemctl stop    "$SERVICE_NAME" && print_success "服务已停止";   }
restart_service() { systemctl restart "$SERVICE_NAME" && print_success "服务已重启"; }
enable_service()  { systemctl enable  "$SERVICE_NAME" >/dev/null 2>&1 && print_success "已设置服务开机自启"; }
disable_service() { systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 && print_success "已取消服务开机自启"; }
status_service()  {
    print_header "服务运行状态"
    systemctl status "$SERVICE_NAME" --no-pager 2>&1 | head -15 || true
}

# ============================================================================
# 连接配置导出信息
# ============================================================================
show_info() {
    if [ ! -f "$META_FILE" ]; then
        print_warning "未找到安装元数据文件，服务器是否尚未安装？"
        return 1
    fi
    local variant version channel port psk obfs ipv6 tfo node_name geo_ip ip
    variant=$(grep   '^variant='     "$META_FILE" | cut -d= -f2-)
    version=$(grep   '^version='     "$META_FILE" | cut -d= -f2-)
    channel=$(grep   '^channel='     "$META_FILE" | cut -d= -f2-)
    port=$(grep      '^port='        "$META_FILE" | cut -d= -f2-)
    psk=$(grep       '^psk='         "$META_FILE" | cut -d= -f2-)
    obfs=$(grep      '^obfs='        "$META_FILE" | cut -d= -f2-)
    ipv6=$(grep      '^ipv6='        "$META_FILE" | cut -d= -f2-)
    tfo=$(grep       '^tfo='         "$META_FILE" | cut -d= -f2-)
    node_name=$(grep '^node_name='   "$META_FILE" | cut -d= -f2-)
    geo_ip=$(grep    '^geo_ip='      "$META_FILE" | cut -d= -f2-)
    [ -z "$channel" ] && channel="stable"

    ip="${geo_ip:-}"
    if [ -z "$ip" ]; then
        ip=$(get_ipv4)
    fi
    [ -z "$ip" ] && ip="您的服务器_IP"

    if [ -z "$node_name" ]; then
        fetch_geo || true
        node_name=$(generate_node_name)
    fi

    print_header "节点连接配置"
    echo -e "${BOLD}节点名称:${NC}      ${node_name}"
    echo -e "${BOLD}服务端类型:${NC}    ${variant} (${version})"
    if [ "$variant" = "opensnell" ]; then
        echo -e "${BOLD}更新通道:${NC}      ${channel}"
    fi
    echo -e "${BOLD}服务器 IP:${NC}     ${ip}"
    echo -e "${BOLD}连接端口:${NC}      ${port}"
    echo -e "${BOLD}连接密钥 (PSK):${NC} ${psk}"
    echo -e "${BOLD}混淆 (obfs):${NC}   ${obfs}"
    echo -e "${BOLD}IPv6 出站:${NC}     ${ipv6}"
    echo -e "${BOLD}TCP 快速打开:${NC}  ${tfo}"

    print_header "Surge 配置文件节点格式 (可直接粘贴入 [Proxy] 段内)"
    local tfo_param=""
    [ "$tfo" = "true" ] && tfo_param=", tfo=true"
    echo -e "${GREEN}${node_name} = snell, ${ip}, ${port}, psk=\"${psk}\", version=5${tfo_param}${NC}"

    print_header "Mihomo (Clash Meta) 代理节点格式 (可直接粘贴入 proxies 段内)"
    local mihomo_name mihomo_server mihomo_psk
    mihomo_name=$(yaml_double_quote_escape "$node_name")
    mihomo_server=$(yaml_double_quote_escape "$ip")
    mihomo_psk=$(yaml_double_quote_escape "$psk")
    printf '%b- {name: "%s", server: "%s", port: %s, type: snell, psk: "%s", version: 5}%b\n' \
        "$GREEN" "$mihomo_name" "$mihomo_server" "$port" "$mihomo_psk" "$NC"

    print_header "Shadowrocket (小火箭) 节点 URL (可复制导入)"
    local shadowrocket_payload shadowrocket_name shadowrocket_tfo
    shadowrocket_payload=$(base64_encode "chacha20-ietf-poly1305:${psk}@${ip}:${port}")
    shadowrocket_name=$(url_encode "$node_name")
    if [ "$tfo" = "true" ]; then shadowrocket_tfo="1"; else shadowrocket_tfo="0"; fi
    printf '%bsnell://%s?tfo=%s&version=5#%s%b\n' \
        "$GREEN" "$shadowrocket_payload" "$shadowrocket_tfo" "$shadowrocket_name" "$NC"

    print_header "系统服务状态"
    systemctl is-active --quiet "$SERVICE_NAME" \
        && print_success "snell-server 正在运行" \
        || print_warning "snell-server 目前没有在运行 (可通过命令尝试拉起: systemctl start $SERVICE_NAME)"
}

# ============================================================================
# 顶级入口指令
# ============================================================================
do_install() {
    check_root; ensure_tools

    print_header "OpenSnell 服务器安装向导"
    echo -e "${BOLD}请选择您要安装的服务端变体:${NC}"
    echo -e "${GREEN}1)${NC} OpenSnell ${YELLOW}(默认推荐, 开源 GPLv3 协议, 支持跨平台)${NC}"
    echo -e "${GREEN}2)${NC} Surge 官方 snell-server v5.0.1 ${YELLOW}(闭源原版, 仅限 Linux 平台)${NC}"
    echo
    read -r -p "$(echo -e "${CYAN}请选择版本 [默认: ${BOLD}1${NC}${CYAN}]: ${NC}")" variant_choice
    case "${variant_choice:-1}" in
        1) download_opensnell ;;
        2) download_surge     ;;
        *) print_error "无效的选项"; exit 1 ;;
    esac

    build_config
    write_systemd_unit
    configure_firewall
    enable_service
    systemctl restart "$SERVICE_NAME"
    sleep 1
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "服务已成功启动"
    else
        print_warning "服务尚未运行 — 请使用命令 'journalctl -u $SERVICE_NAME -n 30' 检查日志报错"
    fi
    show_info
}

do_reconfigure() {
    check_root
    [ -f "$INSTALL_BIN" ] || { print_error "未找到二进制文件，请先执行安装步骤。"; exit 1; }
    build_config
    write_systemd_unit
    configure_firewall
    restart_service
    show_info
}

do_update() {
    check_root; ensure_tools
    local variant; variant=$(get_install_variant)
    [ -z "$variant" ] && variant="opensnell"

    if [ "$CHANNEL" = "stable" ]; then
        local persisted_channel
        persisted_channel=$(get_install_channel)
        if [ -n "$persisted_channel" ]; then
            CHANNEL="$persisted_channel"
        fi
    fi

    print_info "正在为您更新服务端: $variant (更新通道: $CHANNEL)"
    if [ "$variant" = "surge" ]; then
        download_surge
    else
        download_opensnell
    fi
    if [ -f "$META_FILE.tmp" ]; then
        local newver newchan
        newver=$(grep '^version=' "$META_FILE.tmp" | cut -d= -f2)
        newchan=$(grep '^channel=' "$META_FILE.tmp" | cut -d= -f2)
        sed -i.bak "s/^version=.*/version=${newver}/" "$META_FILE" 2>/dev/null || true
        if [ -n "$newchan" ]; then
            if grep -q '^channel=' "$META_FILE" 2>/dev/null; then
                sed -i.bak "s/^channel=.*/channel=${newchan}/" "$META_FILE"
            else
                echo "channel=${newchan}" >> "$META_FILE"
            fi
        fi
        rm -f "$META_FILE.tmp" "$META_FILE.bak"
    fi
    restart_service
    print_success "服务端更新完成"
}

do_uninstall() {
    check_root
    print_warning "这将会停止服务并删除二进制文件。"
    local rm_cfg confirm
    confirm=$(prompt_yesno "您确定要继续吗？" "n")
    [ "$confirm" != "y" ] && { print_info "已取消卸载。"; return; }
    systemctl stop    "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -f "$INSTALL_BIN"
    print_success "已删除二进制程序和 systemd 服务文件"
    rm_cfg=$(prompt_yesno "是否同时删除配置文件目录 $CONFIG_DIR (内含 PSK 密码)？" "n")
    if [ "$rm_cfg" = "y" ]; then
        rm -rf "$CONFIG_DIR"
        print_success "已彻底删除 $CONFIG_DIR"
    else
        print_info "配置文件已为您保留在 $CONFIG_DIR"
    fi
}

# ============================================================================
# 命令行接口 (CLI)
# ============================================================================
show_help() {
    cat <<EOF
OpenSnell 服务器管理脚本

用法: $0 [--alpha] <子命令>

子命令:
  install        启动交互式安装流程 (不带参数时默认进入交互菜单)
  reconfigure    交互式重写配置文件，并自动重启服务
  update         重新拉取最新版本覆盖更新，并自动重启服务
  uninstall      停止服务并删除主程序 (+ 可选删除配置文件)
  start | stop | restart | enable | disable | status
  info           打印节点信息 / IP / 端口 / 密码 / Surge / Clash 格式配置
  help           显示此帮助信息

通道标志 (仅适用于安装/更新 OpenSnell 变体；Surge 闭源版不受此参数影响):

  --alpha        拉取 GitHub 的滚动更新 "alpha" 测试版而不是稳定版。
                 适合用来尝鲜测试最新功能。所选通道会被记录在 
                 /etc/snell/.install_meta 文件中，未来使用 update 时
                 会自动保持在该通道，无需重复加参数。要退回稳定版，请
                 重新运行 \`install\`(且不带 --alpha 参数)。

不带任何参数执行脚本将进入数字选择主菜单。
EOF
}

show_menu() {
    echo -e "${BOLD}${MAGENTA}=====================================================${NC}"
    echo -e "${BOLD}${MAGENTA}        OpenSnell 服务端一键管理脚本                 ${NC}"
    echo -e "${BOLD}${MAGENTA}=====================================================${NC}"
    echo
    echo -e "${GREEN}1)${NC}  安装服务端 (Install)"
    echo -e "${GREEN}2)${NC}  重新配置参数 (Reconfigure)"
    echo -e "${GREEN}3)${NC}  检查更新 (Update)"
    echo -e "${RED}4)${NC}  彻底卸载 (Uninstall)"
    echo -e "${BLUE}5)${NC}  启动服务"
    echo -e "${BLUE}6)${NC}  停止服务"
    echo -e "${BLUE}7)${NC}  重启服务"
    echo -e "${CYAN}8)${NC}  设置开机自启"
    echo -e "${CYAN}9)${NC}  取消开机自启"
    echo -e "${YELLOW}10)${NC} 查看运行状态"
    echo -e "${YELLOW}11)${NC} 打印节点连接信息与配置导出"
    echo -e "${MAGENTA}0)${NC}  退出"
    echo
    read -r -p "$(echo -e "${CYAN}请输入您的选择 (0-11): ${NC}")" choice
    case "$choice" in
        1)  do_install        ;;
        2)  do_reconfigure    ;;
        3)  do_update         ;;
        4)  do_uninstall      ;;
        5)  start_service     ;;
        6)  stop_service      ;;
        7)  restart_service   ;;
        8)  enable_service    ;;
        9)  disable_service   ;;
        10) status_service    ;;
        11) show_info         ;;
        0)  print_info "再见！"; exit 0 ;;
        *)  print_error "无效的选项"; exit 1 ;;
    esac
}

main() {
    local positional=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --alpha)        CHANNEL="alpha";    shift ;;
            --stable)       CHANNEL="stable";   shift ;;
            help|--help|-h) show_help; return ;;
            *)              positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]+"${positional[@]}"}"

    check_linux

    case "${1:-}" in
        install)        do_install        ;;
        reconfigure)    do_reconfigure    ;;
        update|upgrade) do_update         ;;
        uninstall)      do_uninstall      ;;
        start)          check_root; start_service     ;;
        stop)           check_root; stop_service      ;;
        restart)        check_root; restart_service   ;;
        enable)         check_root; enable_service    ;;
        disable)        check_root; disable_service   ;;
        status)         status_service                ;;
        info)           show_info                     ;;
        "")             show_menu                     ;;
        *)              print_error "未知命令: $1"; show_help; exit 1 ;;
    esac
}

main "$@"