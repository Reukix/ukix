#!/bin/bash

#================================================================
# Snell v6 一键部署脚本
# 支持自动检测架构、下载、安装、配置和启动 Snell 服务
#================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
SNELL_VERSION_V6="v6.0.0b3"
SNELL_VERSION_V5="v5.0.1"
SNELL_VERSION=""
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/snell"
CONFIG_FILE="${CONFIG_DIR}/snell-server.conf"
SERVICE_FILE="/etc/systemd/system/snell.service"
MULTI_USER_DIR="${CONFIG_DIR}/users"
SNELL_BINARY=""  # 将根据版本动态设置

# 用户配置变量
USER_PORT=""
USER_PORT_V6=""
USER_PSK=""
USER_IPV6="true"
USER_DNS_PREF="default"
USER_DNS=""
USER_TFO="true"
CURRENT_USER=""
SNELL_CHOICE=""  # v5 或 v6

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_prompt() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 权限运行此脚本"
        exit 1
    fi
}

# 检测系统架构
detect_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        i386|i686)
            ARCH="i386"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        armv7l|armv7)
            ARCH="armv7l"
            ;;
        *)
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    print_info "检测到系统架构: $arch -> $ARCH"
}

# 选择 Snell 版本
select_snell_version() {
    echo ""
    print_info "=========================================="
    print_info "请选择要安装的 Snell 版本:"
    print_info "=========================================="
    echo ""
    echo "  1) Snell v5 (稳定版 - 推荐)"
    echo "  2) Snell v6 (测试版)"
    echo ""
    print_prompt "请输入选项 [1-2]: "
    read -r version_choice

    case "$version_choice" in
        1)
            SNELL_CHOICE="v5"
            SNELL_VERSION="$SNELL_VERSION_V5"
            SNELL_BINARY="${INSTALL_DIR}/snell-server-v5"
            print_info "已选择 Snell v5"
            ;;
        2)
            SNELL_CHOICE="v6"
            SNELL_VERSION="$SNELL_VERSION_V6"
            SNELL_BINARY="${INSTALL_DIR}/snell-server-v6"
            print_info "已选择 Snell v6"
            ;;
        *)
            print_warning "无效选择，默认使用 v6"
            SNELL_CHOICE="v6"
            SNELL_VERSION="$SNELL_VERSION_V6"
            SNELL_BINARY="${INSTALL_DIR}/snell-server-v6"
            ;;
    esac
}

# 生成随机密码
generate_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# 生成随机端口
generate_port() {
    echo $((RANDOM % 59536 + 6000))
}

# 获取用户输入的配置参数
get_user_config() {
    echo ""
    print_info "=========================================="
    print_info "Snell ${SNELL_CHOICE} 配置向导"
    print_info "=========================================="
    echo ""
    print_info "提示: 直接按回车将使用随机生成的值"
    echo ""

    # 获取端口
    local default_port=$(generate_port)

    if [ "$SNELL_CHOICE" = "v5" ]; then
        print_prompt "请输入监听端口 (默认: $default_port, 范围: 6000-65535): "
    else
        print_prompt "请输入 IPv4 监听端口 (默认: $default_port, 范围: 6000-65535): "
    fi

    read -r input_port
    if [ -z "$input_port" ]; then
        USER_PORT="$default_port"
        print_info "使用随机端口: $USER_PORT"
    else
        # 验证端口号
        if [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 6000 ] && [ "$input_port" -le 65535 ]; then
            USER_PORT="$input_port"
            print_info "使用端口: $USER_PORT"
        else
            print_error "无效的端口号（范围6000-65535），使用默认端口: $default_port"
            USER_PORT="$default_port"
        fi
    fi

    # 获取 PSK
    local default_psk=$(generate_password)
    echo ""
    print_prompt "请输入 PSK 密码 (默认: 随机生成32位密码): "
    read -r input_psk
    if [ -z "$input_psk" ]; then
        USER_PSK="$default_psk"
        print_info "使用随机密码: $USER_PSK"
    else
        USER_PSK="$input_psk"
        print_info "使用自定义密码: $USER_PSK"
    fi

    # 获取 IPv6 配置
    echo ""
    print_prompt "是否启用 IPv6? (y/n, 默认: y): "
    read -r input_ipv6
    if [ -z "$input_ipv6" ] || [[ "$input_ipv6" =~ ^[Yy]$ ]]; then
        USER_IPV6="true"

        # v6 版本支持不同端口
        if [ "$SNELL_CHOICE" = "v6" ]; then
            # 如果启用 IPv6，询问是否使用不同端口
            echo ""
            print_prompt "IPv6 是否使用与 IPv4 相同的端口 $USER_PORT? (y/n, 默认: y): "
            read -r same_port
            if [ -z "$same_port" ] || [[ "$same_port" =~ ^[Yy]$ ]]; then
                USER_PORT_V6="$USER_PORT"
                print_info "IPv6 使用相同端口: $USER_PORT_V6"
            else
                local default_port_v6=$(generate_port)
                print_prompt "请输入 IPv6 监听端口 (默认: $default_port_v6, 范围: 6000-65535): "
                read -r input_port_v6
                if [ -z "$input_port_v6" ]; then
                    USER_PORT_V6="$default_port_v6"
                    print_info "IPv6 使用随机端口: $USER_PORT_V6"
                else
                    if [[ "$input_port_v6" =~ ^[0-9]+$ ]] && [ "$input_port_v6" -ge 6000 ] && [ "$input_port_v6" -le 65535 ]; then
                        USER_PORT_V6="$input_port_v6"
                        print_info "IPv6 使用端口: $USER_PORT_V6"
                    else
                        print_error "无效的端口号，使用默认端口: $default_port_v6"
                        USER_PORT_V6="$default_port_v6"
                    fi
                fi
            fi
        else
            # v5 版本使用统一端口
            USER_PORT_V6="$USER_PORT"
        fi

        print_info "IPv6: 已启用"
    else
        USER_IPV6="false"
        USER_PORT_V6=""
        print_info "IPv6: 已禁用"
    fi

    # v5 需要配置 DNS，v6 需要配置 DNS 偏好
    if [ "$SNELL_CHOICE" = "v5" ]; then
        echo ""
        print_prompt "请输入 DNS 服务器 (默认: 1.1.1.1,2606:4700:4700::1111,8.8.8.8,2001:4860:4860::8888): "
        read -r input_dns
        if [ -z "$input_dns" ]; then
            USER_DNS="1.1.1.1,2606:4700:4700::1111,8.8.8.8,2001:4860:4860::8888"
        else
            USER_DNS="$input_dns"
        fi
        print_info "DNS: $USER_DNS"
    else
        # 获取 DNS IP 偏好
        echo ""
        print_info "DNS IP 偏好选项:"
        print_info "  1) default - 系统默认"
        print_info "  2) prefer-ipv4 - 优先 IPv4"
        print_info "  3) prefer-ipv6 - 优先 IPv6"
        print_info "  4) ipv4-only - 仅 IPv4"
        print_info "  5) ipv6-only - 仅 IPv6"
        echo ""
        print_prompt "请选择 DNS IP 偏好 (1-5, 默认: 1): "
        read -r input_dns
        case "$input_dns" in
            2)
                USER_DNS_PREF="prefer-ipv4"
                ;;
            3)
                USER_DNS_PREF="prefer-ipv6"
                ;;
            4)
                USER_DNS_PREF="ipv4-only"
                ;;
            5)
                USER_DNS_PREF="ipv6-only"
                ;;
            *)
                USER_DNS_PREF="default"
                ;;
        esac
        print_info "DNS IP 偏好: $USER_DNS_PREF"
    fi

    # 获取 TFO 配置
    echo ""
    print_prompt "是否启用 TCP Fast Open (TFO)? (y/n, 默认: y): "
    read -r input_tfo
    if [ -z "$input_tfo" ] || [[ "$input_tfo" =~ ^[Yy]$ ]]; then
        USER_TFO="true"
        print_info "TFO: 已启用"
    else
        USER_TFO="false"
        print_info "TFO: 已禁用"
    fi

    echo ""
    print_info "=========================================="
    print_info "配置确认"
    print_info "=========================================="
    print_info "版本: Snell ${SNELL_CHOICE}"
    if [ "$SNELL_CHOICE" = "v6" ]; then
        print_info "IPv4 端口: $USER_PORT"
        if [ "$USER_IPV6" = "true" ]; then
            print_info "IPv6 端口: $USER_PORT_V6"
        fi
    else
        print_info "监听端口: $USER_PORT"
    fi
    print_info "PSK: $USER_PSK"
    print_info "IPv6: $USER_IPV6"
    if [ "$SNELL_CHOICE" = "v5" ]; then
        print_info "DNS: $USER_DNS"
    else
        print_info "DNS IP 偏好: $USER_DNS_PREF"
    fi
    print_info "=========================================="
    echo ""
    print_prompt "确认以上配置并继续安装? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "安装已取消"
        exit 0
    fi
}

