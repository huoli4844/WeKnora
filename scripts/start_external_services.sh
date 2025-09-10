#!/bin/bash

# WeKnora 外部服务启动脚本（用于源码调试）
# 仅启动必要的外部服务，不启动WeKnora本身

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# 加载环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

echo -e "${GREEN}WeKnora 外部服务启动脚本${NC}"
echo "此脚本将启动必要的外部服务用于源码调试"
echo ""

# 检查Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "未安装Docker，请先安装Docker"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请先启动Docker"
        return 1
    fi
    
    return 0
}

# 启动PostgreSQL
start_postgres() {
    log_info "启动PostgreSQL数据库..."
    
    # 检查是否已经运行
    if docker ps --format "table {{.Names}}" | grep -q "weknora-postgres-debug"; then
        log_success "PostgreSQL已在运行"
        return 0
    fi
    
    # 启动PostgreSQL容器
    docker run -d \
        --name weknora-postgres-debug \
        -p ${DB_PORT:-5432}:5432 \
        -e POSTGRES_USER=${DB_USER:-postgres} \
        -e POSTGRES_PASSWORD=${DB_PASSWORD:-postgres123} \
        -e POSTGRES_DB=${DB_NAME:-WeKnora} \
        -v weknora-postgres-debug-data:/var/lib/postgresql/data \
        postgres:13-alpine
    
    # 等待数据库启动
    log_info "等待PostgreSQL启动..."
    sleep 5
    
    # 检查连接
    if docker exec weknora-postgres-debug pg_isready -U ${DB_USER:-postgres} &> /dev/null; then
        log_success "PostgreSQL启动成功"
        echo "  连接信息:"
        echo "    主机: localhost"
        echo "    端口: ${DB_PORT:-5432}"
        echo "    用户: ${DB_USER:-postgres}"
        echo "    数据库: ${DB_NAME:-WeKnora}"
        return 0
    else
        log_error "PostgreSQL启动失败"
        return 1
    fi
}

# 启动Redis
start_redis() {
    log_info "启动Redis..."
    
    # 检查是否已经运行
    if docker ps --format "table {{.Names}}" | grep -q "weknora-redis-debug"; then
        log_success "Redis已在运行"
        return 0
    fi
    
    # 启动Redis容器
    docker run -d \
        --name weknora-redis-debug \
        -p ${REDIS_PORT:-6379}:6379 \
        redis:7.0-alpine \
        redis-server --requirepass ${REDIS_PASSWORD:-redis123}
    
    # 等待Redis启动
    sleep 2
    
    # 检查连接
    if docker exec weknora-redis-debug redis-cli ping &> /dev/null; then
        log_success "Redis启动成功"
        echo "  连接信息:"
        echo "    主机: localhost"
        echo "    端口: ${REDIS_PORT:-6379}"
        echo "    密码: ${REDIS_PASSWORD:-redis123}"
        return 0
    else
        log_error "Redis启动失败"
        return 1
    fi
}

# 启动Ollama
start_ollama() {
    log_info "启动Ollama服务..."
    
    # 检查是否已经运行
    if docker ps --format "table {{.Names}}" | grep -q "weknora-ollama-debug"; then
        log_success "Ollama已在运行"
        return 0
    fi
    
    # 启动Ollama容器
    docker run -d \
        --name weknora-ollama-debug \
        -p 11434:11434 \
        -v weknora-ollama-debug-data:/root/.ollama \
        ollama/ollama
    
    # 等待Ollama启动
    log_info "等待Ollama启动..."
    sleep 10
    
    # 检查连接
    if curl -s http://localhost:11434/api/tags &> /dev/null; then
        log_success "Ollama启动成功"
        echo "  连接信息:"
        echo "    API地址: http://localhost:11434"
        log_info "你可以使用以下命令安装模型:"
        echo "    docker exec weknora-ollama-debug ollama pull qwen2.5:7b"
        echo "    docker exec weknora-ollama-debug ollama pull nomic-embed-text"
        return 0
    else
        log_error "Ollama启动失败"
        return 1
    fi
}

# 停止所有服务
stop_services() {
    log_info "停止所有调试服务..."
    
    for container in weknora-postgres-debug weknora-redis-debug weknora-ollama-debug; do
        if docker ps -q -f name=$container | grep -q .; then
            log_info "停止容器: $container"
            docker stop $container
            docker rm $container
        fi
    done
    
    log_success "所有服务已停止"
}

# 显示服务状态
show_status() {
    log_info "服务状态:"
    echo ""
    
    for container in weknora-postgres-debug weknora-redis-debug weknora-ollama-debug; do
        if docker ps -q -f name=$container | grep -q .; then
            echo -e "  ${GREEN}✓${NC} $container (运行中)"
        else
            echo -e "  ${RED}✗${NC} $container (未运行)"
        fi
    done
    
    echo ""
    log_info "Docker容器详情:"
    docker ps --filter "name=weknora-*-debug" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 显示帮助
show_help() {
    echo "WeKnora 外部服务管理脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start     启动所有外部服务"
    echo "  stop      停止所有外部服务"
    echo "  status    显示服务状态"
    echo "  postgres  仅启动PostgreSQL"
    echo "  redis     仅启动Redis"
    echo "  ollama    仅启动Ollama"
    echo "  -h        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start    # 启动所有服务"
    echo "  $0 postgres # 仅启动PostgreSQL"
    echo "  $0 status   # 查看状态"
    echo "  $0 stop     # 停止所有服务"
}

# 主函数
main() {
    if ! check_docker; then
        exit 1
    fi
    
    case "${1:-start}" in
        start)
            start_postgres
            start_redis
            start_ollama
            echo ""
            show_status
            echo ""
            log_success "外部服务启动完成！现在可以运行源码调试脚本："
            echo "  ./scripts/debug_run.sh"
            ;;
        stop)
            stop_services
            ;;
        status)
            show_status
            ;;
        postgres)
            start_postgres
            ;;
        redis)
            start_redis
            ;;
        ollama)
            start_ollama
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"