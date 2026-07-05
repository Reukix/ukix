#!/bin/bash

# Shadowsocks 2022 interactive installer based on shadowsocks-rust.
# Run without arguments to open a Snell-like management menu.

set -euo pipefail

SCRIPT_VERSION="1.0.0"
SERVICE_NAME="ss2022"
INSTALL_DIR="/etc/ss2022"
BINARY_PATH="/usr/local/bin/ss2022-server"
CONFIG_PATH="${INSTALL_DIR}/config.json"
VERSION_FILE="${INSTALL_DIR}/version"
CONNECTION_INFO_FILE="${INSTALL_DIR}/connection-info.txt"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SYSCTL_FILE="/etc/sysctl.d/99-ss2022.conf"

RANDOM_PORT_MIN="6000"
RANDOM_PORT_MAX="65535"
DEFAULT_METHOD="2022-blake3-aes-256-gcm"
DEFAULT_NODE_NAME="$(hostname 2>/dev/null || echo server)-ss2022"
GITHUB_API="https://api.github.com/repos/shadowsocks/shadowsocks-rust"
NETWORK_TIMEOUT="15"
MAX_RETRIES="3"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TMP_ROOT=""
SERVER_HOST_OVERRIDE=""

cleanup() {
    if [[ -n "${TMP_ROOT:-}" && -d "${TMP_ROOT}" ]]; then
        rm -rf "${TMP_ROOT}"
    fi
}
trap cleanup EXIT

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
die() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
prompt() { echo -e "${CYAN}[INPUT]${NC} $*"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    cat <<EOF
Shadowsocks 2022 一键部署管理脚本 v${SCRIPT_VERSION}

用法:
  bash ss2022.sh                  显示交互式菜单
  bash ss2022.sh install          进入安装向导
  bash ss2022.sh update           更新 shadowsocks-rust
  bash ss2022.sh show             查看配置和客户端链接
  bash ss2022.sh status           查看服务状态和最近日志
  bash ss2022.sh log              查看实时日志
  bash ss2022.sh start|stop|restart
  bash ss2022.sh uninstall

安装参数（可选，不传则交互询问）:
  -p, --port <端口>               服务端口
  -w, --password <base64-key>     SS2022 密钥，留空则随机生成
  -m, --method <method>           加密方式，默认 ${DEFAULT_METHOD}
  -n, --name <名称>               节点名称
  -s, --server <地址>             输出链接时使用的服务器地址
      --ss-version <版本>         指定 shadowsocks-rust 版本
  -f, --force                     覆盖已有安装
      --no-tfo                    禁用 TCP Fast Open
      --no-firewall               不自动放行防火墙端口
  -h, --help                      显示帮助

示例:
  bash ss2022.sh
  bash ss2022.sh install
  bash ss2022.sh install -p 443 -w "\$(openssl rand -base64 16)" --force
EOF
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "请使用 root 权限运行：sudo bash $0 ..."
    fi
}

ensure_linux_systemd() {
    local kernel
    kernel="$(uname -s 2>/dev/null || echo unknown)"
    [[ "${kernel}" == "Linux" ]] || die "当前系统为 ${kernel}，本脚本只支持 Linux + systemd 服务器"
    command_exists systemctl || die "未找到 systemctl，无法创建/管理 systemd 服务"
    systemctl list-units --type=service --all >/dev/null 2>&1 || die "systemctl 无法连接到运行中的 systemd"
}

detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists apk; then
        echo "apk"
    else
        echo ""
    fi
}

install_packages() {
    local pm="$1"
    shift
    [[ "$#" -gt 0 ]] || return 0

    case "${pm}" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y "$@"
            ;;
        dnf)
            dnf install -y "$@"
            ;;
        yum)
            yum install -y epel-release >/dev/null 2>&1 || true
            yum install -y "$@"
            ;;
        zypper)
            zypper --non-interactive install "$@"
            ;;
        pacman)
            pacman -Sy --needed --noconfirm "$@"
            ;;
        apk)
            apk add --no-cache "$@"
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_dependencies() {
    local missing=()
    local packages=()

    command_exists curl || { missing+=("curl"); packages+=("curl"); }
    command_exists jq || { missing+=("jq"); packages+=("jq"); }
    command_exists tar || { missing+=("tar"); packages+=("tar"); }
    command_exists xz || { missing+=("xz"); packages+=("xz"); }
    command_exists openssl || { missing+=("openssl"); packages+=("openssl"); }

    if [[ "${#missing[@]}" -eq 0 ]]; then
        success "依赖检查通过"
        return 0
    fi

    local pm
    pm="$(detect_package_manager)"
    [[ -n "${pm}" ]] || die "缺少依赖：${missing[*]}，且未检测到可用包管理器"

    if [[ "${pm}" == "apt" ]]; then
        local i
        for i in "${!packages[@]}"; do
            [[ "${packages[$i]}" == "xz" ]] && packages[$i]="xz-utils"
        done
    fi

    packages+=("ca-certificates")
    info "正在安装依赖：${packages[*]}"
    install_packages "${pm}" "${packages[@]}" || die "依赖安装失败，请手动安装：${missing[*]}"

    command_exists curl || die "安装后仍未找到 curl"
    command_exists jq || die "安装后仍未找到 jq"
    command_exists tar || die "安装后仍未找到 tar"
    command_exists xz || die "安装后仍未找到 xz"
    command_exists openssl || die "安装后仍未找到 openssl"
}

