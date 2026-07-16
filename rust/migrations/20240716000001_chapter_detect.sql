-- ==================== TXT 章节检测配置 ====================
-- 用户可自定义正则规则集，按命名 scope 分组，多本书可共用同一 scope。

-- 用户自定义的命名 scope
CREATE TABLE IF NOT EXISTS chapter_detect_scopes (
    scope       TEXT PRIMARY KEY,  -- 用户自定义名称
    created_at  INTEGER NOT NULL DEFAULT (unixepoch())
);

-- 每个 scope 下的检测正则（按 pattern_order 排序执行）
CREATE TABLE IF NOT EXISTS chapter_detect_patterns (
    scope         TEXT NOT NULL,
    pattern_order INTEGER NOT NULL,
    pattern_name  TEXT NOT NULL,
    regex         TEXT NOT NULL,
    enabled       INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (scope, pattern_order),
    FOREIGN KEY (scope) REFERENCES chapter_detect_scopes(scope) ON DELETE CASCADE
);

-- 书籍 → scope 关联
ALTER TABLE books ADD COLUMN detect_scope TEXT NOT NULL DEFAULT 'global';
