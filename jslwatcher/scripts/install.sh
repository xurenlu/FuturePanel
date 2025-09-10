#!/bin/bash

# JSLWatcher 一键安装脚本
# 支持自动从 GitHub Release 下载并安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO_USER="xurenlu"
REPO_NAME="FuturePanel"
SERVICE_NAME="jslwatcher"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/jslwatcher"
DATA_DIR="/var/lib/jslwatcher"
LOG_DIR="/var/log/jslwatcher"
SYSTEMD_DIR="/etc/systemd/system"

# 函数定义
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请以 root 用户运行此脚本"
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    log_step "检测系统信息..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) log_error "不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    log_info "操作系统: $OS $VER"
    log_info "架构: $ARCH"
}

# 检查依赖
check_dependencies() {
    log_step "检查依赖..."
    
    local deps=("curl" "tar" "systemctl")
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            log_error "缺少依赖: $dep"
            case $OS in
                ubuntu|debian)
                    log_info "请运行: apt-get update && apt-get install -y $dep"
                    ;;
                centos|rhel|fedora)
                    log_info "请运行: yum install -y $dep"
                    ;;
            esac
            exit 1
        fi
    done
    
    log_info "依赖检查通过"
}

# 获取最新版本
get_latest_version() {
    log_step "获取最新版本..."
    
    local api_url="https://api.github.com/repos/$REPO_USER/$REPO_NAME/releases/latest"
    LATEST_VERSION=$(curl -s $api_url | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        log_error "无法获取最新版本"
        exit 1
    fi
    
    log_info "最新版本: $LATEST_VERSION"
}

# 下载二进制文件
download_binary() {
    log_step "下载 jslwatcher 二进制文件..."
    
    local binary_name="jslwatcher_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
    local download_url="https://sslcat.com/$REPO_USER/$REPO_NAME/releases/download/$LATEST_VERSION/$binary_name"
    local temp_dir=$(mktemp -d)
    
    log_info "下载地址: $download_url"
    
    cd $temp_dir
    if ! curl -L -o $binary_name $download_url; then
        log_error "下载失败"
        rm -rf $temp_dir
        exit 1
    fi
    
    # 解压
    tar -xzf $binary_name
    
    # 安装到系统目录
    if [ -f "jslwatcher" ]; then
        install -m 755 jslwatcher $INSTALL_DIR/jslwatcher
        log_info "二进制文件已安装到 $INSTALL_DIR/jslwatcher"
    else
        log_error "二进制文件不存在"
        rm -rf $temp_dir
        exit 1
    fi
    
    # 清理临时文件
    rm -rf $temp_dir
}

# 创建用户和组
create_user() {
    log_step "创建系统用户..."
    
    if ! id "$SERVICE_NAME" &>/dev/null; then
        useradd --system --home-dir $DATA_DIR --shell /bin/false $SERVICE_NAME
        log_info "用户 $SERVICE_NAME 已创建"
    else
        log_info "用户 $SERVICE_NAME 已存在"
    fi
}

# 创建目录
create_directories() {
    log_step "创建目录..."
    
    local dirs=("$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chown $SERVICE_NAME:$SERVICE_NAME "$dir"
            log_info "目录已创建: $dir"
        else
            log_info "目录已存在: $dir"
        fi
    done
}

# 创建默认配置
create_config() {
    log_step "创建配置文件..."
    
    local config_file="$CONFIG_DIR/jslwatcher.conf"
    
    if [ ! -f "$config_file" ]; then
        # 运行 jslwatcher 生成默认配置
        sudo -u $SERVICE_NAME $INSTALL_DIR/jslwatcher -config $config_file -test 2>/dev/null || true
        
        if [ -f "$config_file" ]; then
            log_info "默认配置文件已创建: $config_file"
        else
            log_warn "配置文件创建失败，请手动创建"
        fi
    else
        log_info "配置文件已存在: $config_file"
    fi
}

# 安装 systemd 服务
install_systemd_service() {
    log_step "安装 systemd 服务..."
    
    local service_file="$SYSTEMD_DIR/jslwatcher.service"
    
    # 创建 systemd 服务文件
    cat > $service_file << 'EOF'
[Unit]
Description=JSLWatcher - 日志文件监控和转发服务
Documentation=https://github.com/xurenlu/FuturePanel/tree/main/jslwatcher
After=network.target
Wants=network.target

[Service]
Type=simple
User=jslwatcher
Group=jslwatcher
ExecStart=/usr/local/bin/jslwatcher -daemon
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=jslwatcher

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/jslwatcher /var/log/jslwatcher
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

# 环境变量
Environment=HOME=/var/lib/jslwatcher
WorkingDirectory=/var/lib/jslwatcher

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    log_info "systemd 服务已安装"
}

# 启用服务
enable_service() {
    log_step "启用服务..."
    
    systemctl enable $SERVICE_NAME
    log_info "服务已设置为开机自启"
}

# 测试配置
test_config() {
    log_step "测试配置..."
    
    if sudo -u $SERVICE_NAME $INSTALL_DIR/jslwatcher -test; then
        log_info "配置测试通过"
    else
        log_warn "配置测试失败，请检查配置文件"
    fi
}

# 显示安装完成信息
show_completion() {
    log_step "安装完成"
    
    echo
    log_info "JSLWatcher 已成功安装！"
    echo
    echo -e "${BLUE}常用命令:${NC}"
    echo "  启动服务:    systemctl start jslwatcher"
    echo "  停止服务:    systemctl stop jslwatcher"
    echo "  重启服务:    systemctl restart jslwatcher"
    echo "  查看状态:    systemctl status jslwatcher"
    echo "  查看日志:    journalctl -u jslwatcher -f"
    echo "  测试配置:    jslwatcher -test"
    echo
    echo -e "${BLUE}配置文件:${NC}"
    echo "  配置文件:    $CONFIG_DIR/jslwatcher.conf"
    echo "  数据目录:    $DATA_DIR"
    echo "  日志目录:    $LOG_DIR"
    echo
    echo -e "${YELLOW}下一步:${NC}"
    echo "1. 编辑配置文件: $CONFIG_DIR/jslwatcher.conf"
    echo "2. 启动服务: systemctl start jslwatcher"
    echo "3. 查看状态: systemctl status jslwatcher"
}

# 卸载函数
uninstall() {
    log_step "卸载 JSLWatcher..."
    
    # 停止服务
    if systemctl is-active --quiet $SERVICE_NAME; then
        systemctl stop $SERVICE_NAME
        log_info "服务已停止"
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet $SERVICE_NAME; then
        systemctl disable $SERVICE_NAME
        log_info "服务已禁用"
    fi
    
    # 删除 systemd 服务文件
    if [ -f "$SYSTEMD_DIR/jslwatcher.service" ]; then
        rm -f "$SYSTEMD_DIR/jslwatcher.service"
        systemctl daemon-reload
        log_info "systemd 服务文件已删除"
    fi
    
    # 删除二进制文件
    if [ -f "$INSTALL_DIR/jslwatcher" ]; then
        rm -f "$INSTALL_DIR/jslwatcher"
        log_info "二进制文件已删除"
    fi
    
    # 询问是否删除数据
    read -p "是否删除配置和数据目录? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
        log_info "配置和数据目录已删除"
    fi
    
    # 询问是否删除用户
    read -p "是否删除系统用户 $SERVICE_NAME? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel $SERVICE_NAME 2>/dev/null || true
        log_info "系统用户已删除"
    fi
    
    log_info "JSLWatcher 卸载完成"
}

# 显示帮助
show_help() {
    echo "JSLWatcher 安装脚本"
    echo
    echo "用法:"
    echo "  $0 [选项]"
    echo
    echo "选项:"
    echo "  install      安装 JSLWatcher (默认)"
    echo "  uninstall    卸载 JSLWatcher"
    echo "  help         显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 install"
    echo "  $0 uninstall"
}

# 主函数
main() {
    local action=${1:-install}
    
    case $action in
        install)
            echo "=== JSLWatcher 安装脚本 ==="
            check_root
            detect_system
            check_dependencies
            get_latest_version
            download_binary
            create_user
            create_directories
            create_config
            install_systemd_service
            enable_service
            test_config
            show_completion
            ;;
        uninstall)
            echo "=== JSLWatcher 卸载脚本 ==="
            check_root
            uninstall
            ;;
        help)
            show_help
            ;;
        *)
            log_error "未知操作: $action"
            show_help
            exit 1
            ;;
    esac
}

# 脚本入口
main "$@"
