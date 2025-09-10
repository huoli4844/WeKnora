#!/bin/bash

# WeKnora 数据库初始化脚本
# 用于创建数据库、用户和基本权限设置

set -e

# 默认配置
DEFAULT_DB_HOST="localhost"
DEFAULT_DB_PORT="5432"
DEFAULT_DB_USER="weknora"
DEFAULT_DB_PASSWORD="weknora_password"
DEFAULT_DB_NAME="weknora_db"
DEFAULT_ADMIN_USER="postgres"

# 从环境变量读取配置，如果没有则使用默认值
DB_HOST=${DB_HOST:-$DEFAULT_DB_HOST}
DB_PORT=${DB_PORT:-$DEFAULT_DB_PORT}
DB_USER=${DB_USER:-$DEFAULT_DB_USER}
DB_PASSWORD=${DB_PASSWORD:-$DEFAULT_DB_PASSWORD}
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}
ADMIN_USER=${POSTGRES_USER:-$DEFAULT_ADMIN_USER}

echo "==========================================="
echo "WeKnora 数据库初始化脚本"
echo "==========================================="
echo "数据库主机: $DB_HOST"
echo "数据库端口: $DB_PORT"
echo "数据库名称: $DB_NAME"
echo "用户名称: $DB_USER"
echo "==========================================="

# 检查PostgreSQL是否运行
echo "正在检查PostgreSQL连接..."
if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" > /dev/null 2>&1; then
    echo "错误: 无法连接到PostgreSQL服务器 ($DB_HOST:$DB_PORT)"
    echo "请确保PostgreSQL服务正在运行"
    exit 1
fi

echo "PostgreSQL连接正常"

# 创建数据库和用户的SQL脚本
INIT_SQL=$(cat << EOF
-- 创建用户（如果不存在）
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        RAISE NOTICE 'User $DB_USER created successfully';
    ELSE
        RAISE NOTICE 'User $DB_USER already exists';
    END IF;
END
\$\$;

-- 创建数据库（如果不存在）
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\\gexec

-- 授予用户权限
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
)

# 执行初始化SQL
echo "正在创建数据库和用户..."
if echo "$INIT_SQL" | psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres > /dev/null 2>&1; then
    echo "数据库和用户创建成功"
else
    echo "警告: 数据库初始化可能失败，但可能是因为资源已存在"
fi

# 连接到目标数据库并设置权限
echo "正在设置数据库权限..."
PERMISSION_SQL=$(cat << EOF
-- 授予schema权限
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;

-- 设置默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;
EOF
)

if echo "$PERMISSION_SQL" | psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" > /dev/null 2>&1; then
    echo "权限设置成功"
else
    echo "警告: 权限设置可能失败"
fi

# 验证连接
echo "正在验证数据库连接..."
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    echo "✅ 数据库初始化完成！"
    echo "连接信息:"
    echo "  主机: $DB_HOST"
    echo "  端口: $DB_PORT"
    echo "  数据库: $DB_NAME"
    echo "  用户: $DB_USER"
    echo ""
    echo "您现在可以使用以下命令启动WeKnora服务:"
    echo "  source .env && go run cmd/server/main.go"
else
    echo "❌ 数据库连接验证失败"
    exit 1
fi

echo "==========================================="