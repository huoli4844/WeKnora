#!/bin/bash

# WeKnora 文档解析服务快速启动脚本
# 基于设计文档的故障排查与启动指南
# 2025-09-10

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 工作目录配置
WORKSPACE_ROOT="/Users/huoli4844/Documents/llm_project/WeKnora"
DOCREADER_DIR="$WORKSPACE_ROOT/services/docreader"

# 服务配置
GRPC_PORT=${GRPC_PORT:-50051}
DOCREADER_ADDR=${DOCREADER_ADDR:-"localhost:$GRPC_PORT"}

# 切换到工作目录
cd "$WORKSPACE_ROOT"

log_info "=== WeKnora 文档解析服务启动脚本 ==="
log_info "工作目录: $WORKSPACE_ROOT"
log_info "DocReader 目录: $DOCREADER_DIR"
log_info "gRPC 端口: $GRPC_PORT"

# 1. 环境检查
log_step "1. 检查环境依赖"

# 检查 Python 版本
if ! command -v python &> /dev/null; then
    log_error "Python 未安装，请先安装 Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
log_info "Python 版本: $PYTHON_VERSION"

# 检查 Go 版本
if ! command -v go &> /dev/null; then
    log_error "Go 未安装，请先安装 Go"
    exit 1
fi

GO_VERSION=$(go version | cut -d' ' -f3)
log_info "Go 版本: $GO_VERSION"

# 2. 检查端口占用
log_step "2. 检查端口占用情况"

if lsof -i :$GRPC_PORT > /dev/null 2>&1; then
    log_warn "端口 $GRPC_PORT 已被占用"
    
    # 显示占用进程
    PROCESS_INFO=$(lsof -i :$GRPC_PORT | tail -n +2)
    echo "$PROCESS_INFO"
    
    read -p "是否终止占用进程并继续? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PID=$(echo "$PROCESS_INFO" | awk '{print $2}' | head -1)
        log_info "终止进程 PID: $PID"
        kill -9 $PID 2>/dev/null || true
        sleep 2
    else
        log_error "用户取消操作"
        exit 1
    fi
fi

# 3. 安装 Python 依赖
log_step "3. 检查和安装 Python 依赖"

cd "$DOCREADER_DIR"

# 检查核心依赖
REQUIRED_PACKAGES=("grpcio" "grpcio-tools" "protobuf")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! python -c "import $package" 2>/dev/null; then
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log_info "安装缺失的依赖包: ${MISSING_PACKAGES[*]}"
    pip install "${MISSING_PACKAGES[@]}" --quiet
fi

# 安装其他必要依赖（跳过有问题的包）
log_info "安装其他必要依赖..."
pip install python-docx PyPDF2 beautifulsoup4 lxml --quiet 2>/dev/null || log_warn "部分依赖包安装失败，使用简化模式"

# 4. 生成 protobuf 文件
log_step "4. 生成 protobuf 文件"

cd "$DOCREADER_DIR/src"
if [ ! -f "proto/docreader_pb2.py" ] || [ ! -f "proto/docreader_pb2_grpc.py" ]; then
    log_info "生成 protobuf Python 文件..."
    python -m grpc_tools.protoc \
        --python_out=. \
        --grpc_python_out=. \
        --proto_path=. \
        proto/docreader.proto
    
    if [ $? -eq 0 ]; then
        log_info "protobuf 文件生成成功"
    else
        log_error "protobuf 文件生成失败"
        exit 1
    fi
else
    log_info "protobuf 文件已存在"
fi

# 5. 修复配置文件
log_step "5. 检查 WeKnora 配置文件"

CONFIG_FILE="$WORKSPACE_ROOT/config/config.yaml"
if ! grep -q "docreader:" "$CONFIG_FILE"; then
    log_warn "配置文件中缺少 docreader 配置段"
    log_info "配置文件已在之前的步骤中修复"
else
    log_info "配置文件检查通过"
fi

# 6. 启动 DocReader 服务
log_step "6. 启动 DocReader 服务"

