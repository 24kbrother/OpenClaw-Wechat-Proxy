#!/bin/bash
#===============================================================================
# OpenClaw WeChat Proxy - 镜像迁移脚本
# 用于从 Debian 服务器导出镜像并传输到阿里云
#===============================================================================

set -e

# 配置
SOURCE_SERVER="root@10.0.0.70"
SOURCE_DIR="/root/OpenClaw-Wechat-Proxy"
CONTAINER_NAME="wechat-proxy"
OUTPUT_FILE="wechat-proxy-image.tar.gz"
ALIYUN_SERVER="root@你的阿里云服务器IP"
ALIYUN_DIR="/root/OpenClaw-Wechat-Proxy"

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
export_image() {
    print_step "导出 Docker 镜像..."

    # 在 Debian 服务器上执行导出
    ssh $SOURCE_SERVER "
        cd $SOURCE_DIR
        echo '停止容器...'
        docker stop $CONTAINER_NAME 2>/dev/null || true

        echo '保存镜像...'
        docker save $CONTAINER_NAME | gzip > /tmp/$OUTPUT_FILE

        echo '文件大小:'
        ls -lh /tmp/$OUTPUT_FILE
    "

    print_success "镜像已导出到 Debian 服务器"
}

#-------------------------------------------------------------------------------
transfer_image() {
    print_step "传输镜像到阿里云..."

    FILE_SIZE=$(ssh $SOURCE_SERVER "ls -lh /tmp/$OUTPUT_FILE | awk '{print \$5}'")
    print_warning "文件大小: $FILE_SIZE"

    read -p "确认传输? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        print_warning "取消传输"
        exit 0
    fi

    print_step "传输中... (这可能需要几分钟)"

    scp $SOURCE_SERVER:/tmp/$OUTPUT_FILE $ALIYUN_SERVER:/tmp/

    print_success "镜像已传输到阿里云"
}

#-------------------------------------------------------------------------------
import_and_run() {
    print_step "在阿里云服务器上加载镜像并启动..."

    ssh $ALIYUN_SERVER "
        cd $ALIYUN_DIR

        echo '加载镜像...'
        docker load -i /tmp/$OUTPUT_FILE

        echo '清理旧容器...'
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true

        echo '启动容器...'
        docker run -d \
            --name $CONTAINER_NAME \
            -p 3120:3120 \
            -e PROXY_PORT=3120 \
            -e TARGET_HOST=qyapi.weixin.qq.com \
            -e TARGET_PORT=443 \
            $CONTAINER_NAME:latest

        sleep 3

        echo '健康检查...'
        curl -s http://localhost:3120/health

        echo ''
        echo '容器状态:'
        docker ps | grep $CONTAINER_NAME
    "

    print_success "阿里云部署完成"
}

#-------------------------------------------------------------------------------
cleanup() {
    print_step "清理临时文件..."

    ssh $SOURCE_SERVER "rm -f /tmp/$OUTPUT_FILE"
    ssh $ALIYUN_SERVER "rm -f /tmp/$OUTPUT_FILE"

    print_success "临时文件已清理"
}

#-------------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  Docker 镜像迁移脚本"
    echo "  从: $SOURCE_SERVER"
    echo "  到: $ALIYUN_SERVER"
    echo "=========================================="
    echo ""

    print_warning "此脚本需要:"
    echo "  1. 能 SSH 到 Debian 服务器 ($SOURCE_SERVER)"
    echo "  2. 能 SSH 到阿里云服务器 ($ALIYUN_SERVER)"
    echo ""

    read -p "是否继续? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        exit 0
    fi

    export_image
    transfer_image
    import_and_run
    cleanup

    echo ""
    echo "=========================================="
    echo "  迁移完成！"
    echo "=========================================="
    echo ""
    echo "  阿里云服务器访问: http://阿里云IP:3120/health"
    echo ""
}

main "$@"
