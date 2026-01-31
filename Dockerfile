FROM node:20-alpine

LABEL maintainer="your-email@example.com"
LABEL description="WeChat Work API Proxy Service"
LABEL version="1.0.0"

WORKDIR /app

# 创建非root用户
RUN addgroup -g 1000 app && adduser -u 1000 -G app -s /bin/sh -D app

# 复制代理服务代码
COPY proxy.js .

# 安装依赖（如果需要）
# RUN npm install

# 切换到非root用户
USER app

EXPOSE 3120

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3120/health || exit 1

CMD ["node", "proxy.js"]
