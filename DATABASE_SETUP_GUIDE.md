# WeKnora 数据库配置修复指南

## 概述

本指南解决WeKnora服务启动时出现的`unsupported database driver`错误，提供完整的配置修复方案。

## 错误症状

```
panic: unsupported database driver:
```

## 解决方案

### 方案1：使用Docker环境（推荐）

#### 1.1 安装Docker
首先确保系统已安装Docker和Docker Compose：

```bash
# macOS用户
brew install docker docker-compose

# Ubuntu用户
sudo apt update
sudo apt install docker.io docker-compose

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker
```

#### 1.2 启动开发环境
```bash
# 进入项目目录
cd /path/to/WeKnora

# 启动开发环境（包含PostgreSQL数据库）
./scripts/start_weknora.sh --dev

# 或者只启动依赖服务
./scripts/start_weknora.sh --local
```

#### 1.3 启动WeKnora服务
```bash
# 方式1：使用启动脚本
./scripts/run_weknora.sh

# 方式2：手动启动
source .env
go run cmd/server/main.go
```

### 方案2：本地PostgreSQL环境

#### 2.1 安装PostgreSQL
```bash
# macOS用户
brew install postgresql
brew services start postgresql

# Ubuntu用户
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 创建用户和数据库
sudo -u postgres psql
```

#### 2.2 手动创建数据库
```sql
-- 在PostgreSQL命令行中执行
CREATE USER weknora WITH PASSWORD 'weknora_password';
CREATE DATABASE weknora_db OWNER weknora;
GRANT ALL PRIVILEGES ON DATABASE weknora_db TO weknora;
\q
```

#### 2.3 或使用初始化脚本
```bash
# 使用项目提供的初始化脚本
./scripts/init_database.sh

# 或手动执行SQL文件
psql -U postgres -f init_weknora.sql
```

#### 2.4 启动WeKnora服务
```bash
# 加载环境变量并启动
source .env
go run cmd/server/main.go
```

## 配置文件说明

### 环境变量文件 (.env)
已为您创建了完整的环境变量配置文件，包含以下关键配置：

```bash
# 数据库配置
DB_DRIVER=postgres      # 数据库驱动类型
DB_HOST=localhost       # 数据库主机
DB_PORT=5432           # 数据库端口
DB_USER=weknora        # 数据库用户名
DB_PASSWORD=weknora_password  # 数据库密码
DB_NAME=weknora_db     # 数据库名称

# 存储配置
STORAGE_TYPE=local     # 存储类型
LOCAL_STORAGE_BASE_DIR=/tmp/weknora  # 本地存储目录

# 检索引擎配置
RETRIEVE_DRIVER=postgres  # 检索引擎类型
```

### 配置文件增强 (config/config.yaml)
已在config.yaml中添加了数据库配置段：

```yaml
# 数据库配置
database:
  driver: ${DB_DRIVER:postgres}
  host: ${DB_HOST:localhost}
  port: ${DB_PORT:5432}
  user: ${DB_USER:weknora}
  password: ${DB_PASSWORD:weknora_password}
  dbname: ${DB_NAME:weknora_db}
  sslmode: disable
  max_idle_conns: 10
  conn_max_lifetime: 600
```

## 验证配置

### 1. 检查环境变量
```bash
source .env
echo "DB_DRIVER: $DB_DRIVER"
echo "DB_HOST: $DB_HOST"
echo "DB_USER: $DB_USER"
echo "DB_NAME: $DB_NAME"
```

### 2. 测试数据库连接
```bash
# 使用psql测试连接
psql -h localhost -p 5432 -U weknora -d weknora_db -c "SELECT version();"

# 或使用pg_isready
pg_isready -h localhost -p 5432 -U weknora
```

### 3. 启动服务测试
```bash
# 方式1：使用检查脚本
./scripts/run_weknora.sh --check

# 方式2：直接启动
source .env && go run cmd/server/main.go
```

## 故障排除

