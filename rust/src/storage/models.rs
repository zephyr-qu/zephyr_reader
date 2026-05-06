//! 存储层数据模型
//!
//! 引擎使用的数据结构，定义所有数据库模型。

use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
/// 排版缓存键（内部使用，不暴露给 FFI）
#[derive(Debug, Clone)]
#[frb]
pub struct LayoutCacheKey {
    pub book_id: String,
    pub chapter_index: i32,
    pub config_hash: String,
}

impl std::fmt::Display for LayoutCacheKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}:{}:{}",
            self.book_id, self.chapter_index, self.config_hash
        )
    }
}
/// 阅读进度（数据库模型）
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

impl DbReadingProgress {
    /// 创建新的阅读进度记录
    pub fn new(book_id: &str) -> Self {
        Self {
            book_id: book_id.to_string(),
            chapter_index: 0,
            char_offset: 0,
            page_index: 0,
            total_pages: 0,
            progress: 0.0,
            reading_time_seconds: 0,
            last_read_at: chrono::Utc::now(),
            is_completed: false,
        }
    }
}

/// 书签（数据库模型）
///
/// 纯位置标记，仅记录阅读位置，不包含内容注释
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

impl DbBookmark {
    /// 创建新书签
    pub fn new(book_id: &str, chapter_index: i32, char_offset: i64, title: &str) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            char_offset,
            title: title.to_string(),
            created_at: chrono::Utc::now(),
        }
    }
}

/// 笔记（数据库模型）
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

impl DbNote {
    /// 创建高亮笔记
    pub fn highlight(
        book_id: &str,
        chapter_index: i32,
        char_offset: i64,
        length: i64,
        selected_text: &str,
        color: i32,
    ) -> Self {
        let now = chrono::Utc::now();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            char_offset,
            length,
            note_type: DbNoteType::Highlight,
            content: String::new(),
            selected_text: Some(selected_text.to_string()),
            highlight_color: Some(color),
            created_at: now,
            updated_at: now,
        }
    }

    /// 创建注释笔记
    pub fn annotation(
        book_id: &str,
        chapter_index: i32,
        char_offset: i64,
        content: &str,
        selected_text: Option<&str>,
    ) -> Self {
        let now = chrono::Utc::now();
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            char_offset,
            length: 0,
            note_type: DbNoteType::Annotation,
            content: content.to_string(),
            selected_text: selected_text.map(String::from),
            highlight_color: None,
            created_at: now,
            updated_at: now,
        }
    }
}

/// 笔记类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum DbNoteType {
    Highlight,  // 高亮笔记（带颜色的文本标记）
    Annotation, // 注释笔记（文本内容备注）
}

impl DbNoteType {
    /// 获取笔记类型的字符串表示
    pub fn as_str(&self) -> &'static str {
        match self {
            DbNoteType::Highlight => "highlight",
            DbNoteType::Annotation => "annotation",
        }
    }
}

impl std::str::FromStr for DbNoteType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "highlight" => Ok(DbNoteType::Highlight),
            "annotation" => Ok(DbNoteType::Annotation),
            _ => Err(format!("Unknown note type: {}", s)),
        }
    }
}

/// 阅读会话记录
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

/// 每日阅读统计
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

/// 全局阅读统计汇总
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb]
pub struct DbGlobalStats {
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read_count: i32,
    pub books_completed_count: i32,
    pub consecutive_reading_days: i32,
    pub today_reading_time_seconds: i64,
    pub today_characters_read: i64,
    pub average_reading_speed: f32,
    pub total_books_count: i32,
    pub total_notes_count: i32,
    pub total_bookmarks_count: i32,
    pub max_consecutive_reading_days: i32,
}
/// 排版缓存值
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub struct DbLayoutCache {
    pub page_offsets: Vec<(i64, i64)>,
    pub total_pages: i32,
    pub created_at: DateTime<Utc>,
}

/// 书籍格式
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum DbBookFormat {
    Txt,
    Epub,
    Pdf,
}

impl DbBookFormat {
    /// 获取书籍格式的字符串表示
    pub fn as_str(&self) -> &'static str {
        match self {
            DbBookFormat::Txt => "txt",
            DbBookFormat::Epub => "epub",
            DbBookFormat::Pdf => "pdf",
        }
    }
}

/// 书籍阅读状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum DbBookStatus {
    Reading,
    Completed,
    Dropped,
    Planned,
}

impl DbBookStatus {
    /// 获取阅读状态的字符串表示
    pub fn as_str(&self) -> &'static str {
        match self {
            DbBookStatus::Reading => "reading",
            DbBookStatus::Completed => "completed",
            DbBookStatus::Dropped => "dropped",
            DbBookStatus::Planned => "planned",
        }
    }
}

impl std::str::FromStr for DbBookStatus {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "reading" => Ok(DbBookStatus::Reading),
            "completed" => Ok(DbBookStatus::Completed),
            "dropped" => Ok(DbBookStatus::Dropped),
            "planned" => Ok(DbBookStatus::Planned),
            _ => Err(format!("Unknown book status: {}", s)),
        }
    }
}

/// 书籍元数据
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

/// 章节元数据
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
    /// 层级深度（0 = 顶层，1 = 子章节，…）
    pub level: i32,
}

/// 书籍分类
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct DbBookCategory {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub sort_order: i32,
    pub is_system: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 搜索结果
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb]
pub struct DbSearchResult {
    pub book_id: String,
    pub chapter_index: i32,
    pub content: String,
    pub rank: f64,
    pub highlighted_text: String,
}

/// 笔记统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct NoteStats {
    pub total_count: i32,
    pub highlight_count: i32,
    pub annotation_count: i32,
}
