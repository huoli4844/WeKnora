-- WeKnora 数据库初始化SQL脚本
-- 用于Docker容器初始化

-- 创建weknora用户
CREATE USER weknora WITH PASSWORD 'weknora_password';

-- 创建weknora_db数据库
CREATE DATABASE weknora_db OWNER weknora;

-- 授予权限
GRANT ALL PRIVILEGES ON DATABASE weknora_db TO weknora;

-- 连接到weknora_db数据库
\c weknora_db;

-- 授予schema权限
GRANT ALL ON SCHEMA public TO weknora;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO weknora;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO weknora;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO weknora;

-- 设置默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO weknora;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO weknora;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO weknora;