method_key_bytes() {
    case "$1" in
        2022-blake3-aes-128-gcm) echo "16" ;;
        2022-blake3-aes-256-gcm|2022-blake3-chacha20-poly1305|2022-blake3-chacha8-poly1305) echo "32" ;;
        *) return 1 ;;
    esac
}

validate_method() {
    method_key_bytes "$1" >/dev/null || die "不支持的加密方式：$1"
}

b64_nowrap() {
    if base64 --help 2>&1 | grep -q -- '-w'; then
        base64 -w 0
    else
        base64 | tr -d '\n'
    fi
}

generate_password() {
    local method="$1"
    local bytes
    bytes="$(method_key_bytes "${method}")"
    openssl rand -base64 "${bytes}" | tr -d '\n'
}

generate_port() {
    echo $((RANDOM % (RANDOM_PORT_MAX - RANDOM_PORT_MIN + 1) + RANDOM_PORT_MIN))
}

validate_password() {
    local method="$1"
    local password="$2"
    local bytes
    local decoded_len

    bytes="$(method_key_bytes "${method}")"

    if ! printf '%s' "${password}" | base64 -d >/dev/null 2>&1; then
        die "密码必须是有效的 base64 字符串"
    fi

    decoded_len="$(printf '%s' "${password}" | base64 -d 2>/dev/null | wc -c | tr -d '[:space:]')"
    [[ "${decoded_len}" == "${bytes}" ]] || die "${method} 需要 ${bytes} 字节密钥，当前密码解码后为 ${decoded_len} 字节"
}

validate_port() {
    local port="$1"
    [[ "${port}" =~ ^[0-9]+$ ]] || die "端口必须是数字：${port}"
    (( port >= 1 && port <= 65535 )) || die "端口必须在 1-65535 之间：${port}"
}

port_in_use() {
    local port="$1"
    if command_exists ss; then
        ss -H -tuln 2>/dev/null | awk '{print $5}' | grep -Eq "(:|\\])${port}$"
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
    else
        return 1
    fi
}

check_port_available() {
    local port="$1"
    if port_in_use "${port}"; then
        die "端口 ${port} 已被占用，请换一个端口"
    fi
}

detect_libc() {
    if ldd --version 2>&1 | grep -qi musl || ls /lib/ld-musl-*.so* >/dev/null 2>&1; then
        echo "musl"
    else
        echo "gnu"
    fi
}

detect_arch_target() {
    local arch
    local libc
    arch="$(uname -m)"
    libc="$(detect_libc)"

    case "${arch}" in
        x86_64|amd64)
            echo "x86_64-unknown-linux-${libc}"
            ;;
        aarch64|arm64)
            echo "aarch64-unknown-linux-${libc}"
            ;;
        armv7l|armv7)
            if [[ "${libc}" == "musl" ]]; then
                echo "armv7-unknown-linux-musleabihf"
            else
                echo "armv7-unknown-linux-gnueabihf"
            fi
            ;;
        armv6l|arm)
            if [[ "${libc}" == "musl" ]]; then
                echo "arm-unknown-linux-musleabi"
            else
                echo "arm-unknown-linux-gnueabi"
            fi
            ;;
        i386|i686)
            echo "i686-unknown-linux-musl"
            ;;
        loongarch64)
            echo "loongarch64-unknown-linux-${libc}"
            ;;
        riscv64)
            echo "riscv64gc-unknown-linux-${libc}"
            ;;
        mips)
            echo "mips-unknown-linux-gnu"
            ;;
        mipsel)
            echo "mipsel-unknown-linux-gnu"
            ;;
        mips64el)
            echo "mips64el-unknown-linux-gnuabi64"
            ;;
        *)
            die "不支持的 CPU 架构：${arch}"
            ;;
    esac
}

download_file() {
    local url="$1"
    local dest="$2"
    local attempt

    for attempt in $(seq 1 "${MAX_RETRIES}"); do
        if curl -fL --connect-timeout "${NETWORK_TIMEOUT}" --max-time 300 \
            --retry 2 --retry-delay 1 \
            -A "ss2022-installer/${SCRIPT_VERSION}" \
            -o "${dest}" "${url}"; then
            return 0
        fi
        sleep "${attempt}"
    done

    return 1
}

