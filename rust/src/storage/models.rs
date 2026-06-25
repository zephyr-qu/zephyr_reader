//! 阅读器核心领域模型
//!
//! 本模块定义了阅读器的所有持久化实体与业务枚举。
//! 所有带 `#[frb]` 的类型会自动暴露给 Dart 侧；
//! 所有带 `#[derive(sqlx::FromRow)]` 的类型支持从 SQLite 自动映射。

use crate::domain::PageContent;
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ==================== 排版缓存 ====================

/// 当前排版缓存版本号
///
/// 每次破坏性变更时递增，旧版本数据在读取时静默丢弃。
pub const LAYOUT_CACHE_VERSION: u8 = 2;

/// 排版缓存键（内部使用，不暴露给 Dart）
///
/// 序列化格式（全章）：`v{VERSION}:{book_id}:{chapter_idx}:{config_hash:016x}`
/// 序列化格式（chunk）：`v{VERSION}:chunk:{book_id}:{chapter_idx}:{chunk_idx}:{config_hash:016x}`
#[derive(Debug, Clone)]
pub struct LayoutCacheKey {
    pub book_id: String,
    pub chapter_index: i32,
    pub chunk_index: Option<u32>,
    pub config_hash: u64,
}

impl std::fmt::Display for LayoutCacheKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.chunk_index {
            Some(chunk) => write!(
                f,
                "v{}:chunk:{}:{}:{}:{:016x}",
                LAYOUT_CACHE_VERSION, self.book_id, self.chapter_index, chunk, self.config_hash
            ),
            None => write!(
                f,
                "v{}:{}:{}:{:016x}",
                LAYOUT_CACHE_VERSION, self.book_id, self.chapter_index, self.config_hash
            ),
        }
    }
}

/// 排版分页结果缓存（仅用于序列化存储，不以行形式入 DB）
///
/// 此结构体未实现 `FromRow`，仅通过 serde 以 JSON/Blob 形式存取。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
pub struct LayoutCache {
    /// 缓存格式版本号，用于向后兼容校验
    pub version: u8,
    /// 生成此缓存时使用的 TypesetConfig 哈希值
    pub config_hash: u64,
    /// 缓存的分页结果
    pub pages: Vec<PageContent>,
    /// 总页数
    pub total_pages: i64,
    /// 缓存创建时间
    pub created_at: i64,
}

impl LayoutCache {
    /// 创建新缓存（自动填充当前版本号）
    pub fn new(config_hash: u64, pages: Vec<PageContent>) -> Self {
        let total_pages = pages.len() as i64;
        Self {
            version: LAYOUT_CACHE_VERSION,
            config_hash,
            pages,
            total_pages,
            created_at: Utc::now().timestamp(),
        }
    }

    /// 校验缓存的版本和配置哈希是否与预期一致
    pub fn is_valid(&self, expected_hash: u64) -> bool {
        self.version == LAYOUT_CACHE_VERSION && self.config_hash == expected_hash
    }
}

// ==================== 块分页持久化缓存（Phase 3 P3-6） ====================

/// 块分页 sled 缓存格式版本（与 plain `LayoutCache` 独立演进）。
pub const BLOCK_LAYOUT_CACHE_VERSION: u8 = 1;

/// 块路径分页索引 + 章 IR（跨 session 复用，避免重复 IR 解析与 BlockPaginator CPU）。
#[derive(Debug, Clone, PartialEq, bincode::Encode, bincode::Decode)]
pub struct BlockLayoutCache {
    pub version: u8,
    pub config_hash: u64,
    pub ir: crate::domain::ChapterContentIr,
    pub result: crate::domain::BlockPaginateResult,
    pub total_pages: i64,
    pub created_at: i64,
}

impl BlockLayoutCache {
    pub fn new(
        config_hash: u64,
        ir: crate::domain::ChapterContentIr,
        result: crate::domain::BlockPaginateResult,
    ) -> Self {
        let total_pages = result.page_count() as i64;
        Self {
            version: BLOCK_LAYOUT_CACHE_VERSION,
            config_hash,
            ir,
            result,
            total_pages,
            created_at: Utc::now().timestamp(),
        }
    }

