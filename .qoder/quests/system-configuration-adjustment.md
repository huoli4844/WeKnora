# 系统配置调整设计 - GPUStack模型服务集成

## 概述

本设计文档描述了如何将WeKnora系统的模型服务从默认配置调整为用户自己部署的GPUStack服务。调整涉及大语言模型、嵌入模型和重排序模型的配置，确保系统能够正确使用用户指定的模型服务。

## 目标需求

- **目标服务地址**: http://182.150.53.174:8299/v1/chat/completions
- **API密钥**: gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c
- **大语言模型**: deepseek-r1-0528-qwen3-8b
- **嵌入模型**: qwen3-embedding
- **重排序模型**: bge-reranker-v2-m3

## 当前系统架构

### 模型集成架构

```mermaid
graph TD
    A[WeKnora系统] --> B[配置管理层]
    B --> C[模型服务层]
    C --> D[聊天模型适配器]
    C --> E[嵌入模型适配器]
    C --> F[重排序模型适配器]
    
    D --> G[RemoteAPI Chat]
    E --> H[Embedding Service]
    F --> I[Rerank Service]
    
    G --> J[外部API服务]
    H --> J
    I --> J
    
    B --> K[config.yaml]
    K --> L[models配置数组]
```

### 配置结构分析

根据现有代码分析，WeKnora使用以下配置结构：

```yaml
models:
  - type: "chat"           # 模型类型：chat, embedding, rerank
    source: "openai"       # 模型来源：openai, ollama等
    model_name: "模型名称"
    parameters:
      base_url: "API基础URL"
      api_key: "API密钥"
```

## 配置调整方案

### 新模型配置结构

```mermaid
flowchart TD
    A[GPUStack服务] --> B[OpenAI兼容API]
    B --> C[Chat Completions接口]
    B --> D[Embeddings接口]
    B --> E[Rerank接口]
    
    F[WeKnora配置] --> G[Chat模型配置]
    F --> H[Embedding模型配置]
    F --> I[Rerank模型配置]
    
    G --> C
    H --> D
    I --> E
```

### 具体配置参数

#### 大语言模型配置
```yaml
models:
  - type: "chat"
    source: "openai"
    model_name: "deepseek-r1-0528-qwen3-8b"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      temperature: 0.7
      max_tokens: 2048
```

#### 嵌入模型配置
```yaml
  - type: "embedding"
    source: "openai"
    model_name: "qwen3-embedding"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      dimensions: 1024
```

#### 重排序模型配置
```yaml
  - type: "rerank"
    source: "openai"
    model_name: "bge-reranker-v2-m3"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      top_k: 10
```

## 配置文件调整

### config.yaml完整模型配置

需要在现有的config.yaml文件中添加models配置节，完整配置如下：

```yaml
# 现有配置保持不变...

# 模型服务配置
models:
  # 大语言模型配置
  - type: "chat"
    source: "openai"
    model_name: "deepseek-r1-0528-qwen3-8b"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      temperature: 0.7
      max_tokens: 2048
      top_p: 1.0
      frequency_penalty: 0.0
      presence_penalty: 0.0

  # 嵌入模型配置
  - type: "embedding"
    source: "openai"
    model_name: "qwen3-embedding"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      dimensions: 1024
      encoding_format: "float"

  # 重排序模型配置
  - type: "rerank"
    source: "openai"
    model_name: "bge-reranker-v2-m3"
    parameters:
      base_url: "http://182.150.53.174:8299/v1"
      api_key: "gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
      top_k: 10
      return_documents: true
```

## 技术实现细节

### 模型服务初始化流程

```mermaid
sequenceDiagram
    participant App as 应用启动
    participant Config as 配置管理
    participant ModelSvc as 模型服务
    participant Adapter as 适配器
    participant GPUStack as GPUStack服务

    App->>Config: 加载配置文件
    Config->>Config: 解析models配置
    App->>ModelSvc: 初始化模型服务
    ModelSvc->>Adapter: 创建OpenAI适配器
    Adapter->>GPUStack: 验证连接
    GPUStack-->>Adapter: 返回连接状态
    Adapter-->>ModelSvc: 确认初始化完成
    ModelSvc-->>App: 模型服务就绪
```

### 模型调用流程

```mermaid
sequenceDiagram
    participant User as 用户请求
    participant Handler as 请求处理器
    participant Service as 业务服务
    participant Adapter as 模型适配器
    participant GPUStack as GPUStack服务

    User->>Handler: 发起聊天请求
    Handler->>Service: 调用聊天服务
    Service->>Adapter: 获取Chat模型
    Adapter->>GPUStack: 调用/v1/chat/completions
    Note over GPUStack: 使用deepseek-r1-0528-qwen3-8b
    GPUStack-->>Adapter: 返回响应
    Adapter-->>Service: 处理后的结果
    Service-->>Handler: 业务处理结果
    Handler-->>User: 返回最终响应
```

## 配置验证策略

### 连接测试机制

```mermaid
flowchart TD
    A[启动时验证] --> B{配置检查}
    B -->|Valid| C[连接测试]
    B -->|Invalid| D[配置错误]
    
    C --> E{连接成功?}
    E -->|Yes| F[模型可用性检查]
    E -->|No| G[连接失败]
    
    F --> H{模型响应?}
    H -->|Yes| I[验证通过]
    H -->|No| J[模型不可用]
    
    D --> K[记录错误日志]
    G --> K
    J --> K
    K --> L[启动失败]
    
    I --> M[系统就绪]
```

