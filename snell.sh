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
SNELL_VERSION="v6.0.0b2"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/snell"
CONFIG_FILE="${CONFIG_DIR}/snell-server.conf"
SERVICE_FILE="/etc/systemd/system/snell.service"
 
# 用户配置变量
USER_PORT=""
USER_PSK=""
USER_IPV6="true"
USER_DNS_PREF="default"
 
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
        *)
            print_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    print_info "检测到系统架构: $arch -> $ARCH"
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
    print_info "Snell v6 配置向导"
    print_info "=========================================="
    echo ""
    print_info "提示: 直接按回车将使用随机生成的值"
    echo ""
 
    # 获取端口
    local default_port=$(generate_port)
    print_prompt "请输入监听端口 (默认: $default_port, 范围: 6000-65535): "
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
        print_info "IPv6: 已启用"
    else
        USER_IPV6="false"
        print_info "IPv6: 已禁用"
    fi
 
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
 
    echo ""
    print_info "=========================================="
    print_info "配置确认"
    print_info "=========================================="
    print_info "端口: $USER_PORT"
    print_info "PSK: $USER_PSK"
    print_info "IPv6: $USER_IPV6"
    print_info "DNS IP 偏好: $USER_DNS_PREF"
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
    local download_url="https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${ARCH}.zip"
    local temp_dir=$(mktemp -d)
    local zip_file="${temp_dir}/snell-server.zip"
 
    print_info "开始下载 Snell 服务器..."
    print_info "下载地址: $download_url"
 
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$zip_file" "$download_url" || {
            print_error "下载失败"
            rm -rf "$temp_dir"
            exit 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "$zip_file" "$download_url" || {
            print_error "下载失败"
            rm -rf "$temp_dir"
            exit 1
        }
    else
        print_error "未找到 wget 或 curl，请先安装其中之一"
        rm -rf "$temp_dir"
        exit 1
    fi
 
    print_info "解压文件..."
    unzip -q "$zip_file" -d "$temp_dir" || {
        print_error "解压失败"
        rm -rf "$temp_dir"
        exit 1
    }
 
    print_info "安装 Snell 服务器到 $INSTALL_DIR..."
    mv "${temp_dir}/snell-server" "$INSTALL_DIR/snell-server"
    chmod +x "${INSTALL_DIR}/snell-server"
 
    rm -rf "$temp_dir"
    print_info "Snell 服务器安装完成"
}
 