    pub fn is_valid(&self, expected_hash: u64) -> bool {
        self.version == BLOCK_LAYOUT_CACHE_VERSION
            && self.config_hash == expected_hash
            && !self.result.is_partial
    }
}

// ==================== 阅读进度 ====================

/// 单章阅读进度
///
/// - `page_index` / `total_pages` 标记了 `#[sqlx(default)]`，
///   仅在数据库迁移新增这两列的过渡期内使用，迁移完成后应移除。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingProgress {
    pub book_id: String,
    pub chapter_index: i64,
    pub chunk_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub page_index: i64,
    pub total_pages: i64,
    pub progress: f32,
    pub reading_time_seconds: i64,
    pub last_read_at: DateTime<Utc>,
    pub is_completed: bool,
}

impl ReadingProgress {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        chunk_index: i64,
        char_offset: i64,
        progress: f32,
        reading_time_seconds: i64,
        page_index: i64,
        total_pages: i64,
        is_completed: bool,
    ) -> Self {
        Self {
            book_id: book_id.to_string(),
            chapter_index,
            chunk_index,
            chapter_id: None,
            char_offset,
            page_index,
            total_pages,
            progress,
            reading_time_seconds,
            last_read_at: Utc::now(),
            is_completed,
        }
    }
}

// ==================== 书签 ====================

/// 章节内书签
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Bookmark {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub title: String,
    pub created_at: DateTime<Utc>,
}

impl Bookmark {
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        chapter_id: Option<String>,
        char_offset: i64,
        title: &str,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            chapter_id,
            char_offset,
            title: title.to_string(),
            created_at: Utc::now(),
        }
    }
}

// ==================== 笔记 ====================

//// 笔记类型
///
/// 数据库中存储为小写文本（`highlight` / `annotation`）。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, strum::AsRefStr, strum::EnumString,
)]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum NoteType {
    Highlight,
    Annotation,
}

// 让 FromRow 能自动将 SQLite TEXT → NoteType
impl TryFrom<String> for NoteType {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}

/// 高亮或批注笔记
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Note {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub length: i64,
    #[sqlx(try_from = "String")]
    pub note_type: NoteType,
    pub content: String,
    pub selected_text: Option<String>,
    pub highlight_color: Option<i64>,
    pub paired_note_id: Option<String>,
    pub language: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Note {
    /// 创建高亮笔记
    #[allow(clippy::too_many_arguments)]
    pub fn highlight(
        book_id: &str,
        chapter_index: i64,
        char_offset: i64,
        length: i64,
        selected_text: &str,
        color: i64,
        language: Option<&str>,
        paired_note_id: Option<&str>,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            chapter_id: None,
            char_offset,
            length,
            note_type: NoteType::Highlight,
            content: String::new(),
            selected_text: Some(selected_text.to_string()),
            highlight_color: Some(color),
            paired_note_id: paired_note_id.map(String::from),
            language: language.map(String::from),
            created_at: now,
            updated_at: now,
        }
    }

    /// 创建批注笔记
    pub fn annotation(
        book_id: &str,
        chapter_index: i64,
        char_offset: i64,
        content: &str,
        selected_text: Option<&str>,
        language: Option<&str>,
        paired_note_id: Option<&str>,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            chapter_id: None,
            char_offset,
            length: 0,
            note_type: NoteType::Annotation,
            content: content.to_string(),
            selected_text: selected_text.map(String::from),
            highlight_color: None,
            paired_note_id: paired_note_id.map(String::from),
            language: language.map(String::from),
            created_at: now,
            updated_at: now,
        }
    }
}
/// 笔记统计摘要（可直接从聚合查询映射）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque, dart_metadata = ("freezed"))]
pub struct NoteStats {
    pub total_count: i64,
    pub highlight_count: i64,
    pub annotation_count: i64,
}

