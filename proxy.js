/**
 * WeChat Work API Proxy Service
 * 
 * 企业微信API反向代理服务
 * 用于绕过IP白名单限制，将API请求从固定IP服务器转发到微信服务器
 * 
 * 使用方法：
 *   node proxy.js [port]
 * 
 * 环境变量：
 *   PROXY_PORT - 代理服务端口（默认3120）
 *   TARGET_HOST - 目标服务器（默认 qyapi.weixin.qq.com）
 *   TARGET_PORT - 目标端口（默认443）
 * 
 * 示例：
 *   PROXY_PORT=3120 TARGET_HOST=qyapi.weixin.qq.com node proxy.js
 */

const http = require('http');
const https = require('https');
const { URL } = require('url');

// 配置
const PROXY_PORT = parseInt(process.env.PROXY_PORT || '3120', 10);
const TARGET_HOST = process.env.TARGET_HOST || 'qyapi.weixin.qq.com';
const TARGET_PORT = parseInt(process.env.TARGET_PORT || '443', 10);

// 打印配置
console.log('========================================');
console.log('  WeChat Work API Proxy Service');
console.log('========================================');
console.log(`  Proxy Port: ${PROXY_PORT}`);
console.log(`  Target Host: ${TARGET_HOST}`);
console.log(`  Target Port: ${TARGET_PORT}`);
console.log('========================================');

// 统计信息
let requestCount = 0;
let errorCount = 0;

/**
 * 记录请求日志
 */
function logRequest(method, path, statusCode, duration) {
  requestCount++;
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${method} ${path} -> ${statusCode} (${duration}ms) ${TARGET_HOST}`);
}

/**
 * 记录错误日志
 */
function logError(method, path, error) {
  errorCount++;
  const timestamp = new Date().toISOString();
  console.error(`[${timestamp}] ERROR: ${method} ${path} - ${error.message}`);
}

/**
 * 创建代理请求选项
 */
function createProxyOptions(req, targetPath) {
  return {
    hostname: TARGET_HOST,
    port: TARGET_PORT,
    path: targetPath,
    method: req.method,
    headers: {
      ...req.headers,
      // 重写Host头为目标服务器
      'Host': TARGET_HOST,
      // 移除可能导致问题的头
      'Connection': 'close',
      // 完全移除X-Forwarded-For和X-Forwarded-Proto头，避免undefined值
    },
    // 超时设置
    timeout: 60000,
  };
}

/**
 * 处理代理请求
 */
function handleProxyRequest(req, res) {
  const startTime = Date.now();
  
  // 只代理 /cgi-bin/ 路径
  if (!req.url.startsWith('/cgi-bin/')) {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Not Found - Only /cgi-bin/ paths are proxyied');
    return;
  }
  
  // 解析URL获取路径和查询参数
  const url = new URL(req.url, `http://localhost:${PROXY_PORT}`);
  const targetPath = url.pathname + url.search;
  
  // 创建代理请求
  const proxyOptions = createProxyOptions(req, targetPath);
  
  // 选择HTTP或HTTPS
  const client = TARGET_PORT === 443 ? https : http;
  
  const proxyReq = client.request(proxyOptions, (proxyRes) => {
    // 复制响应头
    const responseHeaders = { ...proxyRes.headers };
    // 移除可能干扰的头
    delete responseHeaders['transfer-encoding'];
    
    res.writeHead(proxyRes.statusCode, responseHeaders);
    
    // 流式传输响应
    proxyRes.pipe(res);
    
    // 记录成功响应
    const duration = Date.now() - startTime;
    logRequest(req.method, targetPath, proxyRes.statusCode, duration);
  });
  
  // 处理代理请求错误
  proxyReq.on('error', (err) => {
    const duration = Date.now() - startTime;
    logError(req.method, targetPath, err);
    
    res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      errcode: -1,
      errmsg: `Proxy error: ${err.message}`
    }));
  });
  
  // 处理超时
  proxyReq.on('timeout', () => {
    proxyReq.destroy();
    const duration = Date.now() - startTime;
    logError(req.method, targetPath, new Error('Request timeout'));
    
    res.writeHead(504, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({
      errcode: -1,
      errmsg: 'Gateway timeout'
    }));
  });
  
  // 流式传输请求体
  req.pipe(proxyReq);
}

/**
 * 健康检查端点
 */
function handleHealthCheck(res) {
  const healthData = {
    status: 'ok',
    service: 'wecom-proxy',
    version: '1.0.0',
    target: {
      host: TARGET_HOST,
      port: TARGET_PORT,
    },
    stats: {
      totalRequests: requestCount,
      totalErrors: errorCount,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
    },
    timestamp: new Date().toISOString(),
  };
  
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(healthData, null, 2));
}

/**
 * 统计信息端点
 */
function handleStats(res) {
  const statsData = {
    totalRequests: requestCount,
    totalErrors: errorCount,
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    timestamp: new Date().toISOString(),
  };
  
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(statsData, null, 2));
}

/**
 * 根路径处理
 */
function handleRoot(res) {
  const info = `
WeChat Work API Proxy Service
==============================

Endpoints:
  GET  /health          - Health check
  GET  /stats           - Request statistics
  GET  /                - This help message

Proxy:
  All /cgi-bin/* requests are proxied to ${TARGET_HOST}:${TARGET_PORT}

Environment Variables:
  PROXY_PORT   - Proxy listen port (default: 3100)
  TARGET_HOST  - Target server (default: qyapi.weixin.qq.com)
  TARGET_PORT  - Target port (default: 443)

Stats:
  Total Requests: ${requestCount}
  Total Errors: ${errorCount}
  Uptime: ${Math.floor(process.uptime())}s
`;
  
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(info);
}

// 创建HTTP服务器
const server = http.createServer((req, res) => {
  // CORS头（如果需要）
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  // 路由处理
  if (req.url === '/health') {
    handleHealthCheck(res);
  } else if (req.url === '/stats') {
    handleStats(res);
  } else if (req.url === '/' || req.url === '') {
    handleRoot(res);
  } else {
    handleProxyRequest(req, res);
  }
});

// 启动服务器
server.listen(PROXY_PORT, '0.0.0.0', () => {
  console.log(`Proxy server listening on http://0.0.0.0:${PROXY_PORT}`);
  console.log(`Proxying /cgi-bin/* to ${TARGET_HOST}:${TARGET_PORT}`);
  console.log('');
  console.log('Endpoints:');
  console.log(`  Health: http://localhost:${PROXY_PORT}/health`);
  console.log(`  Stats:  http://localhost:${PROXY_PORT}/stats`);
  console.log('');
});

// 处理优雅关闭
process.on('SIGTERM', () => {
  console.log('\nReceived SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\nReceived SIGINT, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// 错误处理
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  errorCount++;
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  errorCount++;
});
