#!/bin/bash
#===============================================================================
# OpenClaw WeChat Proxy - 阿里云服务器部署脚本
#===============================================================================

set -e

# 配置
PROJECT_REPO="https://github.com/24kbrother/OpenClaw-Wechat-Proxy.git"
PROJECT_DIR="$HOME/OpenClaw-Wechat-Proxy"
CONTAINER_NAME="wechat-proxy"
PROXY_PORT=3120

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

#-------------------------------------------------------------------------------
check_docker() {
    print_step "检查 Docker 环境..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        echo "安装命令:"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sh get-docker.sh"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行"
        exit 1
    fi

    print_success "Docker 环境正常 ($(docker --version))"
}

#-------------------------------------------------------------------------------
cleanup_old() {
    print_step "清理旧容器..."

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "发现旧容器: $CONTAINER_NAME"
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
        print_success "旧容器已清理"
    fi
}

#-------------------------------------------------------------------------------
deploy() {
    print_step "部署项目..."

    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    if [ -f "docker-compose.yml" ]; then
        print_warning "项目已存在，更新中..."
        git pull
    else
        print_step "克隆项目..."
        git clone "$PROJECT_REPO" .
    fi

    print_success "项目部署完成: $PROJECT_DIR"
}

#-------------------------------------------------------------------------------
start() {
    print_step "构建并启动容器..."

    cd "$PROJECT_DIR"

    # 使用 docker compose (新版)
    COMPOSE_CMD="docker compose"
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    fi

    $COMPOSE_CMD build --no-cache
    $COMPOSE_CMD up -d

    print_success "容器已启动"
}

#-------------------------------------------------------------------------------
verify() {
    print_step "验证部署..."
    sleep 5

    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_success "容器运行正常"
    else
        print_error "容器启动失败"
        docker logs $CONTAINER_NAME
        exit 1
    fi

    print_step "健康检查..."
    HEALTH=$(curl -s http://localhost:${PROXY_PORT}/health 2>/dev/null || echo "")

    if echo "$HEALTH" | grep -q "ok"; then
        print_success "健康检查通过"
    else
        print_warning "健康检查未通过"
    fi

    echo ""
    echo "=========================================="
    echo "  阿里云部署完成！"
    echo "=========================================="
    echo ""
    echo "  服务地址: http://你的服务器IP:3120"
    echo "  健康检查: http://localhost:3120/health"
    echo ""
    echo "  阿里云安全组需开放 TCP 3120 端口"
    echo ""
}

#-------------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  OpenClaw WeChat Proxy - 阿里云部署"
    echo "=========================================="
    echo ""

    check_docker
    cleanup_old
    deploy
    start
    verify
}

main "$@"