/// 笔记与书名组合（查询笔记列表时一并带回书名）
#[derive(Debug, Clone)]
#[frb(dart_metadata = ("freezed"))]
pub struct NoteWithBook {
    pub note: Note,
    pub book_title: String,
}

// ==================== 阅读会话 & 统计 ====================

/// 单次连续阅读会话记录
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingSession {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i64,
    pub start_char_offset: i64,
    pub end_char_offset: i64,
    pub started_at: DateTime<Utc>,
    pub ended_at: DateTime<Utc>,
    pub duration_seconds: i64,
}
impl ReadingSession {
    /// 创建阅读会话（结束时调用）
    ///
    /// - `id` / `started_at` / `ended_at` / `duration_seconds` 由构造函数自动计算
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        start_char_offset: i64,
        end_char_offset: i64,
        started_at: DateTime<Utc>,
    ) -> Self {
        let ended_at = Utc::now();
        let duration_seconds = (ended_at - started_at).num_seconds().max(0);
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            start_char_offset,
            end_char_offset: end_char_offset.max(start_char_offset),
            started_at,
            ended_at,
            duration_seconds,
        }
    }
}

/// 每日阅读统计
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingStats {
    pub book_id: String,
    pub date: String,
    pub reading_time_seconds: i64,
    pub characters_read: i64,
    pub session_count: i64,
    #[sqlx(default)]
    pub last_session_id: Option<String>,
}
/// 单次聚合查询获取所有计数与求和指标。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque)]
pub struct AggregatedStats {
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read_count: i64,
    pub books_completed_count: i64,
    pub total_books_count: i64,
    pub total_notes_count: i64,
    pub total_bookmarks_count: i64,
    pub today_reading_time_seconds: i64,
    pub today_characters_read: i64,
}
/// 全局阅读统计汇总（应用层计算，非直接 DB 映射）

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque, dart_metadata = ("freezed"))]
pub struct GlobalStats {
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read_count: i64,
    pub books_completed_count: i64,
    pub consecutive_reading_days: i64,
    pub today_reading_time_seconds: i64,
    pub today_characters_read: i64,
    pub average_reading_speed: f32,
    pub total_books_count: i64,
    pub total_notes_count: i64,
    pub total_bookmarks_count: i64,
}

// ==================== 书籍 & 章节 ====================

/// 书籍文件格式
///
/// 数据库中存储为小写文本。`FromStr` 额外兼容 markdown 别名。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, Default, Serialize, Deserialize,
    strum::AsRefStr, strum::EnumString,
)]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum BookFormat {
    #[default]
    #[strum(serialize = "txt", serialize = "text")]
    Txt,
    Epub,
}

//
impl TryFrom<String> for BookFormat {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}

/// 书籍阅读状态
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize, strum::AsRefStr, strum::EnumString,
)]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum BookStatus {
    #[default]
    Reading,
    Completed,
    Dropped,
    Planned,
}

//
impl TryFrom<String> for BookStatus {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}

/// 书籍元数据
#[derive(Debug, Clone, Serialize, Deserialize, Default, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Book {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub file_path: String,
    pub file_hash: Option<String>,
    pub file_size: i64,
    pub file_mtime: Option<i64>,
    pub title: String,
    pub author: Option<String>,
    pub cover_path: Option<String>,
    pub chapter_count: i64,
    pub total_characters: i64,
    #[sqlx(try_from = "String")]
    pub format: BookFormat,
    pub added_at: DateTime<Utc>,
    pub last_opened_at: Option<DateTime<Utc>>,
    #[sqlx(try_from = "String")]
    pub status: BookStatus,
    pub is_pinned: bool,
    #[sqlx(default)]
    pub description: Option<String>,
    #[sqlx(default)]
    pub publisher: Option<String>,
    #[sqlx(default)]
    pub translator: Option<String>,
    #[sqlx(default)]
    pub isbn: Option<String>,
}

