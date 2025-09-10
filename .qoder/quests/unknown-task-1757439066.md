# WeKnora数据库配置修复设计文档

## 概述

本设计文档针对WeKnora服务启动时出现的`unsupported database driver`错误进行分析并提供解决方案。该错误是由于缺少必要的数据库环境变量配置导致的。

## 问题分析

### 错误现象
```
panic: could not build arguments for function "github.com/Tencent/WeKnora/internal/application/service/chat_pipline".NewPluginSearch: 
failed to build *gorm.DB: received non-nil error from function "github.com/Tencent/WeKnora/internal/container".initDatabase: 
unsupported database driver:
```

### 根本原因
通过分析`internal/container/container.go`的`initDatabase`函数，发现该错误是由于以下环境变量缺失导致的：
- `DB_DRIVER`: 数据库驱动类型
- `DB_HOST`: 数据库主机地址  
- `DB_PORT`: 数据库端口
- `DB_USER`: 数据库用户名
- `DB_PASSWORD`: 数据库密码
- `DB_NAME`: 数据库名称

## 系统架构

### 数据库配置架构图

```mermaid
graph TB
    A[WeKnora服务启动] --> B[container.initDatabase()]
    B --> C{检查DB_DRIVER环境变量}
    C -->|postgres| D[创建PostgreSQL连接]
    C -->|空值或其他| E[抛出unsupported database driver错误]
    D --> F[配置连接池参数]
    F --> G[返回GORM数据库实例]
    
    H[环境变量配置] --> I[DB_DRIVER=postgres]
    H --> J[DB_HOST]
    H --> K[DB_PORT] 
    H --> L[DB_USER]
    H --> M[DB_PASSWORD]
    H --> N[DB_NAME]
    
    I --> C
    J --> D
    K --> D
    L --> D
    M --> D
    N --> D
```

### 配置层级结构

```mermaid
graph LR
    A[config.yaml] --> B[应用配置]
    C[环境变量] --> D[数据库配置]
    E[Docker环境] --> F[容器配置]
    
    B --> G[Viper配置管理]
    D --> G
    F --> G
    
    G --> H[container.initDatabase()]
    H --> I[GORM数据库连接]
```

## 解决方案设计

### 方案1：环境变量配置（推荐）

#### 配置步骤
1. **创建环境变量配置文件**
```bash
# 在项目根目录创建 .env 文件
export DB_DRIVER=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=weknora
export DB_PASSWORD=your_password
export DB_NAME=weknora_db
```

2. **加载环境变量**
```bash
# 方式1：直接在终端设置
source .env

# 方式2：启动时指定
DB_DRIVER=postgres DB_HOST=localhost DB_PORT=5432 DB_USER=weknora DB_PASSWORD=your_password DB_NAME=weknora_db go run cmd/server/main.go
```

#### 数据库初始化脚本
```sql
-- 创建数据库和用户
CREATE DATABASE weknora_db;
CREATE USER weknora WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE weknora_db TO weknora;

-- 切换到weknora_db数据库
\c weknora_db;

-- 授予schema权限
GRANT ALL ON SCHEMA public TO weknora;
```

### 方案2：Docker Compose配置

#### docker-compose.yml配置示例
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: weknora_db
      POSTGRES_USER: weknora
      POSTGRES_PASSWORD: your_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./migrations/paradedb/00-init-db.sql:/docker-entrypoint-initdb.d/00-init-db.sql
  
  weknora:
    build: .
    environment:
      DB_DRIVER: postgres
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: weknora
      DB_PASSWORD: your_password
      DB_NAME: weknora_db
    depends_on:
      - postgres
    ports:
      - "8080:8080"

volumes:
  postgres_data:
```

### 方案3：配置文件增强

#### 修改config.yaml支持数据库配置
```yaml
# 在config.yaml中添加数据库配置段
database:
  driver: postgres
  host: ${DB_HOST:localhost}
  port: ${DB_PORT:5432}
  user: ${DB_USER:weknora}
  password: ${DB_PASSWORD}
  dbname: ${DB_NAME:weknora_db}
  sslmode: disable
```

## 附加服务配置

### 存储服务配置
```bash
# 文件存储配置
export STORAGE_TYPE=local
export LOCAL_STORAGE_BASE_DIR=/tmp/weknora

# 或使用MinIO
export STORAGE_TYPE=minio
export MINIO_ENDPOINT=localhost:9000
export MINIO_ACCESS_KEY_ID=minioadmin
export MINIO_SECRET_ACCESS_KEY=minioadmin
export MINIO_BUCKET_NAME=weknora
```

### 检索引擎配置
```bash
# 检索引擎配置
export RETRIEVE_DRIVER=postgres

# 如需要Elasticsearch支持
export RETRIEVE_DRIVER=postgres,elasticsearch_v8
export ELASTICSEARCH_ADDR=http://localhost:9200
export ELASTICSEARCH_USERNAME=elastic
export ELASTICSEARCH_PASSWORD=your_es_password
```

## 验证步骤

### 1. 数据库连接验证
```bash
# 使用psql验证数据库连接
psql -h localhost -p 5432 -U weknora -d weknora_db -c "SELECT version();"
```

### 2. 服务启动验证
```bash
# 设置环境变量后启动服务
export DB_DRIVER=postgres
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=weknora
export DB_PASSWORD=your_password
export DB_NAME=weknora_db

go run cmd/server/main.go
```

### 3. 健康检查
```bash
# 检查服务是否正常启动
curl http://localhost:8080/health

# 检查数据库表是否创建成功
psql -h localhost -p 5432 -U weknora -d weknora_db -c "\dt"
```

## 故障排除

### 常见问题及解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `unsupported database driver: ` | DB_DRIVER环境变量未设置 | 设置`DB_DRIVER=postgres` |
| `connection refused` | 数据库服务未启动 | 启动PostgreSQL服务 |
| `authentication failed` | 用户名密码错误 | 检查DB_USER和DB_PASSWORD |
| `database does not exist` | 数据库不存在 | 创建目标数据库 |
| `permission denied` | 用户权限不足 | 授予用户适当权限 |

### 调试命令
```bash
# 查看当前环境变量
env | grep DB_

# 测试数据库连接
pg_isready -h localhost -p 5432

# 查看服务日志
go run cmd/server/main.go 2>&1 | tee weknora.log
```

## 最佳实践

### 安全考虑
1. **敏感信息保护**：使用环境变量而非硬编码存储密码
2. **最小权限原则**：为应用创建专用数据库用户，仅授予必要权限
3. **连接加密**：生产环境启用SSL连接

### 性能优化
1. **连接池配置**：合理设置`SetMaxIdleConns`和`SetConnMaxLifetime`
2. **索引优化**：为常用查询字段创建适当索引
3. **监控配置**：设置数据库性能监控

### 部署建议
1. **环境隔离**：开发、测试、生产环境使用不同的数据库实例
2. **备份策略**：配置定期数据库备份
3. **版本管理**：使用数据库迁移脚本管理schema变更

## 实施时间线

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 准备阶段 | 安装PostgreSQL，创建数据库 | 30分钟 |
| 配置阶段 | 设置环境变量，修改配置文件 | 15分钟 |
| 测试阶段 | 验证数据库连接，启动服务 | 15分钟 |
| 优化阶段 | 性能调优，安全加固 | 30分钟 |

## 风险评估

### 高风险项
- **数据丢失**：错误的数据库配置可能导致数据覆盖
- **安全漏洞**：密码明文存储或权限配置过宽

### 风险缓解措施
- 在非生产环境先行测试
- 备份现有数据库
- 使用强密码和适当的权限控制
- 定期安全审计