# 创建配置文件
create_config() {
    print_info "创建配置文件..."
 
    mkdir -p "$CONFIG_DIR"
 
    # 获取服务器 IP
    local server_ip=$(curl -s4m5 ifconfig.co 2>/dev/null || curl -s4m5 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")
 
    # 构建监听地址
    local listen_addr="0.0.0.0:${USER_PORT}"
    if [ "$USER_IPV6" = "true" ]; then
        listen_addr="${listen_addr}, [::]:${USER_PORT}"
    fi
 
    # 创建配置文件
    cat > "$CONFIG_FILE" <<EOF
[snell-server]
listen = ${listen_addr}
psk = ${USER_PSK}
ipv6 = ${USER_IPV6}
dns-ip-preference = ${USER_DNS_PREF}
 
# Snell v6 会自动从 PSK 派生部署级别的协议配置文件
# 不同的 PSK 会产生不同的流量特征
EOF
 
    # 设置正确的文件权限，确保 nobody 用户可以读取
    chmod 644 "$CONFIG_FILE"
    print_info "配置文件权限已设置为 644"
 
    print_info "配置文件已创建: $CONFIG_FILE"
    echo ""
    print_info "=========================================="
    print_info "Snell 服务器配置信息:"
    print_info "=========================================="
    print_info "服务器地址: ${server_ip}"
    print_info "监听端口: ${USER_PORT}"
    print_info "密码(PSK): ${USER_PSK}"
    print_info "IPv6: ${USER_IPV6}"
    print_info "DNS IP 偏好: ${USER_DNS_PREF}"
    print_info "版本: Snell v6"
    print_info "=========================================="
    echo ""
    print_warning "请妥善保存以上信息，特别是 PSK（密码）"
    echo ""
 
    # 保存配置信息到文件
    cat > "${CONFIG_DIR}/connection-info.txt" <<EOF
Snell v6 连接信息
==========================================
服务器地址: ${server_ip}
端口: ${USER_PORT}
密码(PSK): ${USER_PSK}
IPv6: ${USER_IPV6}
DNS IP 偏好: ${USER_DNS_PREF}
版本: 6
 
Surge 配置示例:
==========================================
[Proxy]
Snell = snell, ${server_ip}, ${USER_PORT}, psk=${USER_PSK}, version=6
 
注意: Snell v6 仍在 Beta 测试中，需要使用最新的 Surge Beta 版本
EOF
 
    chmod 644 "${CONFIG_DIR}/connection-info.txt"
    print_info "连接信息已保存到: ${CONFIG_DIR}/connection-info.txt"
}
 
# 创建 systemd 服务
create_service() {
    print_info "创建 systemd 服务..."
 
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Snell Proxy Service v6
After=network.target
 
[Service]
Type=simple
User=nobody
Group=nogroup
LimitNOFILE=32768
ExecStart=${INSTALL_DIR}/snell-server -c ${CONFIG_FILE}
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
 
# 检查更新函数
check_update() {
    print_info "检查 Snell 更新..."
 
    if [ ! -f "${INSTALL_DIR}/snell-server" ]; then
        print_error "Snell 未安装，请先运行安装"
        exit 1
    fi
 
    local current_version=$("${INSTALL_DIR}/snell-server" --version 2>&1 | grep -oP 'v\d+\.\d+\.\d+\w*' || echo "unknown")
    print_info "当前版本: $current_version"
    print_info "最新版本: $SNELL_VERSION"
 
    if [ "$current_version" = "$SNELL_VERSION" ]; then
        print_info "已是最新版本"
        return 0
    fi
 
    echo ""
    print_prompt "发现新版本，是否更新? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "取消更新"
        return 0
    fi
 
    print_info "开始更新..."
    detect_architecture
 
    # 停止服务
    if systemctl is-active --quiet snell; then
        systemctl stop snell
        print_info "已停止服务"
    fi
 
    # 备份旧版本
    if [ -f "${INSTALL_DIR}/snell-server" ]; then
        cp "${INSTALL_DIR}/snell-server" "${INSTALL_DIR}/snell-server.backup"
        print_info "已备份当前版本"
    fi
 
    # 下载新版本
    local download_url="https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${ARCH}.zip"
    local temp_dir=$(mktemp -d)
    local zip_file="${temp_dir}/snell-server.zip"
 
    print_info "下载地址: $download_url"
 
    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$zip_file" "$download_url" || {
            print_error "下载失败，恢复备份"
            [ -f "${INSTALL_DIR}/snell-server.backup" ] && mv "${INSTALL_DIR}/snell-server.backup" "${INSTALL_DIR}/snell-server"
            rm -rf "$temp_dir"
            systemctl start snell
            exit 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "$zip_file" "$download_url" || {
            print_error "下载失败，恢复备份"
            [ -f "${INSTALL_DIR}/snell-server.backup" ] && mv "${INSTALL_DIR}/snell-server.backup" "${INSTALL_DIR}/snell-server"
            rm -rf "$temp_dir"
            systemctl start snell
            exit 1
        }
    fi
 
    unzip -q "$zip_file" -d "$temp_dir"
    mv "${temp_dir}/snell-server" "${INSTALL_DIR}/snell-server"
    chmod +x "${INSTALL_DIR}/snell-server"
    rm -rf "$temp_dir"
 
    # 启动服务
    systemctl start snell
    sleep 2
 
    if systemctl is-active --quiet snell; then
        print_info "更新成功！"
        rm -f "${INSTALL_DIR}/snell-server.backup"
        local new_version=$("${INSTALL_DIR}/snell-server" --version 2>&1 | grep -oP 'v\d+\.\d+\.\d+\w*' || echo "unknown")
        print_info "新版本: $new_version"
    else
        print_error "服务启动失败，恢复备份"
        [ -f "${INSTALL_DIR}/snell-server.backup" ] && mv "${INSTALL_DIR}/snell-server.backup" "${INSTALL_DIR}/snell-server"
        systemctl start snell
    fi
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
 
# 显示使用帮助
show_help() {
    cat <<EOF
Snell v6 一键部署脚本
 
用法: $0 [命令]
 
命令:
    install     安装并配置 Snell v6 服务器（默认，交互式配置）
    uninstall   卸载 Snell 服务器
    update      检查并更新 Snell 到最新版本
    start       启动 Snell 服务
    stop        停止 Snell 服务
    restart     重启 Snell 服务
    status      查看 Snell 服务状态
    log         查看 Snell 服务日志
    config      查看 Snell 配置
    info        显示连接信息
    help        显示此帮助信息
 
示例:
    $0              # 交互式安装 Snell
    $0 install      # 交互式安装 Snell
    $0 update       # 检查更新
    $0 start        # 启动服务
    $0 stop         # 停止服务
    $0 restart      # 重启服务
    $0 status       # 查看状态
    $0 config       # 查看配置
    $0 log          # 查看日志
    $0 uninstall    # 卸载
 
EOF
}
 
# 主函数
main() {
    local action="${1:-install}"
 
    case $action in
        install)
            check_root
            print_info "开始安装 Snell v6..."
            detect_architecture
            get_user_config
            download_snell
            create_config
            create_service
            start_service
            configure_firewall
            echo ""
            print_info "=========================================="
            print_info "Snell v6 安装完成！"
            print_info "=========================================="
            print_info "查看连接信息: $0 info"
            print_info "查看配置: $0 config"
            print_info "查看服务状态: $0 status"
            print_info "查看服务日志: $0 log"
            print_info "重启服务: $0 restart"
            print_info "检查更新: $0 update"
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        update)
            check_root
            check_update
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
            print_info "重启 Snell 服务..."
            systemctl restart snell
            sleep 2
            systemctl status snell --no-pager
            ;;
        status)
            systemctl status snell --no-pager -l
            ;;
        log)
            journalctl -u snell -f
            ;;
        config)
            show_config
            ;;
        info)
            if [ -f "${CONFIG_DIR}/connection-info.txt" ]; then
                cat "${CONFIG_DIR}/connection-info.txt"
            else
                print_error "未找到连接信息文件，请确认 Snell 已安装"
                exit 1
            fi
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