fetch_release_json() {
    local ss_version="${1:-}"
    local url

    if [[ -n "${ss_version}" ]]; then
        ss_version="${ss_version#v}"
        url="${GITHUB_API}/releases/tags/v${ss_version}"
    else
        url="${GITHUB_API}/releases/latest"
    fi

    curl -fsSL --connect-timeout "${NETWORK_TIMEOUT}" --max-time 45 \
        -A "ss2022-installer/${SCRIPT_VERSION}" \
        -H "Accept: application/vnd.github+json" \
        "${url}"
}

download_and_install_binary() {
    local requested_version="${1:-}"
    local release_json
    local tag
    local version
    local target
    local asset_name
    local asset_url
    local sha_url
    local archive_path
    local extract_dir
    local ssserver_path

    info "正在获取 shadowsocks-rust release 信息"
    release_json="$(fetch_release_json "${requested_version}")" || die "获取 release 信息失败"
    tag="$(jq -r '.tag_name // empty' <<<"${release_json}")"
    [[ -n "${tag}" && "${tag}" != "null" ]] || die "release 信息中没有 tag_name"

    version="${tag#v}"
    target="$(detect_arch_target)"
    asset_name="shadowsocks-${tag}.${target}.tar.xz"
    asset_url="$(jq -r --arg name "${asset_name}" '.assets[]? | select(.name == $name) | .browser_download_url' <<<"${release_json}")"
    sha_url="$(jq -r --arg name "${asset_name}.sha256" '.assets[]? | select(.name == $name) | .browser_download_url' <<<"${release_json}")"

    [[ -n "${asset_url}" && "${asset_url}" != "null" ]] || die "未找到适合当前架构的 release 文件：${asset_name}"

    TMP_ROOT="$(mktemp -d -t ss2022.XXXXXX)"
    archive_path="${TMP_ROOT}/${asset_name}"
    extract_dir="${TMP_ROOT}/extract"
    mkdir -p "${extract_dir}"

    info "正在下载 ${asset_name}"
    download_file "${asset_url}" "${archive_path}" || die "下载 shadowsocks-rust 失败"

    if command_exists sha256sum && [[ -n "${sha_url}" && "${sha_url}" != "null" ]]; then
        info "正在校验 SHA256"
        download_file "${sha_url}" "${TMP_ROOT}/${asset_name}.sha256" || die "下载 SHA256 校验文件失败"
        (cd "${TMP_ROOT}" && sha256sum -c "${asset_name}.sha256") || die "SHA256 校验失败"
    else
        warn "未进行 SHA256 校验：缺少 sha256sum 或校验文件"
    fi

    info "正在安装 ssserver"
    tar -xf "${archive_path}" -C "${extract_dir}" || die "解压失败"
    ssserver_path="$(find "${extract_dir}" -type f -name ssserver | head -n 1)"
    [[ -n "${ssserver_path}" ]] || die "压缩包中未找到 ssserver"

    install -m 0755 "${ssserver_path}" "${BINARY_PATH}.new"
    mv -f "${BINARY_PATH}.new" "${BINARY_PATH}"
    mkdir -p "${INSTALL_DIR}"
    printf '%s\n' "${version}" > "${VERSION_FILE}"
    chmod 0644 "${VERSION_FILE}"

    success "shadowsocks-rust v${version} 已安装到 ${BINARY_PATH}"
}

write_config() {
    local port="$1"
    local password="$2"
    local method="$3"
    local enable_tfo="$4"
    local fast_open_json="false"

    [[ "${enable_tfo}" == "true" ]] && fast_open_json="true"

    mkdir -p "${INSTALL_DIR}"
    umask 077
    jq -n \
        --argjson server_port "${port}" \
        --arg password "${password}" \
        --arg method "${method}" \
        --argjson fast_open "${fast_open_json}" \
        '{
            server: "::",
            server_port: $server_port,
            password: $password,
            method: $method,
            mode: "tcp_and_udp",
            timeout: 300,
            fast_open: $fast_open,
            no_delay: true
        }' > "${CONFIG_PATH}"
    chmod 0600 "${CONFIG_PATH}"
    chown root:root "${CONFIG_PATH}" 2>/dev/null || true

    success "配置已写入 ${CONFIG_PATH}"
}

create_systemd_service() {
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Shadowsocks 2022 Server (shadowsocks-rust)
Documentation=https://github.com/shadowsocks/shadowsocks-rust
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BINARY_PATH} -c ${CONFIG_PATH}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "${SERVICE_FILE}"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" >/dev/null
    success "systemd 服务已创建：${SERVICE_NAME}"
}

