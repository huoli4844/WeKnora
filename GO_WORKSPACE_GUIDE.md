# WeKnora Go Workspace 配置指南

## 概述

本项目使用Go工作区（Go Workspace）来管理多个相关的Go模块。工作区功能从Go 1.18开始引入，允许在一个工作区中同时开发和构建多个模块。

## 项目结构

WeKnora项目包含以下Go模块：

```
WeKnora/
├── go.work                    # 工作区配置文件
├── go.mod                     # 主模块 (github.com/Tencent/WeKnora)
├── go.sum                     # 主模块依赖锁定文件
├── client/
│   ├── go.mod                 # 客户端模块 (github.com/Tencent/WeKnora/client)
│   ├── go.sum                 # 客户端模块依赖锁定文件
│   └── *.go                   # 客户端源码
└── ...                        # 其他项目文件
```

## 模块说明

### 1. 主模块 (github.com/Tencent/WeKnora)
- **路径**: 项目根目录
- **用途**: 主要的WeKnora应用程序
- **Go版本**: 1.24.0 (工具链 1.24.2)
- **主要依赖**: Gin, GORM, Elasticsearch, Redis等

### 2. 客户端模块 (github.com/Tencent/WeKnora/client)
- **路径**: `./client/`
- **用途**: WeKnora API的Go客户端库
- **Go版本**: 1.24.2
- **依赖**: 无外部依赖，仅使用标准库

## Go Workspace 配置

### go.work 文件内容
```go
go 1.24.2

use (
	.
	./client
)
```

### 配置说明
- `go 1.24.2`: 指定工作区使用的Go版本
- `use .`: 包含根目录的主模块
- `use ./client`: 包含client子目录的客户端模块

## 使用方法

### 1. 基本命令

```bash
# 查看工作区中的所有模块
go list -m all

# 列出工作区中的所有包
go list ./...

# 构建所有模块
go build ./...

# 运行测试
go test ./...

# 同步工作区依赖
go work sync
```

### 2. 模块间引用

由于配置了工作区，主模块可以直接引用客户端模块：

```go
package main

import (
    "github.com/Tencent/WeKnora/client"
)

func main() {
    // 创建客户端实例
    c := client.NewClient("http://localhost:8080")
    // ...
}
```

### 3. 独立开发

每个模块也可以独立开发和构建：

```bash
# 在客户端模块目录中工作
cd client/
go build .
go test .

# 在主模块目录中工作
cd ../
go build ./cmd/server
```

## 工作区优势

### 1. 统一依赖管理
- 所有模块的依赖在工作区级别统一管理
- 避免版本冲突
- 简化依赖更新

### 2. 跨模块开发
- 可以同时修改多个模块
- 支持本地模块引用
- 简化调试过程

### 3. 构建效率
- 共享构建缓存
- 减少重复编译
- 提高开发效率

## 最佳实践

### 1. 版本管理
- 保持所有模块的Go版本一致
- 定期运行 `go work sync` 同步依赖
- 使用相同的工具链版本

### 2. 依赖管理
```bash
# 添加依赖到特定模块
cd client/
go get github.com/example/package

# 更新工作区依赖
cd ..
go work sync
```

### 3. 构建和测试
```bash
# 构建特定模块
go build ./client/...

# 运行特定模块测试
go test ./client/...

# 构建所有模块
go build ./...
```

## 故障排除

### 1. 常见问题

#### 模块未被识别
```bash
# 检查工作区状态
go work use -r .

# 手动添加模块
go work use ./client
```

#### 依赖冲突
```bash
# 清理模块缓存
go clean -modcache

# 重新同步依赖
go work sync
```

### 2. 调试命令

```bash
# 查看工作区信息
go env GOWORK

# 显示模块信息
go list -m -f '{{.Path}} {{.Dir}}' all

# 检查模块依赖
go mod graph
```

## 开发工作流

### 1. 日常开发
```bash
# 1. 启动开发环境
cd /path/to/WeKnora

# 2. 检查工作区状态
go work sync

# 3. 开发和测试
go build ./...
go test ./...

# 4. 运行应用
go run cmd/server/main.go
```

### 2. 添加新模块
```bash
# 1. 创建新模块目录
mkdir new-module
cd new-module

# 2. 初始化模块
go mod init github.com/Tencent/WeKnora/new-module

# 3. 添加到工作区
cd ..
go work use ./new-module
```

## 性能优化

### 1. 构建优化
- 使用并行构建: `go build -p 4 ./...`
- 启用构建缓存: `export GOCACHE=/tmp/go-cache`

### 2. 测试优化
- 并行测试: `go test -p 4 ./...`
- 短测试模式: `go test -short ./...`

## 兼容性

- **Go版本**: 需要Go 1.18+
- **IDE支持**: VSCode、GoLand等主流IDE都支持Go工作区
- **CI/CD**: 大部分CI系统支持Go工作区

## 相关资源

- [Go工作区官方文档](https://go.dev/doc/tutorial/workspaces)
- [Go模块参考](https://go.dev/ref/mod)
- [WeKnora项目文档](./README.md)

---

**注意**: 本配置已经过测试验证，可以直接使用。如果遇到问题，请参考故障排除部分或查看相关日志。