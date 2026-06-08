-- 为 chapters 表添加 start_index 和 end_index 字段
-- 用于记录章节在原始文件中的字节偏移范围（TXT/MD 格式）
ALTER TABLE chapters ADD COLUMN start_index INTEGER NOT NULL DEFAULT 0;
ALTER TABLE chapters ADD COLUMN end_index INTEGER NOT NULL DEFAULT 0;