# 下载 Snell 服务器
download_snell() {
    # 根据选择的版本构建下载链接和二进制文件名
    local binary_name=""

    if [ "$SNELL_CHOICE" = "v5" ]; then
        SNELL_VERSION="$SNELL_VERSION_V5"
        binary_name="snell-server-v5"
    else
        SNELL_VERSION="$SNELL_VERSION_V6"
        binary_name="snell-server-v6"
    fi

    SNELL_BINARY="${INSTALL_DIR}/${binary_name}"

    # 检查是否已安装该版本
    if [ -f "$SNELL_BINARY" ]; then
        print_warning "Snell ${SNELL_CHOICE} 已安装，将覆盖现有版本"
    fi

    local temp_dir=$(mktemp -d)
    local zip_file="${temp_dir}/snell-server.zip"

    print_info "开始下载 Snell ${SNELL_CHOICE} (${SNELL_VERSION})..."

    if ! download_snell_archive "$SNELL_CHOICE" "$zip_file"; then
        print_error "下载失败"
        rm -rf "$temp_dir"
        exit 1
    fi

    print_info "解压文件..."
    unzip -q "$zip_file" -d "$temp_dir" || {
        print_error "解压失败"
        rm -rf "$temp_dir"
        exit 1
    }

    print_info "安装 Snell 服务器到 $SNELL_BINARY..."
    mv "${temp_dir}/snell-server" "$SNELL_BINARY"
    chmod +x "$SNELL_BINARY"

    rm -rf "$temp_dir"
    print_info "Snell ${SNELL_CHOICE} 服务器安装完成"

    # 验证安装的版本
    local installed_version=$("$SNELL_BINARY" --version 2>&1 | head -1)
    print_info "已安装版本: $installed_version"
}

# 创建配置文件
create_config() {
    print_info "创建配置文件..."

    mkdir -p "$CONFIG_DIR"

    # 获取服务器 IP
    local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")

    # 根据版本创建不同格式的配置文件
    if [ "$SNELL_CHOICE" = "v5" ]; then
        # v5 配置格式
        cat > "$CONFIG_FILE" <<EOF
# Snell Version: v5
# Binary: ${SNELL_BINARY}
[snell-server]
listen = ::0:${USER_PORT}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns = ${USER_DNS}
tfo = ${USER_TFO}
EOF
    else
        # v6 配置格式
        local listen_addr="0.0.0.0:${USER_PORT}"
        if [ "$USER_IPV6" = "true" ]; then
            listen_addr="${listen_addr}, [::]:${USER_PORT_V6}"
        fi

        cat > "$CONFIG_FILE" <<EOF
# Snell Version: v6
# Binary: ${SNELL_BINARY}
[snell-server]
listen = ${listen_addr}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns-ip-preference = ${USER_DNS_PREF}
tfo = ${USER_TFO}

# Snell v6 会自动从 PSK 派生部署级别的协议配置文件
# 不同的 PSK 会产生不同的流量特征
EOF
    fi

    # 设置正确的文件权限，确保 nobody 用户可以读取
    chmod 644 "$CONFIG_FILE"
    print_info "配置文件权限已设置为 644"

    print_info "配置文件已创建: $CONFIG_FILE"
    echo ""
    print_info "=========================================="
    print_info "Snell ${SNELL_CHOICE} 服务器配置信息:"
    print_info "=========================================="
    print_info "服务器地址: ${server_ip}"

    if [ "$SNELL_CHOICE" = "v5" ]; then
        print_info "监听端口: ${USER_PORT}"
    else
        print_info "IPv4 端口: ${USER_PORT}"
        if [ "$USER_IPV6" = "true" ]; then
            print_info "IPv6 端口: ${USER_PORT_V6}"
        fi
    fi

    print_info "密码(PSK): ${USER_PSK}"
    print_info "IPv6: ${USER_IPV6}"

    if [ "$SNELL_CHOICE" = "v5" ]; then
        print_info "DNS: ${USER_DNS}"
    else
        print_info "DNS IP 偏好: ${USER_DNS_PREF}"
    fi

    print_info "版本: Snell ${SNELL_CHOICE}"
    print_info "=========================================="
    echo ""
    print_warning "请妥善保存以上信息，特别是 PSK（密码）"
    echo ""

    # 保存配置信息到文件
    if [ "$SNELL_CHOICE" = "v5" ]; then
        cat > "${CONFIG_DIR}/connection-info.txt" <<EOF
Snell v5 连接信息
==========================================
服务器地址: ${server_ip}
端口: ${USER_PORT}
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS: ${USER_DNS}
TFO: ${USER_TFO}

Surge 配置示例:
==========================================
[Proxy]
Snell = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=5, reuse=true, tfo=${USER_TFO}

注意: Snell v5 稳定版
EOF
    else
        cat > "${CONFIG_DIR}/connection-info.txt" <<EOF
Snell v6 连接信息
==========================================
服务器地址: ${server_ip}
IPv4 端口: ${USER_PORT}
$([ "$USER_IPV6" = "true" ] && echo "IPv6 端口: ${USER_PORT_V6}")
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS IP 偏好: ${USER_DNS_PREF}
TFO: ${USER_TFO}
版本: 6

Surge 配置示例:
==========================================
[Proxy]
Snell-IPv4 = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=6, reuse=true, tfo=${USER_TFO}
$([ "$USER_IPV6" = "true" ] && [ "$USER_PORT_V6" != "$USER_PORT" ] && echo "Snell-IPv6 = snell, ${server_ip}, ${USER_PORT_V6}, psk=${USER_PSK}, version=6, reuse=true, tfo=${USER_TFO}")

注意: Snell v6 仍在 Beta 测试中，需要使用最新的 Surge Beta 版本
EOF
    fi

    chmod 644 "${CONFIG_DIR}/connection-info.txt"
    print_info "连接信息已保存到: ${CONFIG_DIR}/connection-info.txt"
}

