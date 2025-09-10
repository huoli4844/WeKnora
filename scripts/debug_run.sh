#!/bin/bash

# WeKnora 源码调试运行脚本
# 此脚本用于启动必要的外部服务并从源码运行主程序

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 获取项目根目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo -e "${GREEN}WeKnora 源码调试运行脚本${NC}"
echo "项目路径: $PROJECT_ROOT"
echo ""

# 检查Go环境
log_info "检查Go环境..."
if ! command -v go &> /dev/null; then
    log_error "未安装Go，请先安装Go 1.24+"
    exit 1
fi

GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
log_success "Go版本: $GO_VERSION"

# 检查.env文件
log_info "检查环境配置..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    log_error ".env文件不存在，请先配置环境变量"
    exit 1
fi

# 加载环境变量
source "$PROJECT_ROOT/.env"
log_success "环境变量已加载"

# 创建数据目录
log_info "创建必要的目录..."
mkdir -p "$PROJECT_ROOT/data/files"
mkdir -p "$PROJECT_ROOT/logs"

# 检查PostgreSQL
check_postgres() {
    log_info "检查PostgreSQL连接..."
    if command -v psql &> /dev/null; then
        if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT 1;" &> /dev/null; then
            log_success "PostgreSQL连接正常"
            return 0
        fi
    fi
    
    log_warning "PostgreSQL未连接或未配置，请检查以下设置："
    echo "  主机: $DB_HOST"
    echo "  端口: $DB_PORT"
    echo "  用户: $DB_USER"
    echo "  数据库: $DB_NAME"
    return 1
}

# 检查Redis
check_redis() {
    log_info "检查Redis连接..."
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h localhost -p ${REDIS_PORT:-6379} ping &> /dev/null; then
            log_success "Redis连接正常"
            return 0
        fi
    fi
    
    log_warning "Redis未连接，将使用内存模式"
    return 1
}

# 检查Ollama
check_ollama() {
    log_info "检查Ollama服务..."
    if curl -s "${OLLAMA_BASE_URL:-http://localhost:11434}/api/tags" &> /dev/null; then
        log_success "Ollama服务可用"
        return 0
    else
        log_warning "Ollama服务不可用，请确保Ollama已启动"
        return 1
    fi
}

# 编译项目
build_project() {
    log_info "编译WeKnora主程序..."
    cd "$PROJECT_ROOT"
    
    if go build -o bin/weknora ./cmd/server; then
        log_success "编译成功"
        return 0
    else
        log_error "编译失败"
        return 1
    fi
}

# 启动DocReader服务
start_docreader() {
    log_info "启动DocReader服务..."
    
    # 检查DocReader目录
    DOCREADER_DIR="$PROJECT_ROOT/services/docreader"
    if [ ! -d "$DOCREADER_DIR" ]; then
        log_error "DocReader目录不存在: $DOCREADER_DIR"
        return 1
    fi
    
    cd "$DOCREADER_DIR"
    
    # 检查Python环境
    if ! command -v python3 &> /dev/null; then
        log_error "未安装Python3，DocReader服务需要Python3"
        return 1
    fi
    
    # 检查依赖
    if [ ! -f "requirements.txt" ]; then
        log_error "未找到requirements.txt文件"
        return 1
    fi
    
    # 检查是否有虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建Python虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境并安装依赖
    source venv/bin/activate
    
    log_info "安装Python依赖..."
    pip install -r requirements.txt
    
    # 启动DocReader服务（后台运行）
    log_info "启动DocReader服务（后台运行）..."
    nohup python3 -m src.server.server > "$PROJECT_ROOT/logs/docreader.log" 2>&1 &
    DOCREADER_PID=$!
    echo $DOCREADER_PID > "$PROJECT_ROOT/logs/docreader.pid"
    
    # 等待服务启动
    sleep 3
    
    # 验证服务启动
    if lsof -i :50051 &> /dev/null; then
        log_success "DocReader服务已启动 (PID: $DOCREADER_PID)"
        return 0
    else
        log_error "DocReader服务启动失败"
        return 1
    fi
}

# 运行主程序
run_main() {
    log_info "启动WeKnora主程序..."
    cd "$PROJECT_ROOT"
    
    # 设置调试环境变量
    export GIN_MODE=debug
    
    log_success "正在启动WeKnora服务..."
    log_info "API地址: http://localhost:8080"
    log_info "按 Ctrl+C 停止服务"
    echo ""
    
    # 运行主程序
    ./bin/weknora
}

# 清理函数
cleanup() {
    log_info "清理进程..."
    
    # 停止DocReader服务
    if [ -f "$PROJECT_ROOT/logs/docreader.pid" ]; then
        DOCREADER_PID=$(cat "$PROJECT_ROOT/logs/docreader.pid")
        if kill -0 $DOCREADER_PID 2>/dev/null; then
            log_info "停止DocReader服务 (PID: $DOCREADER_PID)"
            kill $DOCREADER_PID
        fi
        rm -f "$PROJECT_ROOT/logs/docreader.pid"
    fi
    
    log_success "清理完成"
}

# 注册清理函数
trap cleanup EXIT

# 主流程
main() {
    # 检查外部服务
    check_postgres
    POSTGRES_OK=$?
    
    check_redis
    REDIS_OK=$?
    
    check_ollama
    OLLAMA_OK=$?
    
    # 如果PostgreSQL不可用，提示用户
    if [ $POSTGRES_OK -ne 0 ]; then
        echo ""
        log_error "PostgreSQL不可用，这是运行WeKnora的必要条件"
        echo "请先启动PostgreSQL服务，或者使用Docker启动："
        echo "  docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=$DB_PASSWORD postgres:13"
        echo ""
        read -p "是否继续？（可能会失败）[y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 编译项目
    if ! build_project; then
        log_error "编译失败，无法继续"
        exit 1
    fi
    
    # 启动DocReader服务
    if ! start_docreader; then
        log_warning "DocReader服务启动失败，文档解析功能可能不可用"
    fi
    
    # 运行主程序
    run_main
}

# 显示帮助信息
show_help() {
    echo "WeKnora 源码调试运行脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -b, --build    仅编译，不运行"
    echo "  -c, --check    仅检查环境，不运行"
    echo ""
    echo "示例:"
    echo "  $0             # 编译并运行"
    echo "  $0 --build     # 仅编译"
    echo "  $0 --check     # 检查环境"
}

# 解析命令行参数
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -b|--build)
        build_project
        exit $?
        ;;
    -c|--check)
        check_postgres
        check_redis  
        check_ollama
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "未知选项: $1"
        show_help
        exit 1
        ;;
esac