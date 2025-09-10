# WeKnora 文档解析服务快速故障排查指南

## 问题现象
- 文档上传后显示解析失败
- 知识库中文档状态为 `failed`
- 日志中出现 gRPC 连接失败错误: `dial tcp 127.0.0.1:50051: connect: connection refused`

## 快速解决方案

### 方法一：使用一键启动脚本
```bash
cd /Users/huoli4844/Documents/llm_project/WeKnora
./scripts/start_docreader.sh
```

### 方法二：手动启动服务

#### 1. 检查端口占用
```bash
lsof -i :50051
```

#### 2. 进入 docreader 目录
```bash
cd /Users/huoli4844/Documents/llm_project/WeKnora/services/docreader
```

#### 3. 安装基础依赖
```bash
pip install grpcio grpcio-tools protobuf python-docx PyPDF2 beautifulsoup4 lxml --quiet
```

#### 4. 生成 protobuf 文件
```bash
cd src
python -m grpc_tools.protoc --python_out=. --grpc_python_out=. --proto_path=. proto/docreader.proto
cd ..
```

#### 5. 启动服务
```bash
export PYTHONPATH="/Users/huoli4844/Documents/llm_project/WeKnora/services/docreader/src"
export GRPC_PORT=50051

# 方式A：启动简化测试服务
python start_minimal.py

# 方式B：启动完整服务（需要所有依赖）
python src/server/server.py
```

#### 6. 验证服务启动
```bash
lsof -i :50051
```

应该看到类似输出：
```
COMMAND     PID      USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
python3.9 17499 huoli4844    3u  IPv6 0xfc2ebfd04752d1e9      0t0  TCP *:50051 (LISTEN)
```

#### 7. 启动 WeKnora 后端
```bash
cd /Users/huoli4844/Documents/llm_project/WeKnora

# 设置数据库环境变量
export DB_DRIVER=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=password
export DB_NAME=weknora
export RETRIEVE_DRIVER=postgres
export DOCREADER_ADDR=localhost:50051

go run cmd/server/main.go
```

## 常见问题与解决

### 问题1：端口被占用
```bash
# 查找占用进程
lsof -i :50051
# 终止进程
kill -9 <PID>
```

### 问题2：Python 依赖缺失
```bash
# 重新安装核心依赖
pip install grpcio grpcio-tools protobuf --force-reinstall
```

### 问题3：protobuf 文件缺失
```bash
cd /Users/huoli4844/Documents/llm_project/WeKnora/services/docreader/src
python -m grpc_tools.protoc --python_out=. --grpc_python_out=. --proto_path=. proto/docreader.proto
```

### 问题4：数据库连接失败
确保设置了正确的数据库环境变量：
```bash
export DB_DRIVER=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=password
export DB_NAME=weknora
export RETRIEVE_DRIVER=postgres
```

### 问题5：配置文件缺少 docreader 配置
在 `config/config.yaml` 中添加：
```yaml
# 文档解析服务配置
docreader:
  addr: "localhost:50051"
  timeout: "30s"
  max_file_size: "50MB"
  supported_formats: ["pdf", "docx", "doc", "txt", "md", "html"]
```

## 服务验证

### 检查 DocReader 服务状态
```bash
# 检查端口监听
lsof -i :50051

# 简单连接测试
telnet localhost 50051

# 检查进程
ps aux | grep -E "(server.py|docreader)" | grep -v grep
```

### 检查 WeKnora 后端连接
启动 WeKnora 后端后，尝试上传文档，检查日志中是否还有 gRPC 连接错误。

## 文件位置

- **WeKnora 配置文件**: `/Users/huoli4844/Documents/llm_project/WeKnora/config/config.yaml`
- **DocReader 服务**: `/Users/huoli4844/Documents/llm_project/WeKnora/services/docreader/`
- **启动脚本**: `/Users/huoli4844/Documents/llm_project/WeKnora/scripts/start_docreader.sh`
- **简化服务**: `/Users/huoli4844/Documents/llm_project/WeKnora/services/docreader/start_minimal.py`

## 技术架构

```
WeKnora 后端 (Go)
    ↓ gRPC 调用
DocReader 服务 (Python)
    ├── 端口: 50051
    ├── 协议: gRPC
    └── 功能: 文档解析
```

## 支持的文档格式

- PDF (.pdf)
- Word 文档 (.docx, .doc)
- 文本文件 (.txt)
- Markdown (.md)
- HTML (.html)

---

**最后更新**: 2025-09-10
**版本**: 1.0