configure_tfo() {
    local enable_tfo="$1"

    if [[ "${enable_tfo}" != "true" ]]; then
        rm -f "${SYSCTL_FILE}"
        return 0
    fi

    printf 'net.ipv4.tcp_fastopen = 3\n' > "${SYSCTL_FILE}"
    if sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1; then
        success "TCP Fast Open 已启用"
    else
        warn "TCP Fast Open 启用失败，服务仍会继续安装"
    fi
}

open_firewall_port() {
    local port="$1"

    if command_exists firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        info "检测到 firewalld，正在放行 ${port}/tcp 和 ${port}/udp"
        firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null || warn "firewalld 放行 TCP 失败"
        firewall-cmd --permanent --add-port="${port}/udp" >/dev/null || warn "firewalld 放行 UDP 失败"
        firewall-cmd --reload >/dev/null || warn "firewalld reload 失败"
    elif command_exists ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
        info "检测到 ufw，正在放行 ${port}/tcp 和 ${port}/udp"
        ufw allow "${port}/tcp" >/dev/null || warn "ufw 放行 TCP 失败"
        ufw allow "${port}/udp" >/dev/null || warn "ufw 放行 UDP 失败"
    else
        warn "未检测到启用中的 ufw/firewalld，如有云防火墙请手动放行 ${port}/tcp 和 ${port}/udp"
    fi
}

start_service() {
    systemctl restart "${SERVICE_NAME}"
    sleep 1
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        success "${SERVICE_NAME} 服务运行中"
    else
        systemctl status --full --no-pager "${SERVICE_NAME}" || true
        die "${SERVICE_NAME} 启动失败，请查看上方日志"
    fi
}

read_config_value() {
    local key="$1"
    [[ -f "${CONFIG_PATH}" ]] || die "未找到配置文件：${CONFIG_PATH}"
    jq -r "${key}" "${CONFIG_PATH}"
}

get_public_ip() {
    if [[ -n "${SERVER_HOST_OVERRIDE}" ]]; then
        echo "${SERVER_HOST_OVERRIDE}"
        return 0
    fi

    if ! command_exists curl; then
        return 1
    fi

    local ip
    local service
    local ipv4_services=("https://api.ipify.org" "https://ip.sb" "https://ifconfig.me/ip")
    local ipv6_services=("https://api64.ipify.org" "https://ipv6.ip.sb")

    for service in "${ipv4_services[@]}"; do
        ip="$(curl -fsSL -4 --connect-timeout 5 --max-time 8 "${service}" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "${ip}"
            return 0
        fi
    done

    for service in "${ipv6_services[@]}"; do
        ip="$(curl -fsSL -6 --connect-timeout 5 --max-time 8 "${service}" 2>/dev/null | tr -d '[:space:]' || true)"
        if [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]]; then
            echo "${ip}"
            return 0
        fi
    done

    return 1
}

is_ipv6_host() {
    [[ "$1" == *:* && "$1" != \[*\] ]]
}

strip_ipv6_brackets() {
    local host="$1"
    host="${host#[}"
    host="${host%]}"
    echo "${host}"
}

encode_fragment() {
    printf '%s' "$1" \
        | sed -e 's/%/%25/g' \
              -e 's/ /%20/g' \
              -e 's/#/%23/g' \
              -e 's/?/%3F/g' \
              -e 's/&/%26/g'
}

show_config() {
    local host="${1:-}"
    local port
    local password
    local method
    local node_name
    local host_for_uri
    local host_plain
    local credentials
    local ss_link
    local service_state
    local output

    [[ -f "${CONFIG_PATH}" ]] || die "未安装或配置文件不存在"

    port="$(read_config_value '.server_port')"
    password="$(read_config_value '.password')"
    method="$(read_config_value '.method')"
    node_name="$(read_config_value '.remarks // empty' 2>/dev/null || true)"
    [[ -n "${node_name}" && "${node_name}" != "null" ]] || node_name="${DEFAULT_NODE_NAME}"

    if [[ -z "${host}" ]]; then
        host="$(get_public_ip || true)"
    fi
    [[ -n "${host}" ]] || host="YOUR_SERVER_IP"

    host_for_uri="${host}"
    is_ipv6_host "${host_for_uri}" && host_for_uri="[${host_for_uri}]"
    host_plain="$(strip_ipv6_brackets "${host_for_uri}")"
    credentials="$(printf '%s' "${method}:${password}" | b64_nowrap)"
    ss_link="ss://${credentials}@${host_for_uri}:${port}#$(encode_fragment "${node_name}")"
    service_state="$(systemctl is-active "${SERVICE_NAME}" 2>/dev/null || echo unknown)"

    output="$(cat <<EOF

================ Shadowsocks 2022 ================
服务状态: ${service_state}
地址: ${host_plain}
端口: ${port}
加密: ${method}
密码: ${password}
配置: ${CONFIG_PATH}

SS 链接:
${ss_link}

Clash:
- {name: "${node_name}", type: ss, server: ${host_plain}, port: ${port}, cipher: ${method}, password: "${password}", udp: true}

Surge/Loon:
${node_name} = ss, ${host_plain}, ${port}, encrypt-method=${method}, password=${password}, udp-relay=true, tfo=true
===================================================

EOF
)"

    printf '%s\n' "${output}"

    if [[ "${EUID:-0}" -eq 0 ]]; then
        mkdir -p "${INSTALL_DIR}"
        if printf '%s\n' "${output}" > "${CONNECTION_INFO_FILE}"; then
            chmod 0600 "${CONNECTION_INFO_FILE}" 2>/dev/null || true
        else
            warn "连接信息保存失败: ${CONNECTION_INFO_FILE}"
        fi
    fi
}