# 创建 systemd 服务
create_service() {
    print_info "创建 systemd 服务..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Snell Proxy Service ${SNELL_CHOICE}
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=${SNELL_BINARY} -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_info "Systemd 服务已创建"
}

# 启动服务
start_service() {
    print_info "启动 Snell 服务..."
    systemctl enable snell
    systemctl start snell

    sleep 2

    if systemctl is-active --quiet snell; then
        print_info "Snell 服务启动成功！"
        systemctl status snell --no-pager -l
    else
        print_error "Snell 服务启动失败，请查看日志："
        journalctl -u snell -n 20 --no-pager
        exit 1
    fi
}

# 配置防火墙（可选）
configure_firewall() {
    local port="$USER_PORT"

    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        print_info "检测到 UFW 防火墙，正在添加规则..."
        ufw allow "$port"/tcp
        print_info "UFW 规则已添加"
    elif command -v firewall-cmd &> /dev/null; then
        print_info "检测到 firewalld，正在添加规则..."
        firewall-cmd --permanent --add-port="$port"/tcp
        firewall-cmd --reload
        print_info "Firewalld 规则已添加"
    else
        print_warning "未检测到防火墙，如有需要请手动开放端口 $port"
    fi
}

# 卸载函数
uninstall() {
    print_info "开始卸载 Snell..."

    # 停止并禁用服务
    if systemctl is-active --quiet snell; then
        systemctl stop snell
        print_info "Snell 服务已停止"
    fi

    if systemctl is-enabled --quiet snell 2>/dev/null; then
        systemctl disable snell
        print_info "Snell 服务已禁用"
    fi

    # 删除文件
    [ -f "$SERVICE_FILE" ] && rm -f "$SERVICE_FILE" && print_info "已删除服务文件"
    [ -f "${INSTALL_DIR}/snell-server" ] && rm -f "${INSTALL_DIR}/snell-server" && print_info "已删除程序文件"
    [ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR" && print_info "已删除配置目录"

    systemctl daemon-reload
    print_info "Snell 卸载完成"
}

get_target_version() {
    case "$1" in
        v5)
            echo "$SNELL_VERSION_V5"
            ;;
        v6)
            echo "$SNELL_VERSION_V6"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_default_binary() {
    case "$1" in
        v5)
            echo "${INSTALL_DIR}/snell-server-v5"
            ;;
        v6)
            echo "${INSTALL_DIR}/snell-server-v6"
            ;;
        *)
            echo "${INSTALL_DIR}/snell-server"
            ;;
    esac
}

get_snell_version() {
    local binary_path="$1"

    if [ ! -x "$binary_path" ]; then
        echo "unknown"
        return 0
    fi

    local version
    version=$("$binary_path" --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+[A-Za-z0-9]*' | head -1 || true)
    if [ -z "$version" ]; then
        echo "unknown"
    else
        echo "$version"
    fi
}

infer_choice_from_version() {
    case "$1" in
        v5.*)
            echo "v5"
            ;;
        v6.*)
            echo "v6"
            ;;
        *)
            echo ""
            ;;
    esac
}

infer_choice_from_config() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        echo ""
        return 0
    fi

    if grep -q '^# Snell Version: v5' "$config_file"; then
        echo "v5"
    elif grep -q '^# Snell Version: v6' "$config_file"; then
        echo "v6"
    elif grep -q '^dns-ip-preference[[:space:]]*=' "$config_file"; then
        echo "v6"
    elif grep -q '^dns[[:space:]]*=' "$config_file"; then
        echo "v5"
    else
        echo ""
    fi
}

infer_binary_from_config() {
    local config_file="$1"

    if [ -f "$config_file" ]; then
        local configured_binary
        configured_binary=$(sed -n 's/^# Binary:[[:space:]]*//p' "$config_file" | head -1)
        if [ -n "$configured_binary" ]; then
            echo "$configured_binary"
            return 0
        fi
    fi

    echo ""
}

infer_main_binary() {
    local binary_path=""

    if [ -f "$SERVICE_FILE" ]; then
        binary_path=$(sed -n 's/^ExecStart=\([^[:space:]]*\).*$/\1/p' "$SERVICE_FILE" | head -1)
        if [ -n "$binary_path" ] && [ "$binary_path" != "${INSTALL_DIR}/snell-launcher.sh" ]; then
            echo "$binary_path"
            return 0
        fi
    fi

    binary_path=$(infer_binary_from_config "$CONFIG_FILE")
    if [ -n "$binary_path" ]; then
        echo "$binary_path"
        return 0
    fi

    local config_choice
    config_choice=$(infer_choice_from_config "$CONFIG_FILE")
    if [ -n "$config_choice" ] && [ -f "$(get_default_binary "$config_choice")" ]; then
        get_default_binary "$config_choice"
        return 0
    fi

    if [ -f "${INSTALL_DIR}/snell-server" ]; then
        echo "${INSTALL_DIR}/snell-server"
    elif [ -f "${INSTALL_DIR}/snell-server-v6" ]; then
        echo "${INSTALL_DIR}/snell-server-v6"
    elif [ -f "${INSTALL_DIR}/snell-server-v5" ]; then
        echo "${INSTALL_DIR}/snell-server-v5"
    else
        echo ""
    fi
}

download_snell_archive() {
    local choice="$1"
    local zip_file="$2"
    local target_version
    target_version=$(get_target_version "$choice")

    if [ -z "$target_version" ]; then
        print_error "无法确定 Snell 目标版本"
        return 1
    fi

    local download_url="https://dl.nssurge.com/snell/snell-server-${target_version}-linux-${ARCH}.zip"
    print_info "下载地址: $download_url"

    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$zip_file" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -fL -o "$zip_file" "$download_url"
    else
        print_error "未找到 wget 或 curl，请先安装其中之一"
        return 1
    fi
}

