# WeKnora 数据库配置修复 - 快速解决方案

## 🚨 问题描述
如果您遇到以下错误：
```
panic: unsupported database driver:
```

## 🔧 快速修复

### 步骤1：设置环境变量
```bash
# 进入项目目录
cd /path/to/WeKnora

# 加载环境变量（已为您创建好）
source .env
```

### 步骤2：安装并启动PostgreSQL

#### 方法A：使用Homebrew (macOS)
```bash
# 安装PostgreSQL
brew install postgresql

# 启动PostgreSQL服务
brew services start postgresql

# 创建数据库和用户
./scripts/init_database.sh
```

#### 方法B：使用Docker (所有平台)
```bash
# 安装Docker后运行
./scripts/start_weknora.sh --dev
```

### 步骤3：启动WeKnora服务
```bash
# 方式1：使用启动脚本
./scripts/run_weknora.sh

# 方式2：手动启动
source .env && go run cmd/server/main.go
```

## ✅ 验证成功
如果看到类似以下输出，说明修复成功：
```
WeKnora服务启动中...
服务配置:
  数据库: postgres://weknora@localhost:5432/weknora_db
  存储类型: local
  检索引擎: postgres
```

## 📁 已创建的文件

- `.env` - 环境变量配置文件
- `docker-compose.dev.yml` - 开发环境Docker配置
- `scripts/init_database.sh` - 数据库初始化脚本
- `scripts/start_weknora.sh` - 服务启动脚本
- `scripts/run_weknora.sh` - WeKnora应用启动脚本
- `init_weknora.sql` - SQL初始化脚本
- `DATABASE_SETUP_GUIDE.md` - 详细设置指南

## 🆘 如果仍有问题

1. 检查环境变量：`source .env && env | grep DB_`
2. 测试数据库连接：`pg_isready -h localhost -p 5432`
3. 查看详细指南：`DATABASE_SETUP_GUIDE.md`

## 🎯 一键命令（如果您有Docker）
```bash
# 启动完整环境
./scripts/start_weknora.sh --dev

# 在新终端启动WeKnora
./scripts/run_weknora.sh
```

---
**问题已解决！** 现在您可以正常使用WeKnora了。