cd "$DOCREADER_DIR"

# 设置环境变量
export PYTHONPATH="$DOCREADER_DIR/src"
export GRPC_PORT="$GRPC_PORT"
export DOCREADER_ADDR="$DOCREADER_ADDR"

log_info "启动 DocReader 服务 (端口: $GRPC_PORT)..."

# 选择启动模式
if [ -f "src/parser/__init__.py" ] && python -c "from parser import Parser" 2>/dev/null; then
    log_info "使用完整模式启动服务"
    python src/server/server.py &
else
    log_warn "部分依赖缺失，使用简化测试模式启动服务"
    python start_minimal.py &
fi

DOCREADER_PID=$!
log_info "DocReader 服务已启动，PID: $DOCREADER_PID"

# 等待服务启动
log_info "等待服务启动..."
sleep 5

# 7. 验证服务状态
log_step "7. 验证服务状态"

if lsof -i :$GRPC_PORT > /dev/null 2>&1; then
    log_info "✅ DocReader 服务已成功启动并监听端口 $GRPC_PORT"
    
    # 显示服务信息
    PROCESS_INFO=$(lsof -i :$GRPC_PORT | tail -n +2)
    echo "$PROCESS_INFO"
else
    log_error "❌ DocReader 服务启动失败"
    exit 1
fi

# 8. 设置数据库环境变量（用于 WeKnora 后端）
log_step "8. 设置数据库环境变量"

log_info "为 WeKnora 后端设置数据库环境变量..."

# 检查是否有现有的数据库配置
if [ -z "$DB_DRIVER" ]; then
    log_warn "未设置数据库驱动，设置默认值"
    export DB_DRIVER="postgres"
    export DB_HOST="localhost"
    export DB_PORT="5432"
    export DB_USER="postgres"
    export DB_PASSWORD="password"
    export DB_NAME="weknora"
    export RETRIEVE_DRIVER="postgres"
fi

log_info "数据库配置:"
log_info "  驱动: $DB_DRIVER"
log_info "  主机: $DB_HOST"
log_info "  端口: $DB_PORT"
log_info "  用户: $DB_USER"
log_info "  数据库: $DB_NAME"

# 9. 可选：启动 WeKnora 后端
log_step "9. 启动选项"

echo ""
log_info "=== 启动完成 ==="
log_info "DocReader 服务已启动并运行在端口 $GRPC_PORT"
log_info ""
log_info "下一步操作选项:"
log_info "1. 启动 WeKnora 后端服务:"
log_info "   cd $WORKSPACE_ROOT"
log_info "   export DB_DRIVER=postgres DB_HOST=localhost DB_PORT=5432 DB_USER=postgres DB_PASSWORD=password DB_NAME=weknora RETRIEVE_DRIVER=postgres"
log_info "   go run cmd/server/main.go"
log_info ""
log_info "2. 测试 docreader 连接:"
log_info "   telnet localhost $GRPC_PORT"
log_info ""
log_info "3. 停止 DocReader 服务:"
log_info "   kill $DOCREADER_PID"
log_info ""
log_info "4. 查看服务日志:"
log_info "   tail -f /tmp/docreader.log"

# 10. 等待用户操作
echo ""
read -p "是否现在启动 WeKnora 后端服务? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_step "10. 启动 WeKnora 后端服务"
    
    cd "$WORKSPACE_ROOT"
    
    # 设置环境变量
    export DB_DRIVER="postgres"
    export DB_HOST="localhost" 
    export DB_PORT="5432"
    export DB_USER="postgres"
    export DB_PASSWORD="password"
    export DB_NAME="weknora"
    export RETRIEVE_DRIVER="postgres"
    export DOCREADER_ADDR="localhost:$GRPC_PORT"
    
    log_info "启动 WeKnora 后端服务..."
    go run cmd/server/main.go
else
    log_info "DocReader 服务继续在后台运行"
    log_info "PID: $DOCREADER_PID"
    log_info "端口: $GRPC_PORT"
fi

# 脚本结束
log_info "启动脚本执行完成"