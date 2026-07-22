-- ==================== 阅读引擎位置提示 ====================
-- 存储引擎私有的位置恢复信息（Readium Locator JSON）。
-- 与 reading_progress 表分离：逻辑位置 vs 引擎加速提示。
-- Builtin 引擎不使用此表。

CREATE TABLE IF NOT EXISTS reading_engine_positions (
    book_id TEXT PRIMARY KEY,
    engine_kind TEXT NOT NULL,
    publication_fingerprint TEXT NOT NULL DEFAULT '',
    opaque_position TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
);