ask_yes_no() {
    local message="$1"
    local default="${2:-N}"
    local answer

    if [[ "${default}" =~ ^[Yy]$ ]]; then
        read -r -p "${message} [Y/n]: " answer
        [[ -z "${answer}" || "${answer}" =~ ^[Yy]$ ]]
    else
        read -r -p "${message} [y/N]: " answer
        [[ "${answer}" =~ ^[Yy]$ ]]
    fi
}

choose_method_interactive() {
    local default="${1:-${DEFAULT_METHOD}}"
    local choice

    echo "请选择加密方式：" >&2
    echo "  1) 2022-blake3-aes-128-gcm" >&2
    echo "  2) 2022-blake3-aes-256-gcm" >&2
    echo "  3) 2022-blake3-chacha20-poly1305" >&2
    echo "  4) 2022-blake3-chacha8-poly1305" >&2
    printf '默认 %s: ' "${default}" >&2
    read -r choice

    case "${choice}" in
        "") echo "${default}" ;;
        1) echo "2022-blake3-aes-128-gcm" ;;
        2) echo "2022-blake3-aes-256-gcm" ;;
        3) echo "2022-blake3-chacha20-poly1305" ;;
        4) echo "2022-blake3-chacha8-poly1305" ;;
        *) warn "输入无效，使用默认 ${default}"; echo "${default}" ;;
    esac
}

parse_install_args() {
    INSTALL_PORT=""
    INSTALL_PASSWORD=""
    INSTALL_METHOD="${DEFAULT_METHOD}"
    INSTALL_NODE_NAME="${DEFAULT_NODE_NAME}"
    INSTALL_FORCE="false"
    INSTALL_TFO="true"
    INSTALL_FIREWALL="true"
    INSTALL_SS_VERSION=""
    INSTALL_PORT_SET="false"
    INSTALL_PASSWORD_SET="false"
    INSTALL_METHOD_SET="false"
    INSTALL_NODE_NAME_SET="false"
    INSTALL_TFO_SET="false"
    INSTALL_FIREWALL_SET="false"
    INSTALL_SERVER_SET="false"

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -p|--port)
                [[ "$#" -ge 2 ]] || die "$1 需要端口参数"
                INSTALL_PORT="$2"
                INSTALL_PORT_SET="true"
                shift 2
                ;;
            -w|--password|--pass)
                [[ "$#" -ge 2 ]] || die "$1 需要密码参数"
                INSTALL_PASSWORD="$2"
                INSTALL_PASSWORD_SET="true"
                shift 2
                ;;
            -m|--method)
                [[ "$#" -ge 2 ]] || die "$1 需要加密方式参数"
                INSTALL_METHOD="$2"
                INSTALL_METHOD_SET="true"
                shift 2
                ;;
            -n|--name)
                [[ "$#" -ge 2 ]] || die "$1 需要节点名参数"
                INSTALL_NODE_NAME="$2"
                INSTALL_NODE_NAME_SET="true"
                shift 2
                ;;
            -s|--server)
                [[ "$#" -ge 2 ]] || die "$1 需要服务器地址参数"
                SERVER_HOST_OVERRIDE="$2"
                INSTALL_SERVER_SET="true"
                shift 2
                ;;
            --ss-version)
                [[ "$#" -ge 2 ]] || die "$1 需要版本号参数，例如 1.24.0"
                INSTALL_SS_VERSION="$2"
                shift 2
                ;;
            -f|--force)
                INSTALL_FORCE="true"
                shift
                ;;
            --no-tfo)
                INSTALL_TFO="false"
                INSTALL_TFO_SET="true"
                shift
                ;;
            --no-firewall)
                INSTALL_FIREWALL="false"
                INSTALL_FIREWALL_SET="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "未知参数：$1"
                ;;
        esac
    done
}

