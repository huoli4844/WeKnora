# WeKnora 系统运行与GPUStack集成设计

## 概述

本文档描述如何正确启动WeKnora系统并集成您的GPUStack大模型配置。WeKnora是一个基于Go的全栈RAG（检索增强生成）系统，支持知识库管理、向量检索和智能对话功能。

## 技术架构

### 系统组件
- **后端服务**: Go语言开发的API服务器
- **前端应用**: Vue.js构建的Web界面  
- **数据存储**: PostgreSQL/ParadeDB作为主数据库
- **模型服务**: 通过GPUStack提供的大语言模型API

### 核心依赖
```mermaid
graph TB
    A[WeKnora Server] --> B[PostgreSQL/ParadeDB]
    A --> C[GPUStack API]
    A --> D[前端静态文件]
    
    C --> E[Chat Model: deepseek-r1-0528-qwen3-8b]
    C --> F[Embedding Model: qwen3-embedding]
    C --> G[Rerank Model: bge-reranker-v2-m3]
    
    B --> H[知识库数据]
    B --> I[会话记录]
    B --> J[向量索引]
```

## 配置管理

### GPUStack模型配置
当前配置文件中已包含完整的GPUStack集成配置：

| 模型类型 | 模型名称 | 用途 |
|---------|---------|------|
| Chat | deepseek-r1-0528-qwen3-8b | 对话生成 |
| Embedding | qwen3-embedding | 文本向量化 |
| Rerank | bge-reranker-v2-m3 | 检索结果重排序 |

### 数据库配置需求
系统需要PostgreSQL数据库支持，配置项包括：
- 数据库连接信息（主机、端口、用户名、密码）
- 连接池参数
- 扩展插件（uuid-ossp, vector, pg_trgm, pg_search）

## 系统启动流程

### 启动前置条件
1. **数据库服务就绪**
   - PostgreSQL服务正常运行
   - 数据库已执行初始化脚本
   - 必要扩展已安装

2. **GPUStack服务可用**
   - API端点: `http://182.150.53.174:8299`
   - 认证密钥已配置

3. **配置文件完整**
   - 数据库连接参数
   - 模型服务参数
   - 服务器监听配置

### 启动命令
```bash
# 在项目根目录执行
go run cmd/server/main.go
```

### 启动验证
服务正常启动后将显示：
- 服务器监听地址（默认: 0.0.0.0:8080）
- 数据库连接状态
- 模型服务连接状态

## 数据库初始化

### 自动初始化（推荐）
使用Docker Compose进行一键部署：
```bash
# 启动完整服务栈
docker-compose up -d

# 查看服务状态  
docker-compose ps
```

### 手动初始化
```bash
# 执行数据库迁移脚本
./scripts/migrate.sh up

# 验证数据库结构
psql -h localhost -U postgres -d weknora -c "\dt"
```

### 核心表结构
- `tenants`: 租户管理
- `knowledge_bases`: 知识库元数据
- `knowledge`: 知识文档
- `chunks`: 文档分块
- `embeddings`: 向量嵌入
- `sessions`: 会话管理
- `messages`: 消息记录

## 服务集成验证

### GPUStack连接测试
```bash
# 测试Chat模型
curl -X POST "http://182.150.53.174:8299/v1/chat/completions" \
  -H "Authorization: Bearer gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1-0528-qwen3-8b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'

# 测试Embedding模型
curl -X POST "http://182.150.53.174:8299/v1/embeddings" \
  -H "Authorization: Bearer gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-embedding", 
    "input": ["测试文本"]
  }'
```

### 系统健康检查
```bash
# 检查服务状态
curl http://localhost:8080/health

# 检查API可用性
curl http://localhost:8080/api/v1/models
```

## 故障排除

### 常见启动问题

1. **数据库连接失败**
   - 检查PostgreSQL服务状态
   - 验证连接参数（主机、端口、凭据）
   - 确认数据库已创建

2. **模型服务连接失败**  
   - 验证GPUStack服务可访问性
   - 检查API密钥有效性
   - 确认模型名称正确性

3. **端口占用冲突**
   - 检查8080端口是否被其他服务占用
   - 修改配置文件中的端口设置

### 日志分析
```bash
# 启用详细日志
export GIN_MODE=debug
go run cmd/server/main.go

# 查看Docker容器日志
docker-compose logs -f weknora-server
```

## 部署优化建议

### 生产环境配置
1. **数据库优化**
   - 配置适当的连接池大小
   - 启用数据库查询缓存
   - 定期维护向量索引

2. **模型服务优化**  
   - 配置请求超时参数
   - 实施负载均衡策略
   - 监控API配额使用

3. **系统监控**
   - 集成日志聚合工具
   - 配置健康检查端点
   - 设置性能指标监控