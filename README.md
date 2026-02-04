# OpenClaw WeChat Proxy

> 企业微信 API 反向代理服务，用于家宽验证企业微信API。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Image Size](https://img.shields.io/docker/image-size/wechat-proxy/latest)](https://hub.docker.com/r/yourusername/wechat-proxy)

## 功能特性

- ✅ 反向代理企业微信 API (`qyapi.weixin.qq.com`)
- ✅ 健康检查端点
- ✅ 请求统计
- ✅ 日志记录
- ✅ 优雅关闭支持
- ✅ Docker 部署支持

## 为什么需要代理？

企业微信 API 有 IP 白名单限制。如果你的服务器 IP 动态变化或不在白名单中，可以使用此代理：

```
你的服务器 → 代理服务器(固定IP) → 企业微信 API
```

## 快速开始

### 使用 Docker Compose（推荐）

```bash
# 克隆项目
git clone https://github.com/yourusername/OpenClaw-Wechat-Proxy.git
cd OpenClaw-Wechat-Proxy

# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 手动运行

```bash
# 运行
node proxy.js

# 指定端口
PROXY_PORT=3120 node proxy.js
```

## Docker 部署

### 构建镜像

```bash
docker build -t wechat-proxy:latest .
```

### 运行容器

```bash
docker run -d \
  --name wechat-proxy \
  -p 3120:3120 \
  -e PROXY_PORT=3120 \
  -e TARGET_HOST=qyapi.weixin.qq.com \
  -e TARGET_PORT=443 \
  --restart unless-stopped \
  wechat-proxy:latest
```

## 配置

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `PROXY_PORT` | 3120 | 代理服务监听端口 |
| `TARGET_HOST` | qyapi.weixin.qq.com | 目标服务器地址 |
| `TARGET_PORT` | 443 | 目标服务器端口 |

### Docker Compose 配置示例

```yaml
version: '3.8'
services:
  wechat-proxy:
    image: wechat-proxy:latest
    container_name: wechat-proxy
    restart: unless-stopped
    ports:
      - "3120:3120"
    environment:
      - PROXY_PORT=3120
      - TARGET_HOST=qyapi.weixin.qq.com
      - TARGET_PORT=443
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3120/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

## 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/stats` | GET | 请求统计 |
| `/` | GET | 帮助信息 |
| `/cgi-bin/*` | ALL | 代理到微信API |

## 健康检查

```bash
curl http://localhost:3120/health

# 返回示例
{
  "status": "ok",
  "service": "wecom-proxy",
  "version": "1.0.0",
  "target": {
    "host": "qyapi.weixin.qq.com",
    "port": 443
  },
  "stats": {
    "totalRequests": 100,
    "totalErrors": 2,
    "uptime": 3600
  }
}
```

## 在 OpenClaw 中使用

在 `~/.openclaw/openclaw.json` 中配置：

```json
{
  "env": {
    "vars": {
      "WECOM_API_PROXY": "http://你的代理服务器IP:3120",
      "WECOM_CORP_ID": "你的企业ID",
      "WECOM_CORP_SECRET": "你的应用Secret",
      "WECOM_AGENT_ID": "你的应用AgentId",
      "WECOM_CALLBACK_TOKEN": "你的Token",
      "WECOM_CALLBACK_AES_KEY": "你的AESKey"
    }
  }
}
```

然后重启 OpenClaw：

```bash
pkill -f openclaw
openclaw
```

## 部署到阿里云

### 1. 构建镜像

```bash
docker build -t wechat-proxy:latest .
```

### 2. 标记镜像

```bash
docker tag wechat-proxy:latest your-registry.example.com/wechat-proxy:latest
```

### 3. 推送到镜像仓库

```bash
docker push your-registry.example.com/wechat-proxy:latest
```

### 4. 在阿里云服务器运行

```bash
# 拉取镜像
docker pull your-registry.example.com/wechat-proxy:latest

# 运行
docker run -d \
  --name wechat-proxy \
  -p 3120:3120 \
  -e PROXY_PORT=3120 \
  -e TARGET_HOST=qyapi.weixin.qq.com \
  -e TARGET_PORT=443 \
  --restart unless-stopped \
  your-registry.example.com/wechat-proxy:latest
```

## 日志

查看容器日志：

```bash
docker logs wechat-proxy
```

## 监控

### 请求统计

```bash
curl http://localhost:3120/stats

# 返回示例
{
  "totalRequests": 100,
  "totalErrors": 2,
  "uptime": 3600,
  "memoryUsage": {
    "heapUsed": 12345678,
    "heapTotal": 23456789,
    "rss": 34567890
  }
}
```

### Docker Stats

```bash
docker stats wechat-proxy
```

## 故障排查

### 代理无法连接

1. 检查防火墙设置
2. 确认3120端口已开放
3. 检查目标服务器是否可达

```bash
# 测试目标服务器连接
curl -v https://qyapi.weixin.qq.com/cgi-bin/gettoken?corpid=test
```

### 企业微信 API 返回错误

1. 检查 access_token 是否有效
2. 确认 CorpID 和 Secret 正确
3. 查看代理日志排查问题

```bash
# 查看详细日志
docker logs -f wechat-proxy
```

## 性能优化

### 调整超时时间

```bash
# 增加超时时间（如果处理大文件）
docker run -e TIMEOUT=120000 ...
```

### 资源限制

```yaml
services:
  wechat-proxy:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

## 相关项目

- [OpenClaw-Wechat-Plugin](https://github.com/yourusername/OpenClaw-Wechat-Plugin) - OpenClaw 企业微信插件

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