collect_install_config() {
    local default_port
    local input

    validate_method "${INSTALL_METHOD}"

    if [[ -t 0 ]]; then
        echo ""
        info "=========================================="
        info "Shadowsocks 2022 配置向导"
        info "=========================================="
        echo ""
        info "提示: 直接按回车将使用推荐或随机生成的值"
        echo ""
    fi

    if [[ -z "${INSTALL_PORT}" ]]; then
        default_port="$(generate_port)"
        if [[ -t 0 ]]; then
            prompt "请输入监听端口 (默认: ${default_port}, 可用范围: 1-65535，随机默认避开低端口): "
            read -r input
            INSTALL_PORT="${input:-${default_port}}"
        else
            INSTALL_PORT="${default_port}"
        fi
    fi
    validate_port "${INSTALL_PORT}"
    [[ -t 0 ]] && info "监听端口: ${INSTALL_PORT}"

    if [[ -t 0 && "${INSTALL_METHOD_SET}" != "true" ]]; then
        echo ""
        INSTALL_METHOD="$(choose_method_interactive "${INSTALL_METHOD}")"
        validate_method "${INSTALL_METHOD}"
        info "加密方式: ${INSTALL_METHOD}"
    fi

    if [[ -z "${INSTALL_PASSWORD}" ]]; then
        if [[ -t 0 ]]; then
            echo ""
            prompt "请输入 SS2022 base64 密钥 (默认: 按加密方式随机生成): "
            read -r INSTALL_PASSWORD
        fi
        if [[ -z "${INSTALL_PASSWORD}" ]]; then
            INSTALL_PASSWORD="$(generate_password "${INSTALL_METHOD}")"
            [[ -t 0 ]] && info "使用随机密钥: ${INSTALL_PASSWORD}"
        else
            [[ -t 0 ]] && info "使用自定义密钥"
        fi
    fi

    validate_password "${INSTALL_METHOD}" "${INSTALL_PASSWORD}"

    if [[ -t 0 && "${INSTALL_NODE_NAME_SET}" != "true" ]]; then
        echo ""
        prompt "请输入节点名称 (默认: ${INSTALL_NODE_NAME}): "
        read -r input
        INSTALL_NODE_NAME="${input:-${INSTALL_NODE_NAME}}"
    fi

    if [[ -t 0 && "${INSTALL_SERVER_SET}" != "true" ]]; then
        echo ""
        prompt "请输入服务器地址/域名用于生成链接 (默认: 自动获取公网 IP): "
        read -r input
        SERVER_HOST_OVERRIDE="${input:-${SERVER_HOST_OVERRIDE}}"
    fi

    if [[ -t 0 && "${INSTALL_TFO_SET}" != "true" ]]; then
        echo ""
        if ask_yes_no "是否启用 TCP Fast Open (TFO)?" "Y"; then
            INSTALL_TFO="true"
        else
            INSTALL_TFO="false"
        fi
    fi

    if [[ -t 0 && "${INSTALL_FIREWALL_SET}" != "true" ]]; then
        echo ""
        if ask_yes_no "是否尝试自动放行防火墙端口 ${INSTALL_PORT}/tcp 和 ${INSTALL_PORT}/udp?" "Y"; then
            INSTALL_FIREWALL="true"
        else
            INSTALL_FIREWALL="false"
        fi
    fi

    if [[ -t 0 ]]; then
        echo ""
        info "=========================================="
        info "配置确认"
        info "=========================================="
        info "监听端口: ${INSTALL_PORT}"
        info "加密方式: ${INSTALL_METHOD}"
        info "密钥: ${INSTALL_PASSWORD}"
        info "节点名称: ${INSTALL_NODE_NAME}"
        if [[ -n "${SERVER_HOST_OVERRIDE}" ]]; then
            info "链接地址: ${SERVER_HOST_OVERRIDE}"
        else
            info "链接地址: 自动获取公网 IP"
        fi
        info "TCP Fast Open: ${INSTALL_TFO}"
        info "自动防火墙: ${INSTALL_FIREWALL}"
        info "=========================================="
        echo ""
        if ! ask_yes_no "确认以上配置并继续安装?" "N"; then
            warn "安装已取消"
            return 1
        fi
    fi
}

store_node_name() {
    local node_name="$1"
    local tmp_file

    tmp_file="$(mktemp)"
    jq --arg remarks "${node_name}" '. + {remarks: $remarks}' "${CONFIG_PATH}" > "${tmp_file}"
    install -m 0600 "${tmp_file}" "${CONFIG_PATH}"
    rm -f "${tmp_file}"
}

