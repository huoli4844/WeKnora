#!/bin/bash

# WeKnora 服务启动脚本
# 用于快速启动WeKnora服务及其依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 显示帮助信息
show_help() {
    cat << EOF
WeKnora 服务启动脚本

用法:
    $0 [选项]

选项:
    --dev               启动开发环境 (使用docker-compose.dev.yml)
    --production        启动生产环境 (使用docker-compose.yml)
    --local             启动本地开发环境 (仅启动依赖服务)
    --stop              停止所有服务
    --restart           重启所有服务
    --logs              查看服务日志
    --status            查看服务状态
    --help              显示此帮助信息

示例:
    $0 --dev            # 启动开发环境
    $0 --local          # 启动本地开发环境
    $0 --stop           # 停止所有服务
    $0 --logs           # 查看日志

EOF
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
}

# 检查环境变量文件
check_env_file() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        log_warn ".env文件不存在，正在创建默认配置..."
        create_default_env
    fi
}

# 创建默认环境变量文件
create_default_env() {
    cat > "$PROJECT_ROOT/.env" << 'EOF'
# WeKnora 数据库配置
DB_DRIVER=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=weknora
DB_PASSWORD=weknora_password
DB_NAME=weknora_db

# 存储配置
STORAGE_TYPE=local
LOCAL_STORAGE_BASE_DIR=/tmp/weknora

# 检索引擎配置
RETRIEVE_DRIVER=postgres

# 其他配置
GIN_MODE=debug
CONCURRENCY_POOL_SIZE=5
DOCREADER_ADDR=localhost:50051
EOF
    log_success "已创建默认.env文件"
}

# 启动开发环境
start_dev() {
    log_info "启动开发环境..."
    cd "$PROJECT_ROOT"
    
    check_env_file
    
    # 启动依赖服务
    docker-compose -f docker-compose.dev.yml up -d
    
    # 等待服务启动
    log_info "等待数据库服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker-compose -f docker-compose.dev.yml ps | grep -q "Up"; then
        log_success "开发环境启动成功！"
        log_info "数据库连接信息:"
        log_info "  主机: localhost"
        log_info "  端口: 5432"
        log_info "  数据库: weknora_db"
        log_info "  用户: weknora"
        echo ""
        log_info "现在可以启动WeKnora应用:"
        log_info "  source .env && go run cmd/server/main.go"
    else
        log_error "开发环境启动失败"
        exit 1
    fi
}

# 启动生产环境
start_production() {
    log_info "启动生产环境..."
    cd "$PROJECT_ROOT"
    
    check_env_file
    
    # 启动所有服务
    docker-compose up -d
    
    log_success "生产环境启动成功！"
    log_info "访问地址: http://localhost"
}

# 启动本地开发环境
start_local() {
    log_info "启动本地开发环境（仅依赖服务）..."
    cd "$PROJECT_ROOT"
    
    check_env_file
    
    # 只启动数据库和Redis
    docker-compose -f docker-compose.dev.yml up -d postgres redis
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 检查服务状态
    if docker-compose -f docker-compose.dev.yml ps postgres | grep -q "Up"; then
        log_success "本地开发环境启动成功！"
        echo ""
        log_info "现在可以使用以下命令启动WeKnora:"
        log_info "  cd $PROJECT_ROOT"
        log_info "  source .env"
        log_info "  go run cmd/server/main.go"
    else
        log_error "本地开发环境启动失败"
        exit 1
    fi
}

# 停止服务
stop_services() {
    log_info "停止所有服务..."
    cd "$PROJECT_ROOT"
    
    # 停止生产环境
    if [ -f docker-compose.yml ]; then
        docker-compose down
    fi
    
    # 停止开发环境
    if [ -f docker-compose.dev.yml ]; then
        docker-compose -f docker-compose.dev.yml down
    fi
    
    log_success "所有服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    stop_services
    sleep 2
    start_dev
}

# 查看日志
show_logs() {
    cd "$PROJECT_ROOT"
    if [ -f docker-compose.dev.yml ]; then
        docker-compose -f docker-compose.dev.yml logs -f
    elif [ -f docker-compose.yml ]; then
        docker-compose logs -f
    else
        log_error "未找到docker-compose配置文件"
        exit 1
    fi
}

# 查看服务状态
show_status() {
    cd "$PROJECT_ROOT"
    
    log_info "开发环境状态:"
    if [ -f docker-compose.dev.yml ]; then
        docker-compose -f docker-compose.dev.yml ps
    fi
    
    echo ""
    log_info "生产环境状态:"
    if [ -f docker-compose.yml ]; then
        docker-compose ps
    fi
}

# 主函数
main() {
    cd "$PROJECT_ROOT"
    
    # 检查Docker
    check_docker
    
    case "${1:-}" in
        --dev)
            start_dev
            ;;
        --production)
            start_production
            ;;
        --local)
            start_local
            ;;
        --stop)
            stop_services
            ;;
        --restart)
            restart_services
            ;;
        --logs)
            show_logs
            ;;
        --status)
            show_status
            ;;
        --help|help|-h)
            show_help
            ;;
        "")
            log_info "使用默认模式启动开发环境..."
            start_dev
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