/// 书籍标题摘要（轻量查询用）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct BookTitle {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub title: String,
}
impl Book {
    /// 添加新书籍（导入时调用）
    ///
    /// - `added_at` 自动设为当前时间
    /// - `last_opened_at` 初始为 `None`（尚未打开）
    /// - `status` 默认为 `Planned`（待读）
    /// - 可选元数据（author/description 等）由调用方按需传入
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        file_path: &str,
        file_size: i64,
        title: &str,
        format: BookFormat,
        chapter_count: i64,
        total_characters: i64,
        file_hash: Option<&str>,
        file_mtime: Option<i64>,
        author: Option<&str>,
        cover_path: Option<&str>,
        description: Option<&str>,
        publisher: Option<&str>,
        translator: Option<&str>,
        isbn: Option<&str>,
    ) -> Self {
        Self {
            book_id: Uuid::new_v4().to_string(),
            file_path: file_path.to_string(),
            file_hash: file_hash.map(String::from),
            file_size,
            file_mtime,
            title: title.to_string(),
            author: author.map(String::from),
            cover_path: cover_path.map(String::from),
            chapter_count,
            total_characters,
            format,
            added_at: Utc::now(),
            last_opened_at: None,
            status: BookStatus::Planned,
            is_pinned: false,
            description: description.map(String::from),
            publisher: publisher.map(String::from),
            translator: translator.map(String::from),
            isbn: isbn.map(String::from),
        }
    }
}

/// 章节信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
/// 章节在书籍文件中的位置边界。
///
/// # `start_index` / `end_index` 语义按格式不同
///
/// | 格式 | 含义 |
/// |---|---|
/// | TXT | 文件内的**字节偏移**。切片内容时需确保 UTF-8 字符边界对齐。 |
/// | EPUB | spine item **序号**。用于索引 `Spine` 数组合并多个 HTML 资源。 |
///
/// 消费方必须根据 `Book.format` 判断如何解释这两个字段。
/// 直接将其视为「字符索引」是错误的。
pub struct Chapter {
    pub id: String,
    pub book_id: String,
    pub title: String,
    pub chapter_index: i64,
    pub cached_at: DateTime<Utc>,
    pub level: i64,
    #[sqlx(default)]
    pub start_index: i64,
    #[sqlx(default)]
    pub end_index: i64,
}
impl Chapter {
    /// 创建章节信息（解析完成时调用）
    ///
    /// - `id` / `cached_at` 自动生成
    pub fn new(
        book_id: &str,
        title: &str,
        chapter_index: i64,
        level: i64,
        start_index:i64,
        end_index:i64
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            title: title.to_string(),
            chapter_index,
            cached_at: Utc::now(),
            level,
            start_index,
            end_index,
            // content_length: 0,
        }
    }
}
// ==================== 分类 ====================

/// 书籍分类标签
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Category {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub sort_order: i64,
    pub is_system: bool,
}
impl Category {
    /// 创建书籍分类标签
    ///
    /// - `id` 自动生成
    /// - `is_system` 默认为 `false`（用户自定义分类）
    pub fn new(
        name: &str,
        color: &str,
        sort_order: i64,
        description: Option<&str>,
        is_system: bool,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.to_string(),
            description: description.map(String::from),
            color: color.to_string(),
            sort_order,
            is_system,
        }
    }
}
// ==================== 生词本 ====================

/// 生词学习状态
///
/// 数据库中存储为小写文本（`new` / `learning` / `mastered` / `ignored`）。
#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    sqlx::Type,
    Default,
    strum::AsRefStr,
    strum::EnumString,
)]
#[sqlx(rename_all = "lowercase")]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum VocabStatus {
    /// 新词，尚未开始学习
    #[default]
    Unstarted,
    /// 学习中，正在复习周期内
    Learning,
    /// 已掌握，通过所有复习阶段
    Mastered,
    /// 已忽略/移除出学习队列
    Ignored,
}