install_command() {
    local existing_install="false"

    parse_install_args "$@"
    require_root
    ensure_linux_systemd
    ensure_dependencies

    if [[ -f "${BINARY_PATH}" || -f "${SERVICE_FILE}" || -d "${INSTALL_DIR}" ]]; then
        existing_install="true"
        if [[ "${INSTALL_FORCE}" != "true" ]]; then
            if [[ -t 0 ]]; then
                if ! ask_yes_no "检测到已有安装，是否覆盖重装？" "N"; then
                    warn "已取消安装"
                    return 0
                fi
            else
                die "检测到已有安装，如需覆盖请加 --force"
            fi
        fi
    fi

    collect_install_config || return 0
    if [[ "${existing_install}" == "true" ]]; then
        systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
    fi
    check_port_available "${INSTALL_PORT}"
    download_and_install_binary "${INSTALL_SS_VERSION}"
    write_config "${INSTALL_PORT}" "${INSTALL_PASSWORD}" "${INSTALL_METHOD}" "${INSTALL_TFO}"
    store_node_name "${INSTALL_NODE_NAME}"
    configure_tfo "${INSTALL_TFO}"
    create_systemd_service
    [[ "${INSTALL_FIREWALL}" == "true" ]] && open_firewall_port "${INSTALL_PORT}"
    start_service
    show_config "${SERVER_HOST_OVERRIDE}"
}

update_command() {
    local ss_version=""

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --ss-version)
                [[ "$#" -ge 2 ]] || die "$1 需要版本号参数"
                ss_version="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: bash ss2022.sh update [--ss-version <version>]"
                return 0
                ;;
            *)
                die "未知参数：$1"
                ;;
        esac
    done

    require_root
    ensure_linux_systemd
    ensure_dependencies
    [[ -f "${BINARY_PATH}" ]] || die "未安装 ss2022，请先执行 install"

    download_and_install_binary "${ss_version}"
    create_systemd_service
    start_service
    show_config
}

modify_command() {
    local current_port
    local current_method
    local current_password
    local current_name
    local new_port
    local new_method
    local new_password
    local new_name
    local tfo_enabled="true"

    require_root
    ensure_linux_systemd
    ensure_dependencies
    [[ -f "${CONFIG_PATH}" ]] || die "未找到配置，请先安装"

    current_port="$(read_config_value '.server_port')"
    current_method="$(read_config_value '.method')"
    current_password="$(read_config_value '.password')"
    current_name="$(read_config_value '.remarks // empty')"
    [[ -n "${current_name}" && "${current_name}" != "null" ]] || current_name="${DEFAULT_NODE_NAME}"

    read -r -p "新端口 (当前 ${current_port}，回车保留): " new_port
    new_port="${new_port:-${current_port}}"
    validate_port "${new_port}"

    prompt "修改加密方式"
    new_method="$(choose_method_interactive "${current_method}")"
    validate_method "${new_method}"

    read -r -p "新密码（回车保留，输入 random 随机生成）: " new_password
    if [[ "${new_password}" == "random" ]]; then
        new_password="$(generate_password "${new_method}")"
        success "已生成新密钥"
    elif [[ -z "${new_password}" ]]; then
        if [[ "${new_method}" != "${current_method}" ]]; then
            new_password="$(generate_password "${new_method}")"
            warn "加密方式已改变，旧密钥长度可能不匹配，已自动生成新密钥"
        else
            new_password="${current_password}"
        fi
    fi
    validate_password "${new_method}" "${new_password}"

    read -r -p "节点名 (当前 ${current_name}，回车保留): " new_name
    new_name="${new_name:-${current_name}}"

    echo ""
    info "=========================================="
    info "修改确认"
    info "=========================================="
    info "监听端口: ${new_port}"
    info "加密方式: ${new_method}"
    info "密钥: ${new_password}"
    info "节点名称: ${new_name}"
    info "=========================================="
    echo ""
    if ! ask_yes_no "确认修改配置?" "N"; then
        info "已取消修改"
        return 0
    fi

    if [[ "${new_port}" != "${current_port}" ]]; then
        check_port_available "${new_port}"
    fi

    if [[ -f "${SYSCTL_FILE}" ]]; then
        tfo_enabled="true"
    else
        tfo_enabled="$(jq -r '.fast_open // true' "${CONFIG_PATH}")"
    fi

    write_config "${new_port}" "${new_password}" "${new_method}" "${tfo_enabled}"
    store_node_name "${new_name}"
    create_systemd_service
    start_service
    show_config
}

status_command() {
    ensure_linux_systemd
    echo
    systemctl status --full --no-pager "${SERVICE_NAME}" || true
    echo
    echo "最近日志："
    journalctl -u "${SERVICE_NAME}" --no-pager -n 30 || true
}

log_command() {
    ensure_linux_systemd
    echo ""
    info "即将进入实时日志模式，按 Ctrl+C 退出"
    journalctl -u "${SERVICE_NAME}" -f
}

view_config_file() {
    [[ -f "${CONFIG_PATH}" ]] || die "未找到配置文件：${CONFIG_PATH}"
    echo ""
    echo "配置文件: ${CONFIG_PATH}"
    echo "------------------------------------------"
    if command_exists jq; then
        jq . "${CONFIG_PATH}"
    else
        cat "${CONFIG_PATH}"
    fi
}

