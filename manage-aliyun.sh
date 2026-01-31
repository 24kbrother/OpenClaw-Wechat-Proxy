#!/bin/bash
#===============================================================================
# OpenClaw WeChat Proxy - 阿里云管理脚本
#===============================================================================

set -e

PROJECT_DIR="$HOME/OpenClaw-Wechat-Proxy"
CONTAINER_NAME="wechat-proxy"
PROXY_PORT=3120

# 确定 compose 命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }

show_help() {
    echo ""
    echo "OpenClaw WeChat Proxy 管理 (阿里云)"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "命令:"
    echo "  status    查看状态"
    echo "  start     启动服务"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  logs      查看日志"
    echo "  health    健康检查"
    echo "  update    更新并重启"
    echo "  reload    重新加载配置"
    echo ""
}

case "$1" in
    status)
        print_step "服务状态:"
        cd "$PROJECT_DIR" && $COMPOSE_CMD ps
        ;;
    start)
        print_step "启动服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD up -d
        print_success "已启动"
        ;;
    stop)
        print_step "停止服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD stop
        print_success "已停止"
        ;;
    restart)
        print_step "重启服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD restart
        print_success "已重启"
        ;;
    logs)
        cd "$PROJECT_DIR" && $COMPOSE_CMD logs -f
        ;;
    health)
        print_step "健康检查..."
        curl -s http://localhost:${PROXY_PORT}/health | jq . 2>/dev/null || curl -s http://localhost:${PROXY_PORT}/health
        ;;
    update)
        print_step "更新代码..."
        cd "$PROJECT_DIR"
        git pull
        $COMPOSE_CMD up -d --build
        print_success "已更新并重启"
        ;;
    reload)
        print_step "重新加载配置..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD up -d
        print_success "已重新加载"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
