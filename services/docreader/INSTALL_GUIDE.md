# DocReader 依赖安装指南

## 问题描述
在安装 DocReader 服务依赖时可能遇到以下问题：
1. textract 包的 metadata 版本规范错误
2. paddlepaddle 包体积过大导致网络超时

## 解决方案

### 1. 基础依赖安装（推荐）
```bash
# 清理 pip 缓存
pip cache purge

# 升级 pip
pip install --upgrade pip

# 安装核心依赖（避免大包问题）
pip install -r requirements.txt --timeout 300
```

### 2. 分步安装（网络不稳定时使用）
```bash
# 步骤1: 安装核心依赖
pip install grpcio grpcio-tools protobuf python-docx PyPDF2 pypdf pdfplumber

# 步骤2: 安装处理库
pip install requests Pillow beautifulsoup4 lxml markdownify mistletoe markdown

# 步骤3: 安装工具库
pip install urllib3 asyncio python-magic docx2txt openpyxl antiword

# 步骤4: 安装云存储和AI服务
pip install cos-python-sdk-v5 minio openai ollama

# 步骤5: 安装网络爬虫相关
pip install playwright goose3
```

### 3. 可选的 OCR 依赖安装（单独安装）
```bash
# 仅在需要 OCR 功能时安装
pip install -r requirements-ocr.txt --timeout 600

# 或者手动安装
pip install paddleocr>=2.10.0,<3.0.0
pip install --extra-index-url https://www.paddlepaddle.org.cn/packages/stable/cpu/ paddlepaddle>=3.0.0,<4.0.0
```

## 系统依赖
在 macOS 上还需要安装系统级依赖：
```bash
# 安装 libmagic (用于 python-magic)
brew install libmagic

# 安装 antiword (用于处理 .doc 文件)
brew install antiword
```

## 常见问题及解决方案

### 1. textract 问题
- **问题**: textract 的版本规范不兼容新版 pip
- **解决**: 已从 requirements.txt 中移除，使用更稳定的替代库

### 2. paddlepaddle 下载超时
- **问题**: 包体积大（99.4 MB），下载容易超时
- **解决**: 
  - 分离到单独的 requirements-ocr.txt
  - 增加超时时间：`--timeout 600`
  - 或使用代理/镜像源

### 3. python-magic 问题
- **问题**: 需要系统级 libmagic 库
- **解决**: `brew install libmagic`

## 验证安装
```bash
# 测试导入核心模块
python -c "import grpc, google.protobuf, docx, PyPDF2, pypdf, pdfplumber"

# 测试文档处理库
python -c "import magic, docx2txt, openpyxl"

# 测试 AI 服务连接
python -c "import openai, ollama"
```

## 注意事项
1. OCR 功能是可选的，如不需要可跳过 paddlepaddle 安装
2. 建议在虚拟环境中安装依赖
3. 网络不稳定时使用分步安装方式
4. macOS 用户需要安装额外的系统依赖