### 常见问题及解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `unsupported database driver: ` | DB_DRIVER环境变量未设置或为空 | 执行 `source .env` 或设置 `export DB_DRIVER=postgres` |
| `connection refused` | PostgreSQL服务未启动 | 启动PostgreSQL服务或运行 `./scripts/start_weknora.sh --dev` |
| `authentication failed` | 用户名或密码错误 | 检查DB_USER和DB_PASSWORD环境变量 |
| `database "weknora_db" does not exist` | 数据库不存在 | 运行 `./scripts/init_database.sh` 创建数据库 |
| `permission denied` | 用户权限不足 | 为用户授予适当权限 |

### 调试命令

```bash
# 查看当前环境变量
env | grep DB_

# 检查PostgreSQL服务状态
brew services list | grep postgresql  # macOS
sudo systemctl status postgresql      # Linux

# 查看PostgreSQL日志
tail -f /usr/local/var/log/postgres.log  # macOS
sudo journalctl -u postgresql -f         # Linux

# 测试Go应用连接
cd /path/to/WeKnora
source .env
go run -v cmd/server/main.go
```

### Docker相关问题

```bash
# 检查Docker状态
docker --version
docker-compose --version

# 查看容器状态
docker-compose -f docker-compose.dev.yml ps

# 查看容器日志
docker-compose -f docker-compose.dev.yml logs postgres

# 重新构建容器
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up -d --build
```

## 快速启动命令

### 使用Docker（推荐）
```bash
# 一键启动开发环境
./scripts/start_weknora.sh --dev

# 启动WeKnora服务
./scripts/run_weknora.sh
```

### 使用本地PostgreSQL
```bash
# 1. 启动PostgreSQL服务
brew services start postgresql  # macOS
sudo systemctl start postgresql # Linux

# 2. 初始化数据库（仅首次）
./scripts/init_database.sh

# 3. 启动WeKnora服务
source .env && go run cmd/server/main.go
```

## 配置选项

### 存储配置
```bash
# 本地存储
export STORAGE_TYPE=local
export LOCAL_STORAGE_BASE_DIR=/tmp/weknora

# MinIO存储
export STORAGE_TYPE=minio
export MINIO_ENDPOINT=localhost:9000
export MINIO_ACCESS_KEY_ID=minioadmin
export MINIO_SECRET_ACCESS_KEY=minioadmin
export MINIO_BUCKET_NAME=weknora
```

### 检索引擎配置
```bash
# 仅使用PostgreSQL
export RETRIEVE_DRIVER=postgres

# 同时使用PostgreSQL和Elasticsearch
export RETRIEVE_DRIVER=postgres,elasticsearch_v8
export ELASTICSEARCH_ADDR=http://localhost:9200
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=your_password
```

## 性能优化

### 数据库连接池配置
在config.yaml中调整数据库连接参数：

```yaml
database:
  max_idle_conns: 10      # 最大空闲连接数
  conn_max_lifetime: 600  # 连接最大生存时间（秒）
```

### 并发配置
```bash
export CONCURRENCY_POOL_SIZE=10  # 并发池大小
```

## 安全配置

### 生产环境建议
1. 使用强密码
2. 启用SSL连接
3. 配置防火墙规则
4. 定期备份数据库

```bash
# 生产环境环境变量示例
export DB_PASSWORD=your_strong_password_here
export TENANT_AES_KEY=your_32_character_aes_key_here
```

## 监控和日志

### 启用分布式追踪
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_SERVICE_NAME=WeKnora
export OTEL_TRACES_EXPORTER=otlp
```

### 查看应用日志
```bash
# 启动时查看详细日志
source .env && go run cmd/server/main.go 2>&1 | tee weknora.log
```

## 联系支持

如果按照本指南操作后仍遇到问题，请提供以下信息：

1. 操作系统版本
2. Go版本 (`go version`)
3. PostgreSQL版本 (`psql --version`)
4. 错误日志内容
5. 环境变量配置 (`env | grep DB_`)

## 更新日志

- 2025-09-10: 初始版本，解决unsupported database driver错误
- 包含完整的环境配置和启动脚本
- 提供Docker和本地PostgreSQL两种部署方案