update_snell_binary() {
    local binary_path="$1"
    local choice="$2"
    local label="$3"
    shift 3
    local services=("$@")
    local target_version
    target_version=$(get_target_version "$choice")

    if [ -z "$binary_path" ]; then
        print_error "未找到需要更新的 Snell 二进制文件"
        return 1
    fi

    if [ -z "$target_version" ]; then
        print_error "无法确定 ${label} 的目标版本"
        return 1
    fi

    if [ ! -f "$binary_path" ]; then
        print_error "二进制文件不存在: $binary_path"
        return 1
    fi

    local current_version
    current_version=$(get_snell_version "$binary_path")
    print_info "${label}: $binary_path"
    print_info "当前版本: $current_version"
    print_info "最新版本: $target_version"

    if [ "$current_version" = "$target_version" ]; then
        print_info "${label} 已是最新版本"
        return 0
    fi

    echo ""
    print_prompt "发现新版本，是否更新 ${label}? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消更新"
        return 0
    fi

    print_info "开始更新 ${label}..."
    detect_architecture

    local active_services=()
    local service_name
    for service_name in "${services[@]}"; do
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            active_services+=("$service_name")
            systemctl stop "$service_name" 2>/dev/null || true
            print_info "已停止服务: $service_name"
        fi
    done

    local backup_file="${binary_path}.backup"
    cp "$binary_path" "$backup_file"
    print_info "已备份当前版本"

    local temp_dir
    temp_dir=$(mktemp -d)
    local zip_file="${temp_dir}/snell-server.zip"

    if ! download_snell_archive "$choice" "$zip_file"; then
        print_error "下载失败，恢复备份"
        mv "$backup_file" "$binary_path"
        rm -rf "$temp_dir"
        for service_name in "${active_services[@]}"; do
            systemctl start "$service_name" 2>/dev/null || true
        done
        return 1
    fi

    if ! unzip -q "$zip_file" -d "$temp_dir"; then
        print_error "解压失败，恢复备份"
        mv "$backup_file" "$binary_path"
        rm -rf "$temp_dir"
        for service_name in "${active_services[@]}"; do
            systemctl start "$service_name" 2>/dev/null || true
        done
        return 1
    fi

    if [ ! -f "${temp_dir}/snell-server" ]; then
        print_error "压缩包中未找到 snell-server，恢复备份"
        mv "$backup_file" "$binary_path"
        rm -rf "$temp_dir"
        for service_name in "${active_services[@]}"; do
            systemctl start "$service_name" 2>/dev/null || true
        done
        return 1
    fi

    mv "${temp_dir}/snell-server" "$binary_path"
    chmod +x "$binary_path"
    rm -rf "$temp_dir"

    local failed_service=""
    for service_name in "${active_services[@]}"; do
        systemctl start "$service_name" 2>/dev/null || failed_service="$service_name"
    done

    sleep 2
    for service_name in "${active_services[@]}"; do
        if ! systemctl is-active --quiet "$service_name" 2>/dev/null; then
            failed_service="$service_name"
            break
        fi
    done

    if [ -n "$failed_service" ]; then
        print_error "服务启动失败: $failed_service，恢复备份"
        mv "$backup_file" "$binary_path"
        for service_name in "${active_services[@]}"; do
            systemctl start "$service_name" 2>/dev/null || true
        done
        return 1
    fi

    rm -f "$backup_file"
    local new_version
    new_version=$(get_snell_version "$binary_path")
    print_info "更新成功！"
    print_info "新版本: $new_version"
}

# 检查更新函数
check_update() {
    print_info "检查 Snell 更新..."

    local binary_path
    binary_path=$(infer_main_binary)

    if [ -z "$binary_path" ] || [ ! -f "$binary_path" ]; then
        print_error "Snell 未安装，请先运行安装"
        exit 1
    fi

    local choice
    choice=$(infer_choice_from_config "$CONFIG_FILE")

    if [ -z "$choice" ]; then
        local current_version
        current_version=$(get_snell_version "$binary_path")
        choice=$(infer_choice_from_version "$current_version")
    fi

    if [ -z "$choice" ]; then
        print_warning "无法自动判断当前 Snell 主服务版本"
        select_snell_version
        choice="$SNELL_CHOICE"
    fi

    SNELL_CHOICE="$choice"
    SNELL_VERSION=$(get_target_version "$choice")
    SNELL_BINARY="$binary_path"

    update_snell_binary "$binary_path" "$choice" "Snell 主服务" "snell"
}

# 查看配置函数
show_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    echo ""
    print_info "=========================================="
    print_info "Snell 配置文件: $CONFIG_FILE"
    print_info "=========================================="
    cat "$CONFIG_FILE"
    echo ""

    if [ -f "${CONFIG_DIR}/connection-info.txt" ]; then
        print_info "=========================================="
        print_info "连接信息"
        print_info "=========================================="
        cat "${CONFIG_DIR}/connection-info.txt"
        echo ""
    fi
}

