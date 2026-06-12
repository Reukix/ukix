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
NC='\033[0m' # No Color
 
# 配置变量
SNELL_VERSION="v6.0.0b2"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/snell"
CONFIG_FILE="${CONFIG_DIR}/snell-server.conf"
SERVICE_FILE="/etc/systemd/system/snell.service"
 
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
 
    # 生成随机端口 (6000-9000)
    local port=$((RANDOM % 3000 + 6000))
 
    # 生成随机密码
    local psk=$(generate_password)
 
    # 创建配置文件
    cat > "$CONFIG_FILE" <<EOF
[snell-server]
listen = 0.0.0.0:${port}, [::]:${port}
psk = ${psk}
ipv6 = true
dns-ip-preference = default
 
# Snell v6 会自动从 PSK 派生部署级别的协议配置文件
# 不同的 PSK 会产生不同的流量特征
EOF
 
    print_info "配置文件已创建: $CONFIG_FILE"
    echo ""
    print_info "=========================================="
    print_info "Snell 服务器配置信息:"
    print_info "=========================================="
    print_info "服务器地址: ${server_ip}"
    print_info "监听端口: ${port}"
    print_info "密码(PSK): ${psk}"
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
端口: ${port}
密码(PSK): ${psk}
版本: 6
 
Surge 配置示例:
==========================================
[Proxy]
Snell = snell, ${server_ip}, ${port}, psk=${psk}, version=6
 
注意: Snell v6 仍在 Beta 测试中，需要使用最新的 Surge Beta 版本
EOF
 
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
    local port=$(grep -oP 'listen = 0\.0\.0\.0:\K\d+' "$CONFIG_FILE" | head -1)
 
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
 
# 显示使用帮助
show_help() {
    cat <<EOF
Snell v6 一键部署脚本
 
用法: $0 [选项]
 
选项:
    install     安装并配置 Snell v6 服务器（默认）
    uninstall   卸载 Snell 服务器
    restart     重启 Snell 服务
    status      查看 Snell 服务状态
    log         查看 Snell 服务日志
    info        显示连接信息
    help        显示此帮助信息
 
示例:
    $0              # 安装 Snell
    $0 install      # 安装 Snell
    $0 uninstall    # 卸载 Snell
    $0 status       # 查看状态
    $0 log          # 查看日志
 
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
            download_snell
            create_config
            create_service
            start_service
            configure_firewall
            echo ""
            print_info "=========================================="
            print_info "Snell v6 安装完成！"
            print_info "=========================================="
            print_info "查看连接信息: cat ${CONFIG_DIR}/connection-info.txt"
            print_info "查看服务状态: systemctl status snell"
            print_info "查看服务日志: journalctl -u snell -f"
            print_info "重启服务: systemctl restart snell"
            ;;
        uninstall)
            check_root
            uninstall
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
            print_error "未知选项: $action"
            show_help
            exit 1
            ;;
    esac
}
 
# 运行主函数
main "$@"
