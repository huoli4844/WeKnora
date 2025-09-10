#!/bin/bash

# WeKnora 前端开发启动脚本

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
FRONTEND_DIR="$PROJECT_ROOT/frontend"

echo -e "${GREEN}WeKnora 前端开发脚本${NC}"
echo "前端目录: $FRONTEND_DIR"
echo ""

# 检查Node.js
check_node() {
    if ! command -v node &> /dev/null; then
        log_error "未安装Node.js，请先安装Node.js"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "未安装npm，请先安装npm"
        return 1
    fi
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "Node.js版本: $NODE_VERSION"
    log_success "npm版本: $NPM_VERSION"
    return 0
}

# 安装依赖
install_deps() {
    log_info "安装前端依赖..."
    cd "$FRONTEND_DIR"
    
    if [ ! -f "package.json" ]; then
        log_error "未找到package.json文件"
        return 1
    fi
    
    npm install
    if [ $? -eq 0 ]; then
        log_success "依赖安装成功"
        return 0
    else
        log_error "依赖安装失败"
        return 1
    fi
}

# 启动开发服务器
start_dev() {
    log_info "启动前端开发服务器..."
    cd "$FRONTEND_DIR"
    
    log_success "启动成功！"
    log_info "前端地址: http://localhost:5173"
    log_info "后端API: http://localhost:8080"
    log_info "按 Ctrl+C 停止服务"
    echo ""
    
    npm run dev
}

# 构建生产版本
build_prod() {
    log_info "构建生产版本..."
    cd "$FRONTEND_DIR"
    
    npm run build
    if [ $? -eq 0 ]; then
        log_success "构建完成，输出目录: $FRONTEND_DIR/dist"
        return 0
    else
        log_error "构建失败"
        return 1
    fi
}

# 显示帮助
show_help() {
    echo "WeKnora 前端开发脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  dev       启动开发服务器（默认）"
    echo "  build     构建生产版本"
    echo "  install   安装依赖"
    echo "  -h        显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 dev      # 启动开发服务器"
    echo "  $0 build    # 构建生产版本"
    echo "  $0 install  # 安装依赖"
}

# 主函数
main() {
    if ! check_node; then
        exit 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "前端目录不存在: $FRONTEND_DIR"
        exit 1
    fi
    
    case "${1:-dev}" in
        dev)
            install_deps && start_dev
            ;;
        build)
            install_deps && build_prod
            ;;
        install)
            install_deps
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