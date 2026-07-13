-- Zephyr Reader 数据库初始建表
-- 全量建表（非发布阶段，不提供增量迁移）

-- ==================== 书籍（热字段） ====================

CREATE TABLE IF NOT EXISTS books (
    id              TEXT PRIMARY KEY,
    file_path       TEXT NOT NULL,
    file_hash       TEXT,
    file_size       INTEGER NOT NULL,
    file_mtime      INTEGER,
    title           TEXT NOT NULL,
    author          TEXT,
    chapter_count   INTEGER DEFAULT 0,
    total_characters INTEGER DEFAULT 0,
    format          TEXT NOT NULL,
    added_at        INTEGER NOT NULL,
    last_opened_at  INTEGER,
    status          TEXT DEFAULT 'planned',
    is_pinned       INTEGER DEFAULT 0,
    cover_path      TEXT
);

CREATE INDEX IF NOT EXISTS idx_books_file_hash ON books(file_hash);
CREATE INDEX IF NOT EXISTS idx_books_status_last_open ON books(status, last_opened_at);
CREATE INDEX IF NOT EXISTS idx_books_pinned_last_open ON books(is_pinned, last_opened_at);

-- ==================== 书籍元数据（冷字段） ====================

CREATE TABLE IF NOT EXISTS book_metadata (
    book_id     TEXT PRIMARY KEY,
    description TEXT,
    publisher   TEXT,
    translator  TEXT,
    isbn        TEXT,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

-- ==================== 章节 ====================

-- 内容定位由 ChapterContentProvider 通过 (book_id, chapter_index) 完成
-- TXT/MD: 按文件偏移范围读取; EPUB: 按 spine 索引获取; PDF: 按页码渲染
CREATE TABLE IF NOT EXISTS chapters (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    title           TEXT NOT NULL,
    chapter_index   INTEGER NOT NULL,
    cached_at       INTEGER NOT NULL,
    level           INTEGER NOT NULL DEFAULT 0,
    start_index     INTEGER NOT NULL DEFAULT 0,
    end_index       INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters(book_id);
CREATE INDEX IF NOT EXISTS idx_chapters_index ON chapters(book_id, chapter_index);

-- ==================== 阅读进度 ====================

CREATE TABLE IF NOT EXISTS reading_progress (
    book_id               TEXT PRIMARY KEY,
    chapter_index         INTEGER NOT NULL DEFAULT 0,
    chunk_index           INTEGER NOT NULL DEFAULT 0,
    chapter_id            TEXT,
    char_offset           INTEGER NOT NULL DEFAULT 0,
    progress              REAL NOT NULL DEFAULT 0.0,
    reading_time_seconds  INTEGER NOT NULL DEFAULT 0,
    last_read_at          INTEGER NOT NULL,
    page_index            INTEGER NOT NULL DEFAULT 0,
    total_pages           INTEGER NOT NULL DEFAULT 0,
    is_completed          INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_progress_last_read ON reading_progress(last_read_at);

-- ==================== 书签 ====================

CREATE TABLE IF NOT EXISTS bookmarks (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    chapter_index   INTEGER NOT NULL,
    chapter_id      TEXT,
    char_offset     INTEGER NOT NULL,
    title           TEXT NOT NULL,
    created_at      INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_chapter ON bookmarks(book_id, chapter_index);

-- ==================== 笔记 ====================

CREATE TABLE IF NOT EXISTS notes (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    chapter_index   INTEGER NOT NULL,
    chapter_id      TEXT,
    char_offset     INTEGER NOT NULL,
    length          INTEGER NOT NULL DEFAULT 0,
    note_type       TEXT NOT NULL,
    content         TEXT NOT NULL DEFAULT '',
    selected_text   TEXT,
    highlight_color INTEGER,
    paired_note_id  TEXT,
    language        TEXT,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notes_book ON notes(book_id);
CREATE INDEX IF NOT EXISTS idx_notes_chapter ON notes(book_id, chapter_index);
CREATE INDEX IF NOT EXISTS idx_notes_type ON notes(book_id, note_type);
CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_unique ON notes(book_id, chapter_index, char_offset, length, note_type, language);
CREATE INDEX IF NOT EXISTS idx_notes_paired ON notes(paired_note_id);

-- ==================== 阅读会话 ====================

CREATE TABLE IF NOT EXISTS reading_sessions (
    id                  TEXT PRIMARY KEY,
    book_id             TEXT NOT NULL,
    chapter_index       INTEGER NOT NULL,
    start_char_offset   INTEGER NOT NULL,
    end_char_offset     INTEGER NOT NULL,
    started_at          INTEGER NOT NULL,
    ended_at            INTEGER NOT NULL,
    duration_seconds    INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_book ON reading_sessions(book_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON reading_sessions(started_at);

-- ==================== 阅读统计 ====================

CREATE TABLE IF NOT EXISTS reading_stats (
    book_id               TEXT NOT NULL,
    date                  TEXT NOT NULL,
    reading_time_seconds  INTEGER DEFAULT 0,
    characters_read       INTEGER DEFAULT 0,
    session_count         INTEGER DEFAULT 0,
    last_session_id       TEXT,
    PRIMARY KEY (book_id, date),
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reading_stats_date ON reading_stats(date);

-- ==================== 分类 ====================

CREATE TABLE IF NOT EXISTS categories (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    description TEXT,
    color       TEXT,
    sort_order  INTEGER DEFAULT 0,
    is_system   INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS book_categories (
    book_id     TEXT NOT NULL,
    category_id TEXT NOT NULL,
    PRIMARY KEY (book_id, category_id),
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- ==================== 全文搜索 ====================

CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
    content,
    book_id UNINDEXED,
    chapter_id UNINDEXED,
    chapter_index UNINDEXED,
    chapter_title UNINDEXED,
    position UNINDEXED
);

-- ==================== 词典 ====================

CREATE TABLE IF NOT EXISTS dictionaries (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    file_path   TEXT NOT NULL UNIQUE,
    dict_type   TEXT NOT NULL,
    lang_from   TEXT,
    lang_to     TEXT,
    is_enabled  INTEGER DEFAULT 1,
    word_count  INTEGER DEFAULT 0,
    added_at    INTEGER NOT NULL
);

-- ==================== 生词本 ====================

CREATE TABLE IF NOT EXISTS vocabulary_words (
    id              TEXT PRIMARY KEY,
    word            TEXT NOT NULL,
    pinyin          TEXT NOT NULL DEFAULT '',
    translation     TEXT NOT NULL,
    context_sentence TEXT,
    book_id         TEXT,
    chapter_index   INTEGER,
    char_offset     INTEGER,
    created_at      INTEGER NOT NULL,
    review_count    INTEGER DEFAULT 0,
    last_reviewed_at INTEGER,
    word_list       TEXT,
    status          TEXT DEFAULT 'unstarted',
    dict_source     TEXT REFERENCES dictionaries(id) ON DELETE SET NULL,
    dict_entry_hash TEXT
);

CREATE INDEX IF NOT EXISTS idx_vocab_word ON vocabulary_words(word);
CREATE INDEX IF NOT EXISTS idx_vocab_book ON vocabulary_words(book_id);
CREATE INDEX IF NOT EXISTS idx_vocab_status ON vocabulary_words(status);
CREATE INDEX IF NOT EXISTS idx_vocab_book_status ON vocabulary_words(book_id, status);