# 修改配置函数
modify_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在，请先安装 Snell"
        return 1
    fi

    print_info "当前配置内容:"
    echo ""
    cat "$CONFIG_FILE"
    echo ""

    # 读取当前配置
    local current_port=$(grep -oP 'listen = 0\.0\.0\.0:\K\d+' "$CONFIG_FILE" | head -1)
    local current_port_v6=$(grep -oP 'listen = .*\[::\]:\K\d+' "$CONFIG_FILE" | head -1)
    local current_psk=$(grep -oP 'psk = \K.*' "$CONFIG_FILE")
    local current_ipv6=$(grep -oP 'ipv6 = \K.*' "$CONFIG_FILE")
    local current_dns=$(grep -oP 'dns-ip-preference = \K.*' "$CONFIG_FILE")

    print_info "=========================================="
    print_info "当前配置:"
    print_info "IPv4 端口: $current_port"
    if [ -n "$current_port_v6" ]; then
        print_info "IPv6 端口: $current_port_v6"
    fi
    print_info "PSK: $current_psk"
    print_info "IPv6: $current_ipv6"
    print_info "DNS IP 偏好: $current_dns"
    print_info "=========================================="
    echo ""

    # 获取新的 IPv4 端口
    print_prompt "请输入新的 IPv4 监听端口 (回车保持不变 $current_port): "
    read -r input_port
    if [ -z "$input_port" ]; then
        USER_PORT="$current_port"
    else
        if [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 6000 ] && [ "$input_port" -le 65535 ]; then
            USER_PORT="$input_port"
        else
            print_error "无效的端口号，保持原端口: $current_port"
            USER_PORT="$current_port"
        fi
    fi

    # 获取 IPv6 配置
    echo ""
    print_prompt "是否启用 IPv6? (y/n, 回车保持当前: $current_ipv6): "
    read -r input_ipv6
    if [ -z "$input_ipv6" ]; then
        USER_IPV6="$current_ipv6"
    else
        if [[ "$input_ipv6" =~ ^[Yy]$ ]]; then
            USER_IPV6="true"
        else
            USER_IPV6="false"
        fi
    fi

    # 如果启用 IPv6，询问端口
    if [ "$USER_IPV6" = "true" ]; then
        echo ""
        if [ -n "$current_port_v6" ]; then
            print_prompt "IPv6 是否使用与 IPv4 相同的端口 $USER_PORT? (y/n, 当前 IPv6 端口: $current_port_v6): "
        else
            print_prompt "IPv6 是否使用与 IPv4 相同的端口 $USER_PORT? (y/n, 默认: y): "
        fi
        read -r same_port
        if [[ "$same_port" =~ ^[Yy]$ ]] || [ -z "$same_port" ]; then
            USER_PORT_V6="$USER_PORT"
            print_info "IPv6 使用相同端口: $USER_PORT_V6"
        else
            local default_v6=${current_port_v6:-$(generate_port)}
            print_prompt "请输入 IPv6 监听端口 (回车保持 $default_v6): "
            read -r input_port_v6
            if [ -z "$input_port_v6" ]; then
                USER_PORT_V6="$default_v6"
            else
                if [[ "$input_port_v6" =~ ^[0-9]+$ ]] && [ "$input_port_v6" -ge 6000 ] && [ "$input_port_v6" -le 65535 ]; then
                    USER_PORT_V6="$input_port_v6"
                else
                    print_error "无效的端口号，使用: $default_v6"
                    USER_PORT_V6="$default_v6"
                fi
            fi
        fi
    else
        USER_PORT_V6=""
    fi

    # 获取新 PSK
    echo ""
    print_prompt "请输入新的 PSK 密码 (回车保持不变): "
    read -r input_psk
    if [ -z "$input_psk" ]; then
        USER_PSK="$current_psk"
    else
        USER_PSK="$input_psk"
    fi

    # 获取 DNS IP 偏好
    echo ""
    print_info "DNS IP 偏好选项:"
    print_info "  1) default"
    print_info "  2) prefer-ipv4"
    print_info "  3) prefer-ipv6"
    print_info "  4) ipv4-only"
    print_info "  5) ipv6-only"
    echo ""
    print_prompt "请选择 DNS IP 偏好 (回车保持当前: $current_dns): "
    read -r input_dns
    if [ -z "$input_dns" ]; then
        USER_DNS_PREF="$current_dns"
    else
        case "$input_dns" in
            1)
                USER_DNS_PREF="default"
                ;;
            2)
                USER_DNS_PREF="prefer-ipv4"
                ;;
            3)
                USER_DNS_PREF="prefer-ipv6"
                ;;
            4)
                USER_DNS_PREF="ipv4-only"
                ;;
            5)
                USER_DNS_PREF="ipv6-only"
                ;;
            *)
                USER_DNS_PREF="$current_dns"
                ;;
        esac
    fi

    echo ""
    print_info "=========================================="
    print_info "新配置:"
    print_info "IPv4 端口: $USER_PORT"
    if [ "$USER_IPV6" = "true" ]; then
        print_info "IPv6 端口: $USER_PORT_V6"
    fi
    print_info "PSK: $USER_PSK"
    print_info "IPv6: $USER_IPV6"
    print_info "DNS IP 偏好: $USER_DNS_PREF"
    print_info "=========================================="
    echo ""
    print_prompt "确认修改配置? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消修改"
        return 0
    fi

    # 获取服务器 IP
    local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")

    # 构建监听地址
    local listen_addr="0.0.0.0:${USER_PORT}"
    if [ "$USER_IPV6" = "true" ]; then
        listen_addr="${listen_addr}, [::]:${USER_PORT_V6}"
    fi

    # 备份旧配置
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    print_info "已备份原配置到: ${CONFIG_FILE}.backup"

    # 写入新配置
    cat > "$CONFIG_FILE" <<EOF
[snell-server]
listen = ${listen_addr}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns-ip-preference = ${USER_DNS_PREF}

# Snell v6 会自动从 PSK 派生部署级别的协议配置文件
# 不同的 PSK 会产生不同的流量特征
EOF

    chmod 644 "$CONFIG_FILE"
    print_info "配置文件已更新"

    # 更新连接信息文件
    cat > "${CONFIG_DIR}/connection-info.txt" <<EOF
Snell v6 连接信息
==========================================
服务器地址: ${server_ip}
IPv4 端口: ${USER_PORT}
$([ "$USER_IPV6" = "true" ] && echo "IPv6 端口: ${USER_PORT_V6}")
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS IP 偏好: ${USER_DNS_PREF}
版本: 6

Surge 配置示例:
==========================================
[Proxy]
Snell-IPv4 = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=6
$([ "$USER_IPV6" = "true" ] && [ "$USER_PORT_V6" != "$USER_PORT" ] && echo "Snell-IPv6 = snell, ${server_ip}, ${USER_PORT_V6}, psk=${USER_PSK}, version=6")

注意: Snell v6 仍在 Beta 测试中，需要使用最新的 Surge Beta 版本
EOF

    chmod 644 "${CONFIG_DIR}/connection-info.txt"

    # 重启服务
    echo ""
    print_info "正在重启 Snell 服务以应用新配置..."
    systemctl restart snell
    sleep 2

    if systemctl is-active --quiet snell; then
        print_info "服务重启成功！新配置已生效"
        systemctl status snell --no-pager -l
    else
        print_error "服务启动失败，正在恢复原配置..."
        mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
        systemctl restart snell
        print_error "已恢复原配置，请检查配置是否正确"
    fi
}

# 启动服务函数
start_snell() {
    print_info "启动 Snell 服务..."
    systemctl start snell
    sleep 2
    systemctl status snell --no-pager -l
}

# 停止服务函数
stop_snell() {
    print_info "停止 Snell 服务..."
    systemctl stop snell
    print_info "Snell 服务已停止"
}

# ============================================
# 多用户管理功能
# ============================================

