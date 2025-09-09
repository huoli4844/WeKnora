# GPUStack模型服务集成配置指南

本文档描述如何将WeKnora系统配置为使用GPUStack模型服务。

## 🎯 配置概述

GPUStack服务提供以下模型：
- **聊天模型**: `deepseek-r1-0528-qwen3-8b`
- **嵌入模型**: `qwen3-embedding` (2560维度)
- **重排序模型**: `bge-reranker-v2-m3`

服务地址: `http://182.150.53.174:8299/v1/`

## 📁 配置文件说明

项目提供了三种配置方式：

### 1. 直接配置版本 (`config/config.yaml`)
已更新的主配置文件，包含完整的GPUStack模型配置。

### 2. 环境变量版本 (`config/config-gpustack.yaml`)
使用环境变量占位符的配置文件，提供更好的安全性。

### 3. 环境变量模板 (`.env.gpustack`)
包含所有必需环境变量的模板文件。

## 🚀 快速开始

### 方式一：使用直接配置（推荐快速测试）

1. 当前的 `config/config.yaml` 已经配置完成，直接使用即可
2. 确保GPUStack服务可访问
3. 配置数据库连接环境变量：
   ```bash
   export DB_DRIVER=postgres
   export DB_HOST=localhost
   export DB_PORT=5432
   export DB_USER=postgres
   export DB_PASSWORD=postgres
   export DB_NAME=WeKnora
   ```

### 方式二：使用环境变量（推荐生产环境）

1. 复制环境变量模板：
   ```bash
   cp .env.gpustack .env
   ```

2. 编辑 `.env` 文件，根据需要修改配置

3. 使用环境变量版配置：
   ```bash
   cp config/config-gpustack.yaml config/config.yaml
   ```

4. 启动服务：
   ```bash
   source .env
   go run cmd/server/main.go
   ```

## ⚙️ 配置详解

### 模型配置结构

```yaml
models:
  - type: "chat|embedding|rerank"     # 模型类型
    source: "openai"                  # 模型来源（使用OpenAI兼容API）
    model_name: "模型名称"              # GPUStack中的模型名称
    parameters:                       # 模型参数
      base_url: "服务地址"             # GPUStack API地址
      api_key: "API密钥"              # 认证密钥
      # 其他模型特定参数...
```

### 聊天模型参数

| 参数 | 值 | 说明 |
|-----|---|------|
| `base_url` | `http://182.150.53.174:8299/v1` | GPUStack API地址 |
| `api_key` | `gpustack_b6070f918c567789_...` | 认证密钥 |
| `temperature` | `0.7` | 创造性控制 |
| `max_tokens` | `2048` | 最大输出长度 |

### 嵌入模型参数

| 参数 | 值 | 说明 |
|-----|---|------|
| `dimensions` | `2560` | 向量维度 |
| `encoding_format` | `"float"` | 编码格式 |

### 重排序模型参数

| 参数 | 值 | 说明 |
|-----|---|------|
| `top_k` | `10` | 返回结果数量 |
| `return_documents` | `true` | 是否返回文档内容 |

## 🔧 环境变量说明

### 核心模型配置
```bash
# GPUStack服务配置
GPUSTACK_BASE_URL=http://182.150.53.174:8299/v1
GPUSTACK_API_KEY=gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c
```

### 数据库配置
```bash
# 数据库连接（必需）
DB_DRIVER=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=WeKnora
```

### 存储配置
```bash
# 文件存储
STORAGE_TYPE=local
LOCAL_STORAGE_BASE_DIR=./data/files
```

## ✅ 验证配置

### 1. 检查GPUStack服务连通性
```bash
curl -H "Authorization: Bearer gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c" \
     -H "Content-Type: application/json" \
     http://182.150.53.174:8299/v1/models
```

### 2. 测试聊天模型
```bash
curl -H "Authorization: Bearer gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c" \
     -H "Content-Type: application/json" \
     -d '{"model":"deepseek-r1-0528-qwen3-8b","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}' \
     http://182.150.53.174:8299/v1/chat/completions
```

### 3. 验证配置加载
```bash
# 检查YAML语法
python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"

# 或使用Go验证
go run -c 'package main; import ("gopkg.in/yaml.v3"; "os"); func main() {data,_:=os.ReadFile("config/config.yaml"); var c map[string]interface{}; yaml.Unmarshal(data,&c)}'
```

## 🔒 安全考虑

### API密钥管理
- **开发环境**: 可以直接在配置文件中使用API密钥
- **生产环境**: 建议使用环境变量方式，避免将密钥提交到代码仓库

### 网络安全
- 确保GPUStack服务网络可达性
- 考虑使用HTTPS（如果GPUStack支持）
- 配置防火墙规则限制访问来源

## 🐛 常见问题排查

### 1. 连接失败
- 检查网络连通性：`ping 182.150.53.174`
- 验证端口开放：`telnet 182.150.53.174 8299`
- 确认API密钥正确

### 2. 认证失败
- 检查API密钥格式
- 确认密钥权限
- 验证请求头格式

### 3. 模型不可用
- 通过`/v1/models`接口检查模型状态
- 确认模型名称拼写正确
- 检查模型是否在运行状态

### 4. 配置加载失败
- 验证YAML语法正确性
- 检查环境变量是否正确设置
- 确认配置文件路径正确

## 📚 相关文档

- [WeKnora系统架构](./docs/architecture.md)
- [模型集成开发指南](./docs/model-integration.md)
- [API参考文档](./docs/api.md)

## 🔄 配置更新

如需修改模型配置：

1. 编辑 `config/config.yaml` 或对应环境变量
2. 重启服务以应用新配置
3. 通过系统健康检查接口验证配置生效

配置更新后，建议进行完整的功能测试以确保系统正常工作。