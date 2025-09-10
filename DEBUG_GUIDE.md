# WeKnora 源码调试指南

本指南将帮助你设置WeKnora的源码调试环境，适用于需要修改代码并进行调试的开发场景。

## 🎯 调试模式 vs Docker模式

| 特性 | 源码调试模式 | Docker模式 |
|------|-------------|------------|
| **编译方式** | 本地Go编译 | Docker镜像 |
| **调试能力** | 支持断点调试 | 日志调试 |
| **代码修改** | 即时生效 | 需重新构建镜像 |
| **性能** | 更快的启动 | 略慢 |
| **依赖管理** | 手动管理 | 自动化 |
| **适用场景** | 开发调试 | 生产部署 |

## 🚀 快速开始

### 步骤1: 启动外部服务

```bash
# 启动所有必要的外部服务（PostgreSQL, Redis, Ollama）
./scripts/start_external_services.sh start

# 查看服务状态
./scripts/start_external_services.sh status
```

### 步骤2: 启动主程序调试

```bash
# 编译并运行WeKnora主程序
./scripts/debug_run.sh

# 或者分步执行：
./scripts/debug_run.sh --build  # 仅编译
./scripts/debug_run.sh --check  # 检查环境
```

### 步骤3: 启动前端开发服务器（可选）

```bash
# 启动前端开发服务器
./scripts/frontend_dev.sh dev
```

## 📋 详细配置

### 环境要求

- **Go 1.24+** ✅ (当前: go1.24.2)
- **Docker** (用于外部服务)
- **Node.js** (用于前端开发)
- **Python 3.8+** (用于DocReader服务)

### 核心服务端口

| 服务 | 端口 | 描述 |
|------|------|------|
| WeKnora API | 8080 | 主程序API服务 |
| PostgreSQL | 5432 | 主数据库 |
| Redis | 6379 | 缓存/流管理 |
| Ollama | 11434 | LLM模型服务 |
| DocReader | 50051 | 文档解析服务 |
| 前端开发服务器 | 5173 | Vue.js开发服务器 |

### 环境变量配置

当前已配置的关键环境变量：

```bash
# 调试模式
GIN_MODE=debug

# 数据库配置
DB_DRIVER=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres123!@#
DB_NAME=WeKnora

# 存储配置
STORAGE_TYPE=local
LOCAL_STORAGE_BASE_DIR=./data/files

# 模型服务
OLLAMA_BASE_URL=http://localhost:11434

# 文档解析
DOCREADER_ADDR=localhost:50051
```

## 🔧 调试工作流

### 典型的调试流程：

1. **启动外部服务**
   ```bash
   ./scripts/start_external_services.sh start
   ```

2. **修改Go代码**
   - 编辑 `internal/` 目录下的源码
   - 主程序入口: `cmd/server/main.go`

3. **重新编译运行**
   ```bash
   ./scripts/debug_run.sh
   ```

4. **前端开发**（如需要）
   ```bash
   # 在新终端窗口中
   ./scripts/frontend_dev.sh dev
   ```

5. **访问服务**
   - API: http://localhost:8080
   - 前端: http://localhost:5173（开发模式）

### IDE集成调试

#### VS Code调试配置

创建 `.vscode/launch.json`：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug WeKnora",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd/server",
            "cwd": "${workspaceFolder}",
            "envFile": "${workspaceFolder}/.env",
            "args": []
        }
    ]
}
```

#### GoLand调试配置

1. 右键点击 `cmd/server/main.go`
2. 选择 "Debug 'go build main.go'"
3. 在Run Configuration中添加环境变量文件路径: `.env`

## 📁 项目结构（调试重点）

```
WeKnora/
├── cmd/server/           # 主程序入口 🎯
├── internal/             # 核心业务逻辑 🎯
│   ├── application/      # 应用层
│   ├── handler/          # API处理层 🎯
│   ├── models/           # 模型层
│   └── types/            # 类型定义
├── config/               # 配置文件
├── scripts/              # 调试脚本 🆕
│   ├── debug_run.sh      # 主调试脚本
│   ├── start_external_services.sh  # 外部服务管理
│   └── frontend_dev.sh   # 前端开发脚本
├── services/docreader/   # 文档解析服务 🎯
└── frontend/             # 前端代码 🎯
```

## 🛠️ 常用调试命令

### 服务管理

```bash
# 启动外部服务
./scripts/start_external_services.sh start

