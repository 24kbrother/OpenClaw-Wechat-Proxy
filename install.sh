#!/bin/bash
#===============================================================================
# OpenClaw WeChat Proxy - Docker 部署脚本
# GitHub: https://github.com/24kbrother/OpenClaw-Wechat-Proxy
#===============================================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_REPO="https://github.com/24kbrother/OpenClaw-Wechat-Proxy.git"
PROJECT_DIR="$HOME/OpenClaw-Wechat-Proxy"
CONTAINER_NAME="wechat-proxy"
PROXY_PORT=3120

#-------------------------------------------------------------------------------
# 打印函数
#-------------------------------------------------------------------------------
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#-------------------------------------------------------------------------------
# 检查 Docker 环境
#-------------------------------------------------------------------------------
check_docker() {
    print_step "检查 Docker 环境..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose 未安装，尝试使用 docker compose 命令"
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi

    print_success "Docker 环境正常"
    echo "  Docker 版本: $(docker --version)"
    echo "  Compose 命令: $COMPOSE_CMD"
}

#-------------------------------------------------------------------------------
# 停止并删除旧容器
#-------------------------------------------------------------------------------
cleanup_old() {
    print_step "清理旧容器..."

    # 检查容器是否存在
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "发现旧容器: $CONTAINER_NAME"

        # 停止容器
        print_step "停止容器..."
        docker stop $CONTAINER_NAME 2>/dev/null || true

        # 删除容器
        print_step "删除容器..."
        docker rm $CONTAINER_NAME 2>/dev/null || true

        print_success "旧容器已清理"
    else
        print_success "没有发现旧容器，无需清理"
    fi

    # 检查旧镜像
    if docker images --format '{{.Repository}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warning "发现旧镜像: $CONTAINER_NAME"
        read -p "是否删除旧镜像? (y/N): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            docker rmi $(docker images -q $CONTAINER_NAME) -f 2>/dev/null || true
            print_success "旧镜像已删除"
        fi
    fi
}

#-------------------------------------------------------------------------------
# 克隆或更新项目
#-------------------------------------------------------------------------------
deploy_project() {
    print_step "部署项目..."

    # 创建目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    # 检查是否已有项目
    if [ -f "docker-compose.yml" ]; then
        print_warning "项目已存在，更新中..."
        git pull origin main 2>/dev/null || print_warning "git pull 失败，跳过更新"
    else
        print_step "克隆项目..."
        git clone "$PROJECT_REPO" .
    fi

    print_success "项目部署完成"
    echo "  项目目录: $PROJECT_DIR"
}

#-------------------------------------------------------------------------------
# 构建并启动容器
#-------------------------------------------------------------------------------
start_container() {
    print_step "构建并启动容器..."

    cd "$PROJECT_DIR"

    # 构建镜像
    print_step "构建 Docker 镜像..."
    $COMPOSE_CMD build --no-cache

    # 启动容器
    print_step "启动容器..."
    $COMPOSE_CMD up -d

    print_success "容器已启动"
}

#-------------------------------------------------------------------------------
# 验证部署
#-------------------------------------------------------------------------------
verify_deployment() {
    print_step "验证部署..."

    # 等待服务启动
    print_step "等待服务启动 (5秒)..."
    sleep 5

    # 检查容器状态
    cd "$PROJECT_DIR"
    CONTAINER_STATUS=$($COMPOSE_CMD ps --format json 2>/dev/null || $COMPOSE_CMD ps)

    if echo "$CONTAINER_STATUS" | grep -q "Up"; then
        print_success "容器运行正常"
    else
        print_error "容器启动失败，查看日志:"
        $COMPOSE_CMD logs
        exit 1
    fi

    # 健康检查
    print_step "执行健康检查..."
    HEALTH_RESPONSE=$(curl -s http://localhost:${PROXY_PORT}/health 2>/dev/null || echo "")

    if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
        print_success "健康检查通过"
    else
        print_warning "健康检查未通过，查看日志排查问题"
        $COMPOSE_CMD logs
    fi

    # 显示服务信息
    echo ""
    echo "=========================================="
    echo "  部署完成！"
    echo "=========================================="
    echo ""
    echo "  服务地址: http://localhost:${PROXY_PORT}"
    echo "  健康检查: http://localhost:${PROXY_PORT}/health"
    echo "  统计信息: http://localhost:${PROXY_PORT}/stats"
    echo ""
    echo "  项目目录: $PROJECT_DIR"
    echo "  容器名称: $CONTAINER_NAME"
    echo ""
    echo "  管理命令:"
    echo "    查看日志: cd $PROJECT_DIR && $COMPOSE_CMD logs -f"
    echo "    停止服务: cd $PROJECT_DIR && $COMPOSE_CMD down"
    echo "    重启服务: cd $PROJECT_DIR && $COMPOSE_CMD restart"
    echo "    更新部署: cd $PROJECT_DIR && git pull && $COMPOSE_CMD up -d --build"
    echo ""
    echo "=========================================="
}

#-------------------------------------------------------------------------------
# 主函数
#-------------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  OpenClaw WeChat Proxy 部署脚本"
    echo "  GitHub: $PROJECT_REPO"
    echo "=========================================="
    echo ""

    check_docker
    cleanup_old
    deploy_project
    start_container
    verify_deployment
}

# 运行主函数
main "$@"