manage_service() {
    local action="$1"
    require_root
    ensure_linux_systemd
    [[ -f "${SERVICE_FILE}" ]] || die "服务不存在，请先安装"
    systemctl "${action}" "${SERVICE_NAME}"
    if [[ "${action}" == "start" || "${action}" == "restart" ]]; then
        sleep 1
        systemctl is-active --quiet "${SERVICE_NAME}" && success "服务已${action}" || status_command
    else
        success "服务已${action}"
    fi
}

uninstall_command() {
    require_root
    ensure_linux_systemd

    if [[ -t 0 ]]; then
        if ! ask_yes_no "确定卸载 ss2022 并删除配置？" "N"; then
            warn "已取消卸载"
            return 0
        fi
    fi

    systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
    rm -f "${SERVICE_FILE}"
    rm -f "${BINARY_PATH}"
    rm -f "${SYSCTL_FILE}"
    rm -rf "${INSTALL_DIR}"
    systemctl daemon-reload
    systemctl reset-failed "${SERVICE_NAME}" >/dev/null 2>&1 || true
    success "ss2022 已卸载"
}

menu() {
    while true; do
        clear
        echo ""
        echo -e "${CYAN}=========================================="
        echo -e "    Shadowsocks 2022 一键部署管理脚本"
        echo -e "==========================================${NC}"
        echo ""
        if [[ -f "${BINARY_PATH}" ]]; then
            if command_exists systemctl; then
                echo -e " 当前状态: ${GREEN}$(systemctl is-active "${SERVICE_NAME}" 2>/dev/null || echo unknown)${NC}"
            else
                echo -e " 当前状态: ${YELLOW}已安装，未检测 systemctl${NC}"
            fi
            echo -e " 内核版本: ${GREEN}$(cat "${VERSION_FILE}" 2>/dev/null || echo unknown)${NC}"
        else
            echo -e " 当前状态: ${YELLOW}未安装${NC}"
        fi
        echo
        echo -e "${YELLOW}基础管理:${NC}"
        echo "  1) 安装 / 重装 Shadowsocks 2022"
        echo "  2) 启动服务"
        echo "  3) 停止服务"
        echo "  4) 重启服务"
        echo "  5) 查看服务状态"
        echo "  6) 查看实时日志"
        echo "  7) 查看配置文件"
        echo "  8) 查看连接信息"
        echo "  9) 修改配置"
        echo " 10) 更新 shadowsocks-rust"
        echo " 11) 卸载 Shadowsocks 2022"
        echo ""
        echo " 0) 退出"
        echo ""
        echo -e "${CYAN}==========================================${NC}"
        echo
        prompt "请输入选项 [0-11]: "
        read -r choice
        case "${choice}" in
            1) install_command ;;
            2) manage_service start ;;
            3) manage_service stop ;;
            4)
                if ask_yes_no "确认重启 ${SERVICE_NAME} 服务?" "N"; then
                    manage_service restart
                else
                    info "已取消重启"
                fi
                ;;
            5) status_command ;;
            6)
                if ask_yes_no "继续查看实时日志?" "N"; then
                    log_command
                fi
                ;;
            7) view_config_file ;;
            8) show_config ;;
            9) modify_command ;;
            10) update_command ;;
            11) uninstall_command ;;
            0)
                info "退出脚本"
                exit 0
                ;;
            *) warn "无效选项，请输入 0-11" ;;
        esac
        echo
        read -r -p "按回车返回菜单..." _
    done
}

main() {
    local cmd="${1:-}"

    case "${cmd}" in
        "")
            if [[ -t 0 ]]; then
                menu
            else
                die "交互菜单需要 TTY。请下载后运行 bash ss2022.sh，或使用 bash <(curl -sL URL)"
            fi
            ;;
        install|i)
            shift
            install_command "$@"
            ;;
        update|u)
            shift
            update_command "$@"
            ;;
        modify|edit)
            shift
            modify_command "$@"
            ;;
        config)
            shift
            view_config_file "$@"
            ;;
        show|info|link)
            shift
            while [[ "$#" -gt 0 ]]; do
                case "$1" in
                    -s|--server)
                        [[ "$#" -ge 2 ]] || die "$1 需要服务器地址参数"
                        SERVER_HOST_OVERRIDE="$2"
                        shift 2
                        ;;
                    *) die "未知参数：$1" ;;
                esac
            done
            show_config "${SERVER_HOST_OVERRIDE}"
            ;;
        status)
            shift
            status_command "$@"
            ;;
        log|logs)
            shift
            log_command "$@"
            ;;
        start|stop|restart)
            shift
            manage_service "${cmd}"
            ;;
        uninstall|remove)
            shift
            uninstall_command "$@"
            ;;
        menu)
            shift
            menu "$@"
            ;;
        -h|--help|help)
            usage
            ;;
        --*)
            install_command "$@"
            ;;
        *)
            die "未知命令：${cmd}，使用 --help 查看用法"
            ;;
    esac
}

main "$@"