impl TryFrom<String> for VocabStatus {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}
/// 生词条目
///
/// `status` 字段通过 `#[sqlx(try_from)]` 自动从 SQLite TEXT 解码为 `VocabStatus`，
/// 非法值会导致 `FromRow` 解析失败（Fail visibly）。
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Vocab {
    pub id: String,
    pub word: String,
    pub pinyin: String,
    pub translation: String,
    pub context_sentence: Option<String>,
    pub book_id: Option<String>,
    pub chapter_index: Option<i64>,
    pub char_offset: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub review_count: i64,
    pub last_reviewed_at: Option<DateTime<Utc>>,
    #[sqlx(try_from = "String")]
    pub status: VocabStatus,
    pub word_list: Option<String>,
    #[sqlx(default)]
    pub dict_source: Option<String>,
    #[sqlx(default)]
    pub dict_entry_hash: Option<String>,
}
impl Vocab {
    /// 添加生词条目
    ///
    /// - `id` / `created_at` 自动生成
    /// - `status` 默认为 `Unstarted`（新词）
    /// - `review_count` 初始为 0
    /// - 关联上下文（book_id/chapter_index 等）为可选参数
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        word: &str,
        pinyin: &str,
        translation: &str,
        context_sentence: Option<&str>,
        book_id: Option<&str>,
        chapter_index: Option<i64>,
        char_offset: Option<i64>,
        word_list: Option<&str>,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            word: word.to_string(),
            pinyin: pinyin.to_string(),
            translation: translation.to_string(),
            context_sentence: context_sentence.map(String::from),
            book_id: book_id.map(String::from),
            chapter_index,
            char_offset,
            created_at: Utc::now(),
            review_count: 0,
            last_reviewed_at: None,
            status: VocabStatus::Unstarted,
            word_list: word_list.map(String::from),
            dict_source: None,
            dict_entry_hash: None,
        }
    }
}
/// 生词本统计摘要（应用层计算，非直接 DB 映射）
#[derive(Debug, Clone, Serialize, Deserialize,sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct VocabStats {
    #[sqlx(try_from = "i64")]
    pub total_words: i64,
    #[sqlx(try_from = "i64")]
    pub unstarted_count: i64,
    #[sqlx(try_from = "i64")]
    pub learning_count: i64,
    #[sqlx(try_from = "i64")]
    pub mastered_count: i64,
    #[sqlx(try_from = "i64")]
    pub ignored_count: i64,
}

/// 词典
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Dictionary {
    pub id: String,
    pub name: String,
    pub file_path: String,
    pub dict_type: String,
    pub lang_from: Option<String>,
    pub lang_to: Option<String>,
    pub is_enabled: bool,
    pub word_count: i64,
    pub added_at: DateTime<Utc>,
}
impl Dictionary {
    pub fn new(
        name: &str,
        file_path: &str,
        dict_type: &str,
        lang_from: Option<&str>,
        lang_to: Option<&str>,
        is_enabled: bool,
        word_count: i64,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.to_string(),
            file_path: file_path.to_string(),
            dict_type: dict_type.to_string(),
            lang_from: lang_from.map(String::from),
            lang_to: lang_to.map(String::from),
            is_enabled,
            word_count,
            added_at: Utc::now(),
        }
    }
}

/// 书籍+阅读进度聚合（LEFT JOIN 查询结果）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct BookWithProgress {
    pub book: Book,
    pub progress: Option<ReadingProgress>,
}

/// 书架展示用书籍摘要（含进度）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct BookshelfBook {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub file_path: String,
    pub title: String,
    pub author: Option<String>,
    pub cover_path: Option<String>,
    pub is_pinned: bool,
    #[sqlx(try_from = "String")]
    pub status: BookStatus,
    pub chapter_count: i64,
    pub last_opened_at: Option<DateTime<Utc>>,
    pub added_at: DateTime<Utc>,
    pub progress: Option<f32>,
}