# 查看服务状态
./scripts/start_external_services.sh status

# 停止所有外部服务
./scripts/start_external_services.sh stop

# 仅启动PostgreSQL
./scripts/start_external_services.sh postgres
```

### 程序调试

```bash
# 编译并运行
./scripts/debug_run.sh

# 仅编译
./scripts/debug_run.sh --build

# 检查环境
./scripts/debug_run.sh --check

# 手动编译
make build

# 手动运行
./bin/weknora
```

### 前端开发

```bash
# 启动前端开发服务器
./scripts/frontend_dev.sh dev

# 构建前端
./scripts/frontend_dev.sh build

# 安装前端依赖
./scripts/frontend_dev.sh install
```

### 日志查看

```bash
# 查看主程序日志（运行时输出）
tail -f logs/weknora.log

# 查看DocReader日志
tail -f logs/docreader.log

# 查看外部服务日志
docker logs weknora-postgres-debug
docker logs weknora-redis-debug
docker logs weknora-ollama-debug
```

## 🐛 常见问题

### 1. 数据库连接失败

**错误**: `unsupported database driver`

**解决**:
```bash
# 检查PostgreSQL是否运行
./scripts/start_external_services.sh postgres

# 检查环境变量
grep -E "^DB_" .env
```

### 2. DocReader服务启动失败

**错误**: DocReader服务不可用

**解决**:
```bash
# 检查Python环境
cd services/docreader
python3 --version

# 手动启动DocReader
source venv/bin/activate
python3 -m src.server.server

# 验证服务
lsof -i :50051
```

### 3. Ollama模型下载

**问题**: 模型未下载

**解决**:
```bash
# 下载推荐模型
docker exec weknora-ollama-debug ollama pull qwen2.5:7b
docker exec weknora-ollama-debug ollama pull nomic-embed-text

# 查看已安装模型
docker exec weknora-ollama-debug ollama list
```

### 4. 前端代理配置

**问题**: 前端无法访问后端API

**解决**: 检查 `frontend/vite.config.ts` 中的代理配置：

```typescript
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
})
```

## 📈 性能优化建议

### 开发环境优化

1. **使用内存数据库**（临时开发）
   ```bash
   # 在.env中设置
   STREAM_MANAGER_TYPE=memory
   ```

2. **减少并发数**（避免429错误）
   ```bash
   CONCURRENCY_POOL_SIZE=3
   ```

3. **启用详细日志**
   ```bash
   GIN_MODE=debug
   ```

### 调试技巧

1. **添加调试日志**
   ```go
   import "github.com/sirupsen/logrus"
   
   logrus.WithFields(logrus.Fields{
       "user_id": userID,
       "action": "debug_point",
   }).Debug("调试信息")
   ```

2. **使用断点调试**
   - 在IDE中设置断点
   - 使用调试模式启动程序

3. **API测试**
   ```bash
   # 测试健康检查
   curl http://localhost:8080/health
   
   # 测试API
   curl -X POST http://localhost:8080/api/v1/sessions \
     -H "Content-Type: application/json" \
     -d '{"name": "test"}'
   ```

## 🔄 开发工作流建议

1. **启动顺序**:
   - 外部服务 → 后端 → 前端

2. **代码修改后**:
   - Go代码: 重新编译运行
   - 前端代码: 热重载（自动）

3. **提交前检查**:
   ```bash
   make test      # 运行测试
   make lint      # 代码检查
   make fmt       # 格式化代码
   ```

## 📞 获取帮助

如果遇到问题，可以：

1. 查看详细日志: `./scripts/debug_run.sh --check`
2. 检查服务状态: `./scripts/start_external_services.sh status`
3. 查看Docker容器: `docker ps -a`

祝你调试愉快！🚀