# 列出所有用户
list_users() {
    echo ""
    print_info "=========================================="
    print_info "Snell 用户列表"
    print_info "=========================================="
    echo ""

    # 主用户
    if systemctl list-units --type=service --all | grep -q "^snell.service"; then
        local status=$(systemctl is-active snell.service)
        local port=$(grep -oP 'listen = 0\.0\.0\.0:\K\d+' "$CONFIG_FILE" 2>/dev/null || echo "N/A")
        printf "  %-20s %-10s %-10s\n" "default (主用户)" "$port" "$status"
    fi

    # 多用户
    if [ -d "$MULTI_USER_DIR" ]; then
        for user_conf in "$MULTI_USER_DIR"/*.conf; do
            if [ -f "$user_conf" ]; then
                local username=$(basename "$user_conf" .conf)
                local service_name="snell@${username}.service"
                local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "inactive")
                local port=$(grep -oP 'listen = 0\.0\.0\.0:\K\d+' "$user_conf" 2>/dev/null || echo "N/A")
                printf "  %-20s %-10s %-10s\n" "$username" "$port" "$status"
            fi
        done
    fi

    echo ""
    print_info "使用方法："
    print_info "  systemctl start snell           # 启动主用户"
    print_info "  systemctl start snell@user1     # 启动指定用户"
    echo ""
}

# 添加用户
add_user() {
    echo ""
    print_info "=========================================="
    print_info "添加新用户"
    print_info "=========================================="
    echo ""

    # 输入用户名
    print_prompt "请输入用户名 (字母数字下划线，如: user1): "
    read -r username

    if [ -z "$username" ]; then
        print_error "用户名不能为空"
        return 1
    fi

    # 验证用户名格式
    if ! [[ "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "用户名只能包含字母、数字和下划线"
        return 1
    fi

    # 检查用户是否已存在
    if [ "$username" = "default" ] || [ -f "${MULTI_USER_DIR}/${username}.conf" ]; then
        print_error "用户 $username 已存在"
        return 1
    fi

    CURRENT_USER="$username"

    # 创建多用户目录
    mkdir -p "$MULTI_USER_DIR"

    # 选择版本
    select_snell_version

    # 设置二进制文件路径
    if [ "$SNELL_CHOICE" = "v5" ]; then
        SNELL_BINARY="${INSTALL_DIR}/snell-server-v5"
    else
        SNELL_BINARY="${INSTALL_DIR}/snell-server-v6"
    fi

    # 检查对应版本的二进制文件是否存在，不存在则下载
    if [ ! -f "$SNELL_BINARY" ]; then
        print_warning "未找到 Snell ${SNELL_CHOICE} 二进制文件，开始下载..."
        detect_architecture
        download_snell
    else
        print_info "使用已安装的 Snell ${SNELL_CHOICE}: $SNELL_BINARY"
    fi

    # 获取配置
    get_user_config

    # 获取服务器 IP
    local server_ip=$(curl -s4m5 ip.sb 2>/dev/null || echo "YOUR_SERVER_IP")

    # 创建用户配置文件
    local user_config="${MULTI_USER_DIR}/${username}.conf"

    if [ "$SNELL_CHOICE" = "v5" ]; then
        # v5 配置格式
        cat > "$user_config" <<EOF
# Snell Version: v5
# Binary: ${SNELL_BINARY}
[snell-server]
listen = ::0:${USER_PORT}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns = ${USER_DNS}
tfo = ${USER_TFO}
EOF
    else
        # v6 配置格式
        local listen_addr="0.0.0.0:${USER_PORT}"
        if [ "$USER_IPV6" = "true" ]; then
            listen_addr="${listen_addr}, [::]:${USER_PORT_V6}"
        fi

        cat > "$user_config" <<EOF
# Snell Version: v6
# Binary: ${SNELL_BINARY}
[snell-server]
listen = ${listen_addr}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns-ip-preference = ${USER_DNS_PREF}
tfo = ${USER_TFO}

# Snell v6 会自动从 PSK 派生部署级别的协议配置文件
# 不同的 PSK 会产生不同的流量特征
EOF
    fi

    chmod 644 "$user_config"
    print_info "用户配置已创建: $user_config"

    # 创建用户连接信息文件
    if [ "$SNELL_CHOICE" = "v5" ]; then
        cat > "${MULTI_USER_DIR}/${username}-info.txt" <<EOF
Snell v5 用户: ${username}
==========================================
服务器地址: ${server_ip}
端口: ${USER_PORT}
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS: ${USER_DNS}
TFO: ${USER_TFO}

Surge 配置示例:
==========================================
[Proxy]
Snell-${username} = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=5, reuse=true, tfo=${USER_TFO}

服务管理:
==========================================
启动: systemctl start snell@${username}
停止: systemctl stop snell@${username}
重启: systemctl restart snell@${username}
状态: systemctl status snell@${username}
EOF
    else
        cat > "${MULTI_USER_DIR}/${username}-info.txt" <<EOF
Snell v6 用户: ${username}
==========================================
服务器地址: ${server_ip}
IPv4 端口: ${USER_PORT}
$([ "$USER_IPV6" = "true" ] && echo "IPv6 端口: ${USER_PORT_V6}")
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS IP 偏好: ${USER_DNS_PREF}
TFO: ${USER_TFO}
版本: 6

Surge 配置示例:
==========================================
[Proxy]
Snell-${username}-IPv4 = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=6, reuse=true, tfo=${USER_TFO}
$([ "$USER_IPV6" = "true" ] && [ "$USER_PORT_V6" != "$USER_PORT" ] && echo "Snell-${username}-IPv6 = snell, ${server_ip}, ${USER_PORT_V6}, psk=${USER_PSK}, version=6, reuse=true, tfo=${USER_TFO}")

服务管理:
==========================================
启动: systemctl start snell@${username}
停止: systemctl stop snell@${username}
重启: systemctl restart snell@${username}
状态: systemctl status snell@${username}
EOF
    fi

    chmod 644 "${MULTI_USER_DIR}/${username}-info.txt"

    # 创建 systemd 模板服务（强制更新以支持 v5/v6 混合部署）
    local template_service="/etc/systemd/system/snell@.service"

    # 创建启动脚本来解析配置文件中的二进制路径
    cat > "${INSTALL_DIR}/snell-launcher.sh" <<'LAUNCHER_EOF'
#!/bin/bash
# Snell 启动器 - 从配置文件读取正确的二进制路径

CONFIG_FILE="$1"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 从配置文件中读取二进制路径
BINARY_PATH=$(grep "^# Binary:" "$CONFIG_FILE" | cut -d' ' -f3)

if [ -z "$BINARY_PATH" ] || [ ! -f "$BINARY_PATH" ]; then
    # 如果没有找到或文件不存在，尝试检测版本
    if grep -q "^# Snell Version: v5" "$CONFIG_FILE"; then
        BINARY_PATH="/usr/local/bin/snell-server-v5"
    elif grep -q "^# Snell Version: v6" "$CONFIG_FILE"; then
        BINARY_PATH="/usr/local/bin/snell-server-v6"
    else
        # 向后兼容：尝试使用默认路径
        BINARY_PATH="/usr/local/bin/snell-server"
    fi
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "找不到 Snell 二进制文件: $BINARY_PATH"
    exit 1
fi

# 执行 snell-server
exec "$BINARY_PATH" -c "$CONFIG_FILE"
LAUNCHER_EOF

    chmod +x "${INSTALL_DIR}/snell-launcher.sh"
    print_info "已创建 Snell 启动器脚本"

    # 始终重新创建模板服务
    cat > "$template_service" <<EOF
[Unit]
Description=Snell Proxy Service - %i
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=${INSTALL_DIR}/snell-launcher.sh ${MULTI_USER_DIR}/%i.conf
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    print_info "已更新 systemd 模板服务"

    # 启动用户服务
    echo ""
    print_info "启动用户 ${username} 的服务..."
    systemctl enable "snell@${username}"
    systemctl start "snell@${username}"
    sleep 2

    if systemctl is-active --quiet "snell@${username}"; then
        print_info "用户 ${username} 服务启动成功！"
        echo ""
        cat "${MULTI_USER_DIR}/${username}-info.txt"
    else
        print_error "用户 ${username} 服务启动失败"
        journalctl -u "snell@${username}" -n 10 --no-pager
    fi

    # 配置防火墙
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow "${USER_PORT}"/tcp
        [ "$USER_IPV6" = "true" ] && [ "$USER_PORT_V6" != "$USER_PORT" ] && [ "$SNELL_CHOICE" = "v6" ] && ufw allow "${USER_PORT_V6}"/tcp
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port="${USER_PORT}"/tcp
        [ "$USER_IPV6" = "true" ] && [ "$USER_PORT_V6" != "$USER_PORT" ] && [ "$SNELL_CHOICE" = "v6" ] && firewall-cmd --permanent --add-port="${USER_PORT_V6}"/tcp
        firewall-cmd --reload
    fi
}

# 删除用户
delete_user() {
    echo ""
    print_info "=========================================="
    print_info "删除用户"
    print_info "=========================================="
    echo ""

    # 列出用户
    if [ ! -d "$MULTI_USER_DIR" ] || [ -z "$(ls -A $MULTI_USER_DIR/*.conf 2>/dev/null)" ]; then
        print_error "没有可删除的用户"
        return 1
    fi

    print_info "现有用户列表："
    local i=1
    declare -a user_list
    for user_conf in "$MULTI_USER_DIR"/*.conf; do
        if [ -f "$user_conf" ]; then
            local username=$(basename "$user_conf" .conf)
            user_list[$i]="$username"
            echo "  $i) $username"
            ((i++))
        fi
    done

    echo ""
    print_prompt "请输入要删除的用户编号: "
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        print_error "无效的选择"
        return 1
    fi

    local username="${user_list[$choice]}"
    echo ""
    print_warning "警告: 将删除用户 ${username} 及其所有配置"
    print_prompt "确认删除? (y/n): "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消删除"
        return 0
    fi

    # 停止并禁用服务
    systemctl stop "snell@${username}" 2>/dev/null
    systemctl disable "snell@${username}" 2>/dev/null
    print_info "已停止服务"

    # 删除配置文件
    rm -f "${MULTI_USER_DIR}/${username}.conf"
    rm -f "${MULTI_USER_DIR}/${username}-info.txt"
    print_info "已删除配置文件"

    systemctl daemon-reload
    print_info "用户 ${username} 已删除"
}

# 查看用户信息
show_user_info() {
    echo ""
    print_info "=========================================="
    print_info "查看用户信息"
    print_info "=========================================="
    echo ""

    if [ ! -d "$MULTI_USER_DIR" ] || [ -z "$(ls -A $MULTI_USER_DIR/*.conf 2>/dev/null)" ]; then
        print_error "没有多用户配置"
        return 1
    fi

    print_info "选择用户："
    local i=1
    declare -a user_list
    for user_conf in "$MULTI_USER_DIR"/*.conf; do
        if [ -f "$user_conf" ]; then
            local username=$(basename "$user_conf" .conf)
            user_list[$i]="$username"
            echo "  $i) $username"
            ((i++))
        fi
    done

    echo ""
    print_prompt "请输入用户编号: "
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        print_error "无效的选择"
        return 1
    fi

    local username="${user_list[$choice]}"
    echo ""

    if [ -f "${MULTI_USER_DIR}/${username}-info.txt" ]; then
        cat "${MULTI_USER_DIR}/${username}-info.txt"
    else
        print_error "未找到用户 ${username} 的信息文件"
    fi
}

multi_user_has_choice() {
    local choice="$1"
    local user_conf

    if [ ! -d "$MULTI_USER_DIR" ]; then
        return 1
    fi

    for user_conf in "$MULTI_USER_DIR"/*.conf; do
        if [ -f "$user_conf" ] && [ "$(infer_choice_from_config "$user_conf")" = "$choice" ]; then
            return 0
        fi
    done

    return 1
}

update_multi_user_version() {
    local choice="$1"
    local target_name="Snell ${choice}"

    if ! multi_user_has_choice "$choice"; then
        print_warning "未找到 ${target_name} 多用户配置"
        return 0
    fi

    local handled_binaries=""
    local user_conf
    for user_conf in "$MULTI_USER_DIR"/*.conf; do
        if [ ! -f "$user_conf" ] || [ "$(infer_choice_from_config "$user_conf")" != "$choice" ]; then
            continue
        fi

        local binary_path
        binary_path=$(infer_binary_from_config "$user_conf")
        if [ -z "$binary_path" ]; then
            binary_path=$(get_default_binary "$choice")
        fi

        case " $handled_binaries " in
            *" $binary_path "*)
                continue
                ;;
        esac
        handled_binaries="${handled_binaries} ${binary_path}"

        local services=()
        local matched_conf
        for matched_conf in "$MULTI_USER_DIR"/*.conf; do
            if [ ! -f "$matched_conf" ] || [ "$(infer_choice_from_config "$matched_conf")" != "$choice" ]; then
                continue
            fi

            local matched_binary
            matched_binary=$(infer_binary_from_config "$matched_conf")
            if [ -z "$matched_binary" ]; then
                matched_binary=$(get_default_binary "$choice")
            fi

            if [ "$matched_binary" = "$binary_path" ]; then
                local username
                username=$(basename "$matched_conf" .conf)
                services+=("snell@${username}")
            fi
        done

        update_snell_binary "$binary_path" "$choice" "多用户 ${target_name}" "${services[@]}" || return 1
    done
}

check_multi_user_update() {
    echo ""
    print_info "=========================================="
    print_info "检查多用户 Snell 更新"
    print_info "=========================================="
    echo ""

    if [ ! -d "$MULTI_USER_DIR" ] || [ -z "$(ls -A "$MULTI_USER_DIR"/*.conf 2>/dev/null)" ]; then
        print_error "没有多用户配置"
        return 1
    fi

    print_info "请选择要更新的多用户版本:"
    echo "  1) Snell v5"
    echo "  2) Snell v6"
    echo "  3) 全部"
    echo ""
    print_prompt "请输入选项 [1-3]: "
    read -r choice

    case "$choice" in
        1)
            update_multi_user_version "v5"
            ;;
        2)
            update_multi_user_version "v6"
            ;;
        3)
            local updated=0
            if multi_user_has_choice "v5"; then
                update_multi_user_version "v5"
                updated=1
            fi
            if multi_user_has_choice "v6"; then
                update_multi_user_version "v6"
                updated=1
            fi
            if [ "$updated" -eq 0 ]; then
                print_error "没有可更新的多用户配置"
                return 1
            fi
            ;;
        *)
            print_error "无效的选项"
            return 1
            ;;
    esac
}

# 显示主菜单
show_menu() {
    clear
    echo ""
    echo -e "${CYAN}=========================================="
    echo -e "    Snell v5/v6 一键部署管理脚本"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "${GREEN}请选择要执行的操作:${NC}"
    echo ""
    echo -e "${YELLOW}基础管理:${NC}"
    echo "  1) 安装 Snell (支持 v5/v6)"
    echo "  2) 启动 Snell 服务"
    echo "  3) 停止 Snell 服务"
    echo "  4) 重启 Snell 服务"
    echo "  5) 查看服务状态"
    echo "  6) 查看实时日志"
    echo "  7) 查看配置信息"
    echo "  8) 查看连接信息"
    echo "  9) 修改配置"
    echo " 10) 检查更新"
    echo " 11) 卸载 Snell"
    echo ""
    echo -e "${YELLOW}多用户管理:${NC}"
    echo " 12) 列出所有用户"
    echo " 13) 添加新用户 (支持 v5/v6)"
    echo " 14) 删除用户"
    echo " 15) 查看用户信息"
    echo " 16) 检查多用户更新"
    echo ""
    echo "  0) 退出"
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# 显示使用帮助
show_help() {
    cat <<EOF
Snell v6 一键部署脚本

用法: $0 [命令]

基础命令:
    install     安装并配置 Snell v6 服务器
    uninstall   卸载 Snell 服务器
    update      检查并更新 Snell 到最新版本
    modify      修改配置
    start       启动 Snell 服务
    stop        停止 Snell 服务
    restart     重启 Snell 服务
    status      查看 Snell 服务状态
    log         查看 Snell 服务日志
    config      查看 Snell 配置
    info        显示连接信息

多用户命令:
    list        列出所有用户
    adduser     添加新用户
    deluser     删除用户
    userinfo    查看用户信息
    update-users 检查并更新多用户 Snell

其他命令:
    help        显示此帮助信息

示例:
    $0              # 显示交互式菜单
    $0 install      # 直接安装 Snell
    $0 adduser      # 添加新用户
    $0 list         # 列出所有用户
    $0 status       # 直接查看状态

EOF
}

# 主函数
main() {
    # 如果没有参数，显示交互式菜单
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            print_prompt "请输入选项 [0-16]: "
            read -r choice

            case $choice in
                1)
                    check_root
                    print_info "开始安装 Snell..."
                    detect_architecture
                    select_snell_version
                    get_user_config
                    download_snell
                    create_config
                    create_service
                    start_service
                    configure_firewall
                    echo ""
                    print_info "=========================================="
                    print_info "Snell ${SNELL_CHOICE} 安装完成！"
                    print_info "=========================================="
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                2)
                    check_root
                    start_snell
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                3)
                    check_root
                    stop_snell
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                4)
                    check_root
                    echo ""
                    print_prompt "确认重启 Snell 服务? (y/n): "
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        print_info "重启 Snell 服务..."
                        systemctl restart snell
                        sleep 2
                        systemctl status snell --no-pager
                    else
                        print_info "已取消重启"
                    fi
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                5)
                    systemctl status snell --no-pager -l
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                6)
                    echo ""
                    print_info "即将进入日志查看模式（按 Ctrl+C 返回菜单）"
                    print_prompt "继续查看实时日志? (y/n): "
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        journalctl -u snell -f
                    fi
                    ;;
                7)
                    show_config
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                8)
                    if [ -f "${CONFIG_DIR}/connection-info.txt" ]; then
                        echo ""
                        cat "${CONFIG_DIR}/connection-info.txt"
                    else
                        print_error "未找到连接信息文件，请确认 Snell 已安装"
                    fi
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                9)
                    check_root
                    modify_config
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                10)
                    check_root
                    check_update
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                11)
                    check_root
                    uninstall
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                12)
                    list_users
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                13)
                    check_root
                    add_user
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                14)
                    check_root
                    delete_user
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                15)
                    show_user_info
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                16)
                    check_root
                    check_multi_user_update
                    echo ""
                    print_prompt "按回车键返回主菜单..."
                    read
                    ;;
                0)
                    print_info "退出脚本"
                    exit 0
                    ;;
                *)
                    print_error "无效的选项，请输入 0-16"
                    sleep 2
                    ;;
            esac
        done
    fi

    # 如果有参数，直接执行对应命令
    local action="$1"

    case $action in
        install)
            check_root
            print_info "开始安装 Snell..."
            detect_architecture
            select_snell_version
            get_user_config
            download_snell
            create_config
            create_service
            start_service
            configure_firewall
            echo ""
            print_info "=========================================="
            print_info "Snell ${SNELL_CHOICE} 安装完成！"
            print_info "=========================================="
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        update)
            check_root
            check_update
            ;;
        modify)
            check_root
            modify_config
            ;;
        start)
            check_root
            start_snell
            ;;
        stop)
            check_root
            stop_snell
            ;;
        restart)
            check_root
            echo ""
            print_prompt "确认重启 Snell 服务? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                print_info "已取消重启"
                exit 0
            fi
            print_info "重启 Snell 服务..."
            systemctl restart snell
            sleep 2
            systemctl status snell --no-pager
            ;;
        status)
            echo ""
            print_prompt "查看 Snell 服务状态? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            systemctl status snell --no-pager -l
            ;;
        log)
            echo ""
            print_info "即将进入日志查看模式（按 Ctrl+C 退出）"
            print_prompt "继续查看实时日志? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            journalctl -u snell -f
            ;;
        config)
            echo ""
            print_prompt "查看 Snell 配置? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            show_config
            ;;
        info)
            echo ""
            print_prompt "查看连接信息? (y/n): "
            read -r confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            if [ -f "${CONFIG_DIR}/connection-info.txt" ]; then
                cat "${CONFIG_DIR}/connection-info.txt"
            else
                print_error "未找到连接信息文件，请确认 Snell 已安装"
                exit 1
            fi
            ;;
        list)
            list_users
            ;;
        adduser)
            check_root
            add_user
            ;;
        deluser)
            check_root
            delete_user
            ;;
        userinfo)
            show_user_info
            ;;
        update-users|updateusers|updateuser)
            check_root
            check_multi_user_update
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $action"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
