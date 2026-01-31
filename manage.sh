#!/bin/bash
#===============================================================================
# OpenClaw WeChat Proxy - 管理脚本
#===============================================================================

set -e

CONTAINER_NAME="wechat-proxy"
PROJECT_DIR="$HOME/OpenClaw-Wechat-Proxy"
PROXY_PORT=3120

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 确定 compose 命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    COMPOSE_CMD="docker compose"
fi

#-------------------------------------------------------------------------------
# 显示帮助
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo "OpenClaw WeChat Proxy 管理脚本"
    echo ""
    echo "用法: $0 <命令>"
    echo ""
    echo "命令:"
    echo "  start     启动服务"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  status    查看状态"
    echo "  logs      查看日志 (跟随)"
    echo "  logs:all  查看全部日志"
    echo "  rebuild   重新构建并启动"
    echo "  update    更新代码并重启"
    echo "  cleanup   清理容器和镜像"
    echo "  health    健康检查"
    echo "  shell     进入容器 shell"
    echo ""
}

#-------------------------------------------------------------------------------
# 命令处理
#-------------------------------------------------------------------------------
case "$1" in
    start)
        print_step "启动服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD up -d
        print_success "服务已启动"
        ;;
    stop)
        print_step "停止服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD stop
        print_success "服务已停止"
        ;;
    restart)
        print_step "重启服务..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD restart
        print_success "服务已重启"
        ;;
    status)
        print_step "服务状态:"
        cd "$PROJECT_DIR" && $COMPOSE_CMD ps
        ;;
    logs)
        print_step "查看日志 (Ctrl+C 退出):"
        cd "$PROJECT_DIR" && $COMPOSE_CMD logs -f
        ;;
    logs:all)
        print_step "查看全部日志:"
        cd "$PROJECT_DIR" && $COMPOSE_CMD logs --tail=100
        ;;
    rebuild)
        print_step "重新构建并启动..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD down && $COMPOSE_CMD up -d --build
        print_success "服务已重新构建并启动"
        ;;
    update)
        print_step "更新代码..."
        cd "$PROJECT_DIR"
        git pull origin main
        $COMPOSE_CMD up -d --build
        print_success "代码已更新，服务已重启"
        ;;
    cleanup)
        print_step "清理容器和镜像..."
        cd "$PROJECT_DIR" && $COMPOSE_CMD down -v
        docker rmi $(docker images -q $CONTAINER_NAME) -f 2>/dev/null || true
        print_success "已清理"
        ;;
    health)
        print_step "健康检查..."
        HEALTH=$(curl -s http://localhost:${PROXY_PORT}/health)
        if echo "$HEALTH" | grep -q "ok"; then
            print_success "健康检查通过"
            echo "$HEALTH" | jq . 2>/dev/null || echo "$HEALTH"
        else
            print_error "健康检查失败"
            echo "$HEALTH"
        fi
        ;;
    shell)
        print_step "进入容器 shell..."
        docker exec -it $CONTAINER_NAME /bin/sh
        ;;
    *)
        show_help
        exit 1
        ;;
esac
