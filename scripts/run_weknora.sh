#!/bin/bash

# WeKnora 快速启动脚本
# 加载环境变量并启动WeKnora服务

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Go是否安装
check_go() {
    if ! command -v go &> /dev/null; then
        log_error "Go未安装，请先安装Go语言环境"
        exit 1
    fi
    
    log_info "Go版本: $(go version)"
}

# 检查环境变量文件
check_env_file() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        log_error ".env文件不存在，请先运行: ./scripts/start_weknora.sh --dev"
        exit 1
    fi
}

# 检查数据库连接
check_database() {
    source "$PROJECT_ROOT/.env"
    
    log_info "检查数据库连接..."
    
    # 检查pg_isready是否可用
    if command -v pg_isready &> /dev/null; then
        if pg_isready -h "${DB_HOST:-localhost}" -p "${DB_PORT:-5432}" -U "${DB_USER:-weknora}" > /dev/null 2>&1; then
            log_success "数据库连接正常"
        else
            log_error "无法连接到数据库"
            log_info "请确保数据库服务正在运行："
            log_info "  ./scripts/start_weknora.sh --dev"
            exit 1
        fi
    else
        log_warn "pg_isready未安装，跳过数据库连接检查"
    fi
}

# 检查必要的环境变量
check_env_vars() {
    source "$PROJECT_ROOT/.env"
    
    local required_vars=("DB_DRIVER" "DB_HOST" "DB_PORT" "DB_USER" "DB_PASSWORD" "DB_NAME")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "缺少必要的环境变量:"
        for var in "${missing_vars[@]}"; do
            log_error "  $var"
        done
        exit 1
    fi
    
    log_success "环境变量检查通过"
}

# 构建项目
build_project() {
    log_info "构建WeKnora项目..."
    cd "$PROJECT_ROOT"
    
    if go build -o bin/weknora cmd/server/main.go; then
        log_success "项目构建成功"
    else
        log_error "项目构建失败"
        exit 1
    fi
}

# 启动服务
start_service() {
    log_info "启动WeKnora服务..."
    cd "$PROJECT_ROOT"
    
    # 加载环境变量
    source .env
    
    # 显示配置信息
    log_info "服务配置:"
    log_info "  数据库: ${DB_DRIVER}://${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
    log_info "  存储类型: ${STORAGE_TYPE:-local}"
    log_info "  检索引擎: ${RETRIEVE_DRIVER:-postgres}"
    echo ""
    
    # 启动服务
    log_success "WeKnora服务启动中..."
    exec go run cmd/server/main.go
}

# 显示帮助信息
show_help() {
    cat << EOF
WeKnora 快速启动脚本

用法:
    $0 [选项]

选项:
    --build             构建项目后启动
    --check             只检查环境，不启动服务
    --help              显示此帮助信息

示例:
    $0                  # 直接启动服务
    $0 --build          # 构建后启动
    $0 --check          # 检查环境

注意:
    启动服务前请确保已运行:
    ./scripts/start_weknora.sh --dev

EOF
}

# 主函数
main() {
    cd "$PROJECT_ROOT"
    
    case "${1:-}" in
        --build)
            check_go
            check_env_file
            check_env_vars
            check_database
            build_project
            start_service
            ;;
        --check)
            check_go
            check_env_file
            check_env_vars
            check_database
            log_success "环境检查完成，可以启动服务"
            ;;
        --help|help|-h)
            show_help
            ;;
        "")
            check_go
            check_env_file
            check_env_vars
            check_database
            start_service
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"