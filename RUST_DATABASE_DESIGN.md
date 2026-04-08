# Rust 引擎数据库设计文档

> **Zephyr Reader** - 离线小说阅读器 Rust 存储层完整设计文档  
> 最后更新：2026-04-07 | 数据库版本：**v4**

---

## 目录

- [1. 技术架构](#1-技术架构)
- [2. 数据库初始化](#2-数据库初始化)
- [3. 数据表结构](#3-数据表结构)
  - [3.1 books - 书籍元数据](#31-books---书籍元数据)
  - [3.2 reading_progress - 阅读进度](#32-reading_progress---阅读进度)
  - [3.3 bookmarks - 书签](#33-bookmarks---书签)
  - [3.4 notes - 笔记/高亮](#34-notes---笔记高亮)
  - [3.5 reading_sessions - 阅读会话](#35-reading_sessions---阅读会话)
  - [3.6 daily_stats - 每日统计](#36-daily_stats---每日统计)
  - [3.7 chapters - 章节元数据](#37-chapters---章节元数据)
  - [3.8 categories - 书籍分类](#38-categories---书籍分类)
  - [3.9 book_categories - 书籍-分类关联](#39-book_categories---书籍-分类关联)
  - [3.10 search_index - FTS5 全文搜索](#310-search_index---fts5-全文搜索)
  - [3.11 sync_records - 同步状态](#311-sync_records---同步状态)
  - [3.12 layout_cache - 排版缓存 (sled KV)](#312-layout_cache---排版缓存-sled-kv)
- [4. 数据模型枚举](#4-数据模型枚举)
- [5. 外键关系图](#5-外键关系图)
- [6. 索引设计](#6-索引设计)
- [7. 触发器](#7-触发器)
- [8. 仓库模式架构](#8-仓库模式架构)
- [9. 线程安全设计](#9-线程安全设计)
- [10. 数据库版本管理](#10-数据库版本管理)
- [11. API 暴露层](#11-api-暴露层)
- [12. 关键文件路径](#12-关键文件路径)

---

## 1. 技术架构

### 双存储引擎

| 存储类型 | 库 | 版本 | 用途 | 数据文件 |
|---------|-----|------|------|----------|
| **关系型数据库** | `rusqlite` (bundled SQLite) | 0.31 | 核心业务数据持久化 | `{data_dir}/reader.db` |
| **KV 存储** | `sled` | 0.34 | 排版缓存等高频/可重建数据 | `{data_dir}/cache/` |

### 序列化

| 库 | 版本 | 用途 |
|-----|------|------|
| `bincode` | 1.3 | sled KV 值的二进制序列化 |
| `serde` | - | Rust 结构体序列化 |
| `chrono` | - | 时间处理 (DateTime<Utc>) |
| `uuid` | - | UUID 主键生成 |

### SQLite 配置

```sql
PRAGMA foreign_keys = ON;              -- 启用外键约束
PRAGMA journal_mode = WAL;             -- Write-Ahead Logging 模式
PRAGMA synchronous = NORMAL;           -- 平衡性能与安全
PRAGMA busy_timeout = 5000;            -- 5 秒繁忙超时
PRAGMA wal_autocheckpoint = 1000;      -- 每 1000 页自动检查点
```

### 关键特性

- ✅ **静态编译**: SQLite 通过 `bundled` 特性静态链接，无需系统依赖
- ✅ **WAL 模式**: 支持并发读写，提升性能
- ✅ **FTS5 扩展**: 全文搜索支持，`unicode61` 分词器
- ✅ **外键级联**: 所有关联数据设置 `ON DELETE CASCADE`

---

## 2. 数据库初始化

### 全局单例管理

```rust
use once_cell::sync::OnceCell;
static STORAGE: OnceCell<Arc<StorageManager>> = OnceCell::new();
```

### 初始化流程

```
init_storage(data_dir)
    └── StorageManager::new(data_dir)
         ├── Database::new("{data_dir}/reader.db")
         │    ├── 打开/创建连接
         │    ├── 设置 PRAGMA 配置
         │    └── migrate() -> 创建表结构
         └── KvStore::new("{data_dir}/cache/")
              └── 初始化 sled 数据库
```

### 版本检查逻辑

```rust
fn migrate(&mut self) -> Result<()> {
    let version = get_user_version();  // 默认 0
    
    if version == 0 {
        create_tables();               // 首次创建
        set_user_version(4);           // 标记为 v4
    } else if version < 4 {
        bail!("数据库版本过旧，请删除重建");  // 不兼容旧版
    }
    Ok(())
}
```

### 优雅关闭

```rust
impl Drop for Database {
    fn drop(&mut self) {
        // WAL checkpoint 确保数据刷盘
        self.conn.pragma_update(None, "wal_checkpoint", "TRUNCATE");
    }
}
```

---

## 3. 数据表结构

### 3.1 books - 书籍元数据

**用途**: 存储书籍的基本信息、状态和管理属性

```sql
CREATE TABLE books (
    book_id             TEXT PRIMARY KEY,
    file_path           TEXT NOT NULL UNIQUE,
    file_size           INTEGER NOT NULL,
    title               TEXT NOT NULL,
    author              TEXT,
    description         TEXT,
    cover_path          TEXT,
    chapter_count       INTEGER DEFAULT 0,
    total_characters    INTEGER DEFAULT 0,
    format              TEXT NOT NULL,           -- 'txt' | 'epub' | 'pdf'
    added_at            INTEGER NOT NULL,         -- Unix timestamp (秒)
    last_opened_at      INTEGER,                  -- Unix timestamp (可空)
    status              TEXT DEFAULT 'reading',   -- 'reading' | 'completed' | 'dropped' | 'planned'
    is_pinned           INTEGER DEFAULT 0         -- 0 或 1
);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct DbBookRecord {
    pub book_id: String,
    pub file_path: String,
    pub file_size: i64,
    pub title: String,
    pub author: String,
    pub description: Option<String>,
    pub cover_path: Option<String>,
    pub chapter_count: i32,
    pub total_characters: i64,
    pub format: DbBookFormat,
    pub added_at: DateTime<Utc>,
    pub last_opened_at: Option<DateTime<Utc>>,
    pub status: DbBookStatus,
    pub is_pinned: bool,
}
```

#### 字段说明

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| book_id | String | - | UUID 主键，唯一标识 |
| file_path | String | - | 本地文件绝对路径 |
| file_size | i64 | - | 文件大小（字节） |
| title | String | - | 书名 |
| author | String | - | 作者名 |
| description | Option<String> | NULL | 书籍简介 |
| cover_path | Option<String> | NULL | 封面图片路径 |
| chapter_count | i32 | 0 | 章节总数 |
| total_characters | i64 | 0 | 总字符数 |
| format | DbBookFormat | - | 文件格式枚举 |
| added_at | DateTime<Utc> | - | 添加时间 |
| last_opened_at | Option<DateTime<Utc>> | NULL | 最后打开时间 |
| status | DbBookStatus | 'reading' | 阅读状态枚举 |
| is_pinned | bool | false | 是否置顶 |

#### 查询方法

| 方法 | SQL | 说明 |
|------|-----|------|
| `get_all_books()` | JOIN reading_progress ORDER BY last_read_at DESC | 获取所有书，按最后阅读时间排序 |
| `get_book(id)` | WHERE book_id = ? | 按 ID 查询 |
| `search_books(keyword)` | WHERE title LIKE ? OR author LIKE ? | 模糊搜索 |
| `get_books_by_status(status)` | WHERE status = ? | 按状态筛选 |
| `get_pinned_books()` | WHERE is_pinned = 1 | 获取置顶书籍 |
| `get_recently_read_books(limit)` | WHERE last_read_at IS NOT NULL LIMIT ? | 获取最近阅读 |

---

### 3.2 reading_progress - 阅读进度

**用途**: 记录每本书的阅读进度，支持断点续读

```sql
CREATE TABLE reading_progress (
    book_id                 TEXT PRIMARY KEY,
    chapter_index           INTEGER NOT NULL DEFAULT 0,
    char_offset             INTEGER NOT NULL DEFAULT 0,
    page_index              INTEGER NOT NULL DEFAULT 0,
    total_pages             INTEGER NOT NULL DEFAULT 0,
    progress                REAL NOT NULL DEFAULT 0.0,      -- 0.0 ~ 1.0
    reading_time_seconds    INTEGER NOT NULL DEFAULT 0,
    last_read_at            INTEGER NOT NULL,
    is_completed            INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

CREATE INDEX idx_progress_last_read ON reading_progress(last_read_at);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb]
pub struct DbReadingProgress {
    pub book_id: String,
    pub chapter_index: i32,
    pub char_offset: i64,
    pub page_index: i32,
    pub total_pages: i32,
    pub progress: f32,
    pub reading_time_seconds: i64,
    pub last_read_at: DateTime<Utc>,
    pub is_completed: bool,
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| book_id | String | 外键 (1:1 关联 books) |
| chapter_index | i32 | 当前章节索引（从 0 开始） |
| char_offset | i64 | 当前字符偏移量 |
| page_index | i32 | 当前页码（从 0 开始） |
| total_pages | i32 | 总页数 |
| progress | f32 | 进度比例 (0.0 = 未开始, 1.0 = 完成) |
| reading_time_seconds | i64 | 累计阅读时长（秒） |
| last_read_at | DateTime<Utc> | 最后阅读时间 |
| is_completed | bool | 是否已读完 |

#### 自动计算逻辑

```rust
// ProgressRepository::save_progress()
progress.progress = page_index as f32 / total_pages as f32;
progress.is_completed = progress.progress >= 1.0;
progress.last_read_at = chrono::Utc::now();
```

---

### 3.3 bookmarks - 书签

**用途**: 记录用户的阅读位置标记，纯位置信息

```sql
CREATE TABLE bookmarks (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    chapter_index   INTEGER NOT NULL,
    char_offset     INTEGER NOT NULL,
    title           TEXT NOT NULL,
    created_at      INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

CREATE INDEX idx_bookmarks_book ON bookmarks(book_id);
CREATE INDEX idx_bookmarks_chapter ON bookmarks(book_id, chapter_index);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbBookmark {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub char_offset: i64,
    pub title: String,
    pub created_at: DateTime<Utc>,
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | UUID 主键 |
| book_id | String | 外键 |
| chapter_index | i32 | 章节索引 |
| char_offset | i64 | 字符偏移位置 |
| title | String | 书签标题（默认 "Chapter N"） |
| created_at | DateTime<Utc> | 创建时间 |

#### 批量操作

```rust
// 使用事务批量插入，避免逐条锁定
pub fn save_bookmarks_batch(&mut self, bookmarks: &[DbBookmark]) -> Result<()> {
    let tx = self.conn.transaction()?;
    // ... 批量 INSERT
    tx.commit()?;
    Ok(())
}
```

---

### 3.4 notes - 笔记/高亮

**用途**: 存储用户的高亮标记和注释笔记

```sql
CREATE TABLE notes (
    id                  TEXT PRIMARY KEY,
    book_id             TEXT NOT NULL,
    chapter_index       INTEGER NOT NULL,
    char_offset         INTEGER NOT NULL,
    length              INTEGER NOT NULL DEFAULT 0,     -- 选中文本长度
    note_type           TEXT NOT NULL,                  -- 'highlight' | 'annotation'
    content             TEXT NOT NULL DEFAULT '',       -- 笔记内容
    selected_text       TEXT,                           -- 选中的原文
    highlight_color     INTEGER,                        -- 颜色值 (ARGB)
    created_at          INTEGER NOT NULL,
    updated_at          INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

CREATE INDEX idx_notes_book ON notes(book_id);
CREATE INDEX idx_notes_chapter ON notes(book_id, chapter_index);
CREATE INDEX idx_notes_type ON notes(book_id, note_type);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbNote {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub char_offset: i64,
    pub length: i64,
    pub note_type: DbNoteType,
    pub content: String,
    pub selected_text: Option<String>,
    pub highlight_color: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | UUID 主键 |
| book_id | String | 外键 |
| chapter_index | i32 | 章节索引 |
| char_offset | i64 | 起始字符偏移 |
| length | i64 | 选中文本长度（0 表示无选中） |
| note_type | DbNoteType | Highlight / Annotation |
| content | String | 笔记正文 |
| selected_text | Option<String> | 选中的原文片段 |
| highlight_color | Option<i32> | 高亮颜色值 (ARGB 格式) |
| created_at | DateTime<Utc> | 创建时间 |
| updated_at | DateTime<Utc> | 最后更新时间 |

#### 工厂方法

```rust
impl DbNote {
    pub fn highlight(book_id, chapter_index, char_offset, length, selected_text, color) -> Self {
        Self { note_type: DbNoteType::Highlight, highlight_color: Some(color), ... }
    }
    pub fn annotation(book_id, chapter_index, char_offset, content, selected_text) -> Self {
        Self { note_type: DbNoteType::Annotation, content, ... }
    }
}
```

---

### 3.5 reading_sessions - 阅读会话

**用途**: 记录每次阅读的起止时间、持续时长，用于统计分析

```sql
CREATE TABLE reading_sessions (
    id                  TEXT PRIMARY KEY,
    book_id             TEXT NOT NULL,
    chapter_index       INTEGER NOT NULL,
    start_char_offset   INTEGER NOT NULL,
    end_char_offset     INTEGER NOT NULL,
    started_at          INTEGER NOT NULL,
    ended_at            INTEGER NOT NULL,
    duration_seconds    INTEGER NOT NULL,
    characters_read     INTEGER NOT NULL,
    start_timestamp     INTEGER,
    end_timestamp       INTEGER,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_book ON reading_sessions(book_id);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbReadingSession {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub start_char_offset: i64,
    pub end_char_offset: i64,
    pub started_at: DateTime<Utc>,
    pub ended_at: DateTime<Utc>,
    pub duration_seconds: i64,
    pub characters_read: i64,
}
```

#### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | UUID 主键 |
| book_id | String | 外键 |
| chapter_index | i32 | 阅读的章节索引 |
| start_char_offset | i64 | 开始字符偏移 |
| end_char_offset | i64 | 结束字符偏移 |
| started_at | DateTime<Utc> | 会话开始时间 |
| ended_at | DateTime<Utc> | 会话结束时间 |
| duration_seconds | i64 | 持续时长（秒） |
| characters_read | i64 | 本次阅读字符数 |

#### 会话记录示例

```rust
SessionRepository::record_session(
    book_id: "uuid",
    chapter_index: 5,
    start_offset: 12000,
    end_offset: 18000,
    duration_seconds: 1800,   // 30 分钟
    characters_read: 6000,
);
```

---

### 3.6 daily_stats - 每日统计

**用途**: 聚合每日阅读数据，支持统计报表和成就系统

```sql
CREATE TABLE daily_stats (
    date                        TEXT NOT NULL,            -- YYYY-MM-DD
    book_id                     TEXT,                     -- NULL 表示当日汇总
    reading_time_seconds        INTEGER NOT NULL DEFAULT 0,
    characters_read             INTEGER NOT NULL DEFAULT 0,
    session_count               INTEGER NOT NULL DEFAULT 0,
    chapters_read               INTEGER DEFAULT 0,
    pages_read                  INTEGER DEFAULT 0,
    PRIMARY KEY (date, book_id),
    FOREIGN KEY (date) REFERENCES daily_stats(date) ON DELETE CASCADE
);

CREATE INDEX idx_daily_date ON daily_stats(date);
CREATE INDEX idx_daily_book ON daily_stats(book_id);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbDailyReadingStats {
    pub date: String,
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read: Vec<String>,
    pub session_count: i32,
    pub chapters_read: i32,
    pub pages_read: i32,
}
```

#### 设计说明

- **复合主键**: `(date, book_id)` 支持一天读多本书
- **自引用外键**: `date` 引用自身，确保日期一致性
- **book_id 为 NULL**: 表示当日汇总记录

#### 查询方法

| 方法 | 说明 |
|------|------|
| `get_daily_stats(date)` | 获取指定日期的汇总统计 |
| `update_daily_stats(stats)` | 更新/插入日统计（UPSERT） |
| `get_books_for_date(date)` | 获取某日读过的书列表 |

---

### 3.7 chapters - 章节元数据

**用途**: 缓存书籍的章节信息，避免重复解析

```sql
CREATE TABLE chapters (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    title           TEXT NOT NULL,
    content_file    TEXT NOT NULL,           -- 章节内容文件路径
    chapter_index   INTEGER NOT NULL,
    word_count      INTEGER DEFAULT 0,
    cached_at       INTEGER NOT NULL,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

CREATE INDEX idx_chapters_book ON chapters(book_id);
CREATE INDEX idx_chapters_index ON chapters(book_id, chapter_index);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct DbChapter {
    pub id: String,
    pub book_id: String,
    pub title: String,
    pub content_file: String,
    pub chapter_index: i32,
    pub word_count: i64,
    pub cached_at: DateTime<Utc>,
}
```

---

### 3.8 categories - 书籍分类

**用途**: 用户自定义书籍分类标签

```sql
CREATE TABLE categories (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    description     TEXT,
    color           TEXT,                    -- 颜色值 (如 "#FF5733")
    sort_order      INTEGER DEFAULT 0,
    created_at      INTEGER NOT NULL,
    is_system       INTEGER DEFAULT 0,       -- 是否系统内置
    updated_at      INTEGER
);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct DbBookCategory {
    pub id: String,
    pub name: String,
    pub color: String,
    pub sort_order: i32,
    pub is_system: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

---

### 3.9 book_categories - 书籍-分类关联

**用途**: 多对多关联表，一本书可有多个分类

```sql
CREATE TABLE book_categories (
    book_id         TEXT NOT NULL,
    category_id     TEXT NOT NULL,
    PRIMARY KEY (book_id, category_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);
```

#### 操作方法

| 方法 | 说明 |
|------|------|
| `assign_category(book_id, category_id)` | 添加分类关联 |
| `remove_category(book_id, category_id)` | 移除分类关联 |
| `get_categories_for_book(book_id)` | 获取书籍的所有分类 |
| `set_categories_for_book(book_id, ids)` | 批量设置分类（先清后加） |

---

### 3.10 search_index - FTS5 全文搜索

**用途**: 支持书籍内容的全文搜索

```sql
CREATE VIRTUAL TABLE search_index USING fts5(
    book_id, chapter_index, content,
    tokenize='unicode61 remove_diacritics 0'
);
```

#### 触发器自动清理

```sql
CREATE TRIGGER IF NOT EXISTS cleanup_search_on_book_delete
    AFTER DELETE ON books
    BEGIN
        DELETE FROM search_index WHERE book_id = old.book_id;
    END;
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb]
pub struct DbSearchResult {
    pub book_id: String,
    pub chapter_index: i32,
    pub content: String,
    pub rank: f64,
    pub highlighted_text: String,
}
```

#### 搜索方法

```rust
SearchRepository::search(query: &str, book_id: Option<&str>) -> Vec<DbSearchResult>
// 支持 FTS5 语法: "keyword1 NEAR/3 keyword2"
// 支持 book_id 过滤: book_id = ? AND search_index MATCH ?
```

#### 索引方法

```rust
SearchRepository::index_content(book_id, chapter_index, content)
// INSERT INTO search_index (book_id, chapter_index, content) VALUES (?, ?, ?)
```

---

### 3.11 sync_records - 同步状态

**用途**: 记录 WebDAV 同步状态，支持冲突检测和增量同步

```sql
CREATE TABLE sync_records (
    id              TEXT PRIMARY KEY,
    book_id         TEXT NOT NULL,
    data_type       TEXT NOT NULL,           -- 'progress' | 'note' | 'bookmark' 等
    data_id         TEXT NOT NULL,           -- 对应数据记录的 ID
    local_version   INTEGER NOT NULL,
    remote_version  INTEGER,                 -- 可空，表示尚未同步到远程
    status          TEXT NOT NULL,           -- 'synced' | 'pending_upload' | 'pending_download' | 'conflict'
    modified_at     INTEGER NOT NULL,
    etag            TEXT                     -- HTTP ETag 用于缓存验证
);

CREATE INDEX idx_sync_query ON sync_records(book_id, data_type, status);
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbSyncRecord {
    pub id: String,
    pub book_id: String,
    pub data_type: String,
    pub data_id: String,
    pub local_version: i32,
    pub remote_version: Option<i32>,
    pub status: DbSyncStatus,
    pub modified_at: DateTime<Utc>,
    pub etag: Option<String>,
}
```

#### 同步状态枚举

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum DbSyncStatus {
    Synced,            // 已同步
    PendingUpload,     // 待上传
    PendingDownload,   // 待下载
    Conflict,          // 冲突
}
```

#### 查询方法

| 方法 | 说明 |
|------|------|
| `record_sync(book_id, data_type, data_id, ...)` | 记录同步状态 |
| `get_pending_sync(book_id)` | 获取待同步项目 |
| `update_sync_status(record_id, status, remote_version)` | 更新同步状态 |
| `get_sync_conflicts(book_id)` | 获取冲突记录 |
| `clear_sync_conflicts(book_id)` | 解决所有冲突 |

---

### 3.12 layout_cache - 排版缓存 (sled KV)

**用途**: 缓存已计算的排版结果（分页偏移），避免重复渲染

```
存储位置: {data_dir}/cache/
引擎: sled (嵌入式 KV 数据库)
序列化: bincode
```

#### 键格式

```
{book_id}:{chapter_index}:{config_hash}
示例: "550e8400-e29b:3:a1b2c3d4"
```

#### Rust 结构体

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbLayoutCache {
    pub page_offsets: Vec<(i64, i64)>,  // (字符偏移, 页起始位置)
    pub total_pages: i32,
    pub created_at: DateTime<Utc>,
}
```

#### 操作方法

| 方法 | 说明 |
|------|------|
| `get_cached_layout(book_id, chapter_index, config_hash)` | 获取缓存排版 |
| `save_layout_cache(book_id, chapter_index, config_hash, page_offsets, total_pages)` | 保存排版缓存 |
| `invalidate_book_cache(book_id)` | 清除书籍所有缓存 |
| `cleanup_expired(max_age_days)` | 清理过期缓存 |

---

## 4. 数据模型枚举

### DbBookFormat - 书籍格式

```rust
pub enum DbBookFormat {
    Txt,   // 纯文本 (.txt)
    Epub,  // EPUB 电子书 (.epub)
    Pdf,   // PDF 文档 (.pdf)
}
```

存储值: `"txt"`, `"epub"`, `"pdf"`

### DbBookStatus - 书籍状态

```rust
pub enum DbBookStatus {
    Reading,    // 阅读中
    Completed,  // 已完成
    Dropped,    // 已放弃
    Planned,    // 计划阅读
}
```

存储值: `"reading"`, `"completed"`, `"dropped"`, `"planned"`

### DbNoteType - 笔记类型

```rust
pub enum DbNoteType {
    Highlight,   // 高亮笔记（带颜色标记）
    Annotation,  // 注释笔记（文本备注）
}
```

存储值: `"highlight"`, `"annotation"`

### DbSyncStatus - 同步状态

```rust
pub enum DbSyncStatus {
    Synced,            // 已同步
    PendingUpload,     // 待上传
    PendingDownload,   // 待下载
    Conflict,          // 冲突
}
```

存储值: `"synced"`, `"pending_upload"`, `"pending_download"`, `"conflict"`

---

## 5. 外键关系图

```
┌─────────────┐
│   books     │
│  (PK:book_id)│
└──────┬──────┘
       │ ON DELETE CASCADE
       ├───────────────────┬──────────────────┬──────────────────┐
       │                   │                  │                  │
┌──────▼──────┐   ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐
│reading_progress│  │  bookmarks    │  │    notes      │  │reading_sessions│
│ (PK:book_id) │   │ (PK:id)       │  │ (PK:id)       │  │ (PK:id)       │
└──────────────┘   └───────────────┘  └───────────────┘  └───────────────┘
       │                   │                  │                  │
       │              (1:N)│             (1:N)│             (1:N)│
       │                   │                  │                  │
       ├───────────────────┼──────────────────┼──────────────────┤
       │                   │                  │                  │
┌──────▼──────┐   ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐
│  chapters   │   │ sync_records  │  │ search_index  │  │book_categories│
│ (PK:id)     │   │ (PK:id)       │  │ (VIRTUAL)     │  │ (PK:book_id,  │
└──────────────┘   └───────────────┘  └───────────────┘  │  category_id) │
       │                                                 └───────┬───────┘
       │                                                         │
       │                                                    (N:M)│
       │                                                         │
       │                                                 ┌───────▼───────┐
       │                                                 │  categories   │
       │                                                 │ (PK:id)       │
       │                                                 └───────────────┘
       │
┌──────▼──────┐
│ daily_stats │
│ (PK:date,   │
│  book_id)   │
└─────────────┘
  自引用 FK: date -> date

layout_cache (sled KV)
  键: {book_id}:{chapter_index}:{config_hash}
  逻辑关联: book_id (非外键约束)
```

### 级联删除规则

- 删除 `books` 记录时，自动删除所有关联的:
  - `reading_progress`
  - `bookmarks`
  - `notes`
  - `reading_sessions`
  - `chapters`
  - `sync_records`
  - `book_categories` 关联
  - `search_index` (通过触发器)

---

## 6. 索引设计

### 性能优化索引

| 索引名 | 表 | 列 | 用途 |
|--------|-----|-----|------|
| `idx_progress_last_read` | reading_progress | last_read_at | 书架按最后阅读时间排序 |
| `idx_bookmarks_book` | bookmarks | book_id | 查询书籍的所有书签 |
| `idx_bookmarks_chapter` | bookmarks | (book_id, chapter_index) | 按章节查询书签 |
| `idx_notes_book` | notes | book_id | 查询书籍的所有笔记 |
| `idx_notes_chapter` | notes | (book_id, chapter_index) | 按章节查询笔记 |
| `idx_notes_type` | notes | (book_id, note_type) | 按类型筛选笔记 |
| `idx_sessions_book` | reading_sessions | book_id | 查询书籍的阅读会话 |
| `idx_daily_date` | daily_stats | date | 按日期查询统计 |
| `idx_daily_book` | daily_stats | book_id | 按书籍查询统计 |
| `idx_chapters_book` | chapters | book_id | 查询书籍章节 |
| `idx_chapters_index` | chapters | (book_id, chapter_index) | 按索引查章节 |
| `idx_sync_query` | sync_records | (book_id, data_type, status) | 同步查询优化 |

### 索引策略

- **复合索引**: 优先过滤高基数字段 (book_id)，再过滤低基数字段 (chapter_index, note_type)
- **覆盖索引**: 部分查询可直接从索引获取数据，无需回表
- **主键索引**: SQLite 自动为 PRIMARY KEY 创建 B-Tree 索引

---

## 7. 触发器

### cleanup_search_on_book_delete

```sql
CREATE TRIGGER IF NOT EXISTS cleanup_search_on_book_delete
    AFTER DELETE ON books
    BEGIN
        DELETE FROM search_index WHERE book_id = old.book_id;
    END;
```

**触发时机**: 删除 `books` 记录后  
**动作**: 清理 FTS5 虚拟表中对应的搜索索引  
**原因**: FTS5 虚拟表不支持外键约束，必须手动维护

---

## 8. 仓库模式架构

### 宏生成统一封装

```rust
macro_rules! impl_db_repo {
    ($name:ident) => {
        pub struct $name {
            db: Arc<parking_lot::Mutex<Database>>,
        }
        impl $name {
            pub fn new(db: Arc<parking_lot::Mutex<Database>>) -> Self {
                Self { db }
            }
            #[inline]
            fn db(&self) -> parking_lot::MutexGuard<'_, Database> {
                self.db.lock()
            }
        }
    };
}
```

### 仓库列表

| 仓库类 | 职责 | 主要方法 |
|--------|------|----------|
| `BookRepository` | 书籍 CRUD | get_all_books, save_book, search_books |
| `ProgressRepository` | 阅读进度 | save_progress, get_progress, clear_progress |
| `BookmarkRepository` | 书签管理 | create_bookmark, get_bookmarks, sync_bookmarks |
| `NoteRepository` | 笔记/高亮 | create_highlight, create_annotation, get_notes |
| `SessionRepository` | 阅读会话 | record_session, get_sessions_by_book |
| `StatsRepository` | 统计分析 | get_today_stats, get_global_stats |
| `ChapterRepository` | 章节管理 | save_chapters, get_chapters_by_book |
| `CategoryRepository` | 分类管理 | assign_category, get_categories_for_book |
| `SyncRepository` | 同步状态 | record_sync, get_pending_sync |
| `SearchRepository` | 全文搜索 | index_content, search |
| `LayoutCacheRepository` | 排版缓存 | get_cached_layout, save_layout_cache |

### 仓库使用示例

```rust
// 通过 StorageManager 获取仓库实例
let book_repo = BookRepository::new(storage.db());
let books = book_repo.get_all_books()?;

let progress_repo = ProgressRepository::new(storage.db());
progress_repo.save_progress(&DbReadingProgress::new("book-uuid"))?;

let layout_repo = LayoutCacheRepository::new(storage.kv());
layout_repo.save_layout_cache("book-uuid", 0, "hash", offsets, 100)?;
```

---

## 9. 线程安全设计

### SQLite 连接保护

```rust
pub struct StorageManager {
    db: Arc<Mutex<Database>>,     // parking_lot::Mutex 保护
    kv: Arc<Mutex<KvStore>>,
    data_dir: PathBuf,
}
```

**设计原因**:
- `rusqlite::Connection` 不是 `Send` 类型，不能跨线程共享
- `parking_lot::Mutex` 提供轻量级互斥锁
- `Arc` 允许多个所有者共享数据库引用

### KV 存储保护

```rust
pub struct StorageManager {
    kv: Arc<Mutex<KvStore>>,      // sled 本身线程安全，但需 Rust 借用检查
}
```

### 访问模式

```
Thread A: lock(db) -> execute -> unlock
Thread B: lock(db) -> execute -> unlock  (等待 A 释放)
```

**并发策略**:
- 短时操作（SELECT, INSERT）持有锁 < 1ms
- 批量操作使用事务，减少锁竞争
- WAL 模式支持读写并发

---

## 10. 数据库版本管理

### 当前版本: v4

```rust
const DB_VERSION: i32 = 4;
```

### 版本升级策略

| 当前版本 | 目标版本 | 动作 |
|---------|---------|------|
| 0 | 4 | 创建所有表结构，设置 user_version = 4 |
| 1, 2, 3 | 4 | **报错**，要求删除旧库重建 |
| 4 | 4 | 无需操作 |
| > 4 | 4 | **报错**（未来版本降级保护） |

### 安全策略说明

**为什么不支持渐进式迁移？**
1. **减少维护成本**: 每个版本需要写迁移逻辑
2. **避免数据丢失**: 字段缺失可能导致 Panic
3. **开发阶段**: 项目早期，数据结构变动频繁
4. **用户量小**: 重新导入书籍成本可接受

**建议做法**:
```
1. 备份 {data_dir}/reader.db
2. 删除旧数据库文件
3. 应用启动时自动创建 v4 结构
4. 重新导入书籍和进度（如有备份）
```

---

## 11. API 暴露层

### flutter_rust_bridge 集成

所有模型结构体带 `#[frb]` 标记，自动生成 Dart 绑定：

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]  // <-- 自动生成 Dart 代码
pub struct DbBookRecord {
    pub book_id: String,
    pub title: String,
    // ...
}
```

### 生成的 Dart 代码示例

```dart
// 自动生成 (lib/src/rust/api/storage/models.dart)
class DbBookRecord {
  final String bookId;
  final String filePath;
  final String title;
  // ...
}
```

### API 调用模式

```rust
// 通过 FRB 暴露的操作
#[flutter_rust_bridge::frb]
pub fn get_all_books() -> Result<Vec<DbBookRecord>> {
    let storage = ensure_storage()?;
    BookRepository::new(storage.db()).get_all_books()
}

#[flutter_rust_bridge::frb]
pub fn save_book(book: DbBookRecord) -> Result<()> {
    let storage = ensure_storage()?;
    BookRepository::new(storage.db()).save_book(&book)
}
```

---

## 12. 关键文件路径

```
rust/
└── src/
    └── storage/
        ├── mod.rs               # StorageManager, 全局单例, 初始化入口
        ├── database.rs          # Database 类, PRAGMA 配置, 表创建, CRUD 实现
        ├── models.rs            # 所有数据模型结构体 (DbBookRecord, DbNote, 等)
        ├── repositories.rs      # 仓库模式封装 (BookRepository, NoteRepository, 等)
        └── kv_store.rs          # sled KV 存储封装 (排版缓存)
```

### 相关依赖

```toml
# rust/Cargo.toml
[dependencies]
rusqlite = { version = "0.31", features = ["bundled"] }
sled = "0.34"
bincode = "1.3"
chrono = { version = "0.4", features = ["serde"] }
serde = { version = "1.0", features = ["derive"] }
uuid = { version = "1.0", features = ["v4"] }
parking_lot = "0.12"
once_cell = "1.19"
anyhow = "1.0"
flutter_rust_bridge = "2.11.1"
```

---

## 附录: 数据库文件结构

```
{data_dir}/
├── reader.db              # SQLite 数据库主文件
├── reader.db-wal          # WAL 日志文件（运行时生成）
├── reader.db-shm          # 共享内存文件（运行时生成）
└── cache/                 # sled KV 存储目录
    ├── 000000.sled        # sled 数据文件
    ├── CONF               # sled 配置文件
    └── ...
```

---

**文档版本**: 1.0  
**数据库版本**: v4  
**适用项目**: Zephyr Reader (Flutter + Rust)  
**最后更新**: 2026-04-07