### 验证测试用例

| 验证项目 | 测试方法 | 预期结果 |
|---------|----------|----------|
| API连接 | HTTP健康检查 | 200状态码 |
| 认证验证 | 带token的请求 | 成功认证 |
| Chat模型 | 简单对话测试 | 正常回复 |
| Embedding | 文本向量化 | 返回向量数组 |
| Rerank | 重排序测试 | 排序结果 |

## 环境变量支持

为了增强安全性，支持通过环境变量配置敏感信息：

```yaml
models:
  - type: "chat"
    source: "openai"
    model_name: "deepseek-r1-0528-qwen3-8b"
    parameters:
      base_url: "${GPUSTACK_BASE_URL}"
      api_key: "${GPUSTACK_API_KEY}"
```

对应的环境变量：
```bash
export GPUSTACK_BASE_URL="http://182.150.53.174:8299/v1"
export GPUSTACK_API_KEY="gpustack_b6070f918c567789_afcdc50334379ffc928c3e36a6f3a12c"
```

## 降级和容错策略

### 服务降级机制

```mermaid
flowchart TD
    A[模型调用] --> B{主服务可用?}
    B -->|Yes| C[正常调用GPUStack]
    B -->|No| D[记录错误]
    
    D --> E{有备用服务?}
    E -->|Yes| F[切换到备用服务]
    E -->|No| G[使用本地fallback]
    
    F --> H[记录降级日志]
    G --> I[返回默认响应]
    H --> J[继续服务]
    I --> J
```

### 配置回退选项

```yaml
conversation:
  fallback_strategy: "fixed"
  fallback_response: "抱歉，模型服务暂时不可用，请稍后重试。"
```

## 监控和日志

### 关键监控指标

| 指标类型 | 监控内容 | 告警阈值 |
|---------|----------|----------|
| 可用性 | 服务响应时间 | >5秒 |
| 错误率 | API调用失败率 | >5% |
| 性能 | 模型推理延迟 | >10秒 |
| 配额 | API调用次数 | 接近限制 |

### 日志记录策略

```mermaid
graph TD
    A[模型调用] --> B[记录请求日志]
    B --> C[执行调用]
    C --> D[记录响应日志]
    D --> E{调用成功?}
    E -->|Yes| F[记录成功指标]
    E -->|No| G[记录错误详情]
    
    F --> H[性能统计]
    G --> I[错误分析]
```

## 配置迁移步骤

### 实施计划

```mermaid
gantt
    title GPUStack模型配置迁移时间表
    dateFormat  YYYY-MM-DD
    section 准备阶段
    备份现有配置    :active, backup, 2024-01-01, 1d
    验证GPUStack服务 :verify, after backup, 1d
    
    section 配置阶段  
    更新config.yaml :config, after verify, 1d
    环境变量设置    :env, after config, 1d
    
    section 测试阶段
    连接测试       :test1, after env, 1d
    功能测试       :test2, after test1, 2d
    
    section 部署阶段
    灰度发布       :deploy1, after test2, 1d
    全量部署       :deploy2, after deploy1, 1d
```

### 回滚计划

```mermaid
flowchart TD
    A[发现问题] --> B[评估影响]
    B --> C{需要回滚?}
    C -->|Yes| D[停止服务]
    C -->|No| E[问题修复]
    
    D --> F[恢复原配置]
    F --> G[重启服务]
    G --> H[验证恢复]
    H --> I[服务正常]
    
    E --> J[在线修复]
    J --> I
```

## 性能优化考虑

### 连接池配置

```yaml
models:
  - type: "chat"
    parameters:
      # 连接池配置
      max_idle_conns: 10
      max_open_conns: 100
      conn_max_lifetime: "1h"
      timeout: "30s"
```

### 缓存策略

```mermaid
graph TD
    A[模型请求] --> B{缓存命中?}
    B -->|Yes| C[返回缓存结果]
    B -->|No| D[调用GPUStack]
    D --> E[存储到缓存]
    E --> F[返回结果]
    C --> G[更新访问时间]
    F --> H[完成响应]
    G --> H
```

## 安全考虑

### API密钥安全

- 使用环境变量存储敏感信息
- 定期轮换API密钥
- 限制网络访问来源
- 启用HTTPS通信

### 网络安全

```mermaid
graph TD
    A[WeKnora] -->|HTTPS| B[GPUStack服务]
    B --> C[模型推理服务]
    
    D[防火墙规则] --> E[只允许指定IP]
    E --> B
    
    F[SSL证书] --> G[加密传输]
    G --> B
```

## 单元测试策略

### 测试覆盖范围

```mermaid
graph TD
    A[配置测试] --> B[配置解析正确性]
    A --> C[环境变量替换]
    
    D[连接测试] --> E[网络连接]
    D --> F[认证验证]
    
    G[功能测试] --> H[Chat模型调用]
    G --> I[Embedding生成]
    G --> J[Rerank功能]
    
    K[异常测试] --> L[网络故障处理]
    K --> M[认证失败处理]
    K --> N[超时处理]
```

### 测试用例示例

| 测试场景 | 输入 | 预期输出 |
|---------|------|----------|
| 配置加载 | 有效的config.yaml | 成功加载模型配置 |
| API调用 | 标准聊天请求 | 正常返回响应 |
| 错误处理 | 无效的API密钥 | 抛出认证错误 |
| 超时处理 | 长时间无响应 | 超时异常 |