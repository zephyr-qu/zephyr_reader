use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 排版缓存键（内部使用）
#[derive(Debug, Clone)]
pub struct LayoutCacheKey {
    pub book_id: String,
    pub chapter_index: i32,
    pub config_hash: String,
}

impl std::fmt::Display for LayoutCacheKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "v1:{}:{}:{}",
            self.book_id, self.chapter_index, self.config_hash
        )
    }
}

// ==================== 阅读进度 ====================

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct ReadingProgress {
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub page_index: i32,
    pub total_pages: i32,
    pub progress: f32,
    pub reading_time_seconds: i64,
    pub last_read_at: DateTime<Utc>,
    pub is_completed: bool,
}

impl ReadingProgress {
    pub fn new(book_id: &str) -> Self {
        Self {
            book_id: book_id.to_string(),
            chapter_index: 0,
            chapter_id: None,
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

// ==================== 书签 ====================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct Bookmark {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub title: String,
    pub created_at: DateTime<Utc>,
}

impl Bookmark {
    pub fn new(book_id: &str, chapter_index: i32, char_offset: i64, title: &str) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            chapter_id: None,
            char_offset,
            title: title.to_string(),
            created_at: chrono::Utc::now(),
        }
    }
}

// ==================== 笔记 ====================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct Note {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub length: i64,
    pub note_type: NoteType,
    pub content: String,
    pub selected_text: Option<String>,
    pub highlight_color: Option<i32>,
    pub paired_note_id: Option<String>,
    pub language: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Note {
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
            chapter_id: None,
            char_offset,
            length,
            note_type: NoteType::Highlight,
            content: String::new(),
            selected_text: Some(selected_text.to_string()),
            highlight_color: Some(color),
            paired_note_id: None,
            language: None,
            created_at: now,
            updated_at: now,
        }
    }

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
            chapter_id: None,
            char_offset,
            length: 0,
            note_type: NoteType::Annotation,
            content: content.to_string(),
            selected_text: selected_text.map(String::from),
            highlight_color: None,
            paired_note_id: None,
            language: None,
            created_at: now,
            updated_at: now,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(rename_all = "lowercase")]
#[frb]
pub enum NoteType {
    Highlight,
    Annotation,
}

impl NoteType {
    pub fn as_str(&self) -> &'static str {
        match self {
            NoteType::Highlight => "highlight",
            NoteType::Annotation => "annotation",
        }
    }
}

impl std::str::FromStr for NoteType {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "highlight" => Ok(NoteType::Highlight),
            "annotation" => Ok(NoteType::Annotation),
            _ => Err(format!("Unknown note type: {}", s)),
        }
    }
}

// ==================== 阅读会话 ====================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct ReadingSession {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i32,
    pub chapter_id: Option<String>,
    pub start_char_offset: i64,
    pub end_char_offset: i64,
    pub started_at: DateTime<Utc>,
    pub ended_at: DateTime<Utc>,
    pub duration_seconds: i64,
}

// ==================== 阅读统计 ====================

/// 每日阅读统计（按书聚合）
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct ReadingStats {
    pub book_id: String,
    pub date: String,
    pub reading_time_seconds: i64,
    pub characters_read: i64,
    pub session_count: i32,
}

/// 全局阅读统计汇总
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb(non_opaque, dart_metadata=("freezed"))]
pub struct GlobalStats {
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
}

// ==================== 排版缓存 ====================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LayoutCache {
    pub page_offsets: Vec<(i64, i64)>,
    pub total_pages: i32,
    pub created_at: DateTime<Utc>,
}

// ==================== 枚举 ====================

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(rename_all = "lowercase")]
#[frb]
pub enum BookFormat {
    Txt,
    Epub,
    Pdf,
}

impl BookFormat {
    pub fn as_str(&self) -> &'static str {
        match self {
            BookFormat::Txt => "txt",
            BookFormat::Epub => "epub",
            BookFormat::Pdf => "pdf",
        }
    }
}
impl std::str::FromStr for BookFormat {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "txt" => Ok(BookFormat::Txt),
            "epub" => Ok(BookFormat::Epub),
            "pdf" => Ok(BookFormat::Pdf),
            _ => Err(format!("Unknown book format: {}", s)),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(rename_all = "lowercase")]
#[frb]
pub enum BookStatus {
    Reading,
    Completed,
    Dropped,
    Planned,
}

impl BookStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            BookStatus::Reading => "reading",
            BookStatus::Completed => "completed",
            BookStatus::Dropped => "dropped",
            BookStatus::Planned => "planned",
        }
    }
}

impl std::str::FromStr for BookStatus {
    type Err = String;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "reading" => Ok(BookStatus::Reading),
            "completed" => Ok(BookStatus::Completed),
            "dropped" => Ok(BookStatus::Dropped),
            "planned" => Ok(BookStatus::Planned),
            _ => Err(format!("Unknown book status: {}", s)),
        }
    }
}

// ==================== 书籍 & 章节 ====================

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct Book {
    pub book_id: String,
    pub file_path: String,
    pub file_hash: Option<String>,
    pub file_size: i64,
    pub file_mtime: Option<i64>,
    pub title: String,
    pub author: Option<String>,
    pub description: Option<String>,
    pub cover_path: Option<String>,
    pub chapter_count: i32,
    pub total_characters: i64,
    pub format: BookFormat,
    pub added_at: DateTime<Utc>,
    pub last_opened_at: Option<DateTime<Utc>>,
    pub status: BookStatus,
    pub is_pinned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct Chapter {
    pub id: String,
    pub book_id: String,
    pub title: String,
    pub content_file: String,
    pub chapter_index: i32,
    pub word_count: i64,
    pub cached_at: DateTime<Utc>,
    pub level: i32,
    /// 章节在源文件中的起始偏移（字节），仅解析时使用
    pub start_index: i64,
    /// 章节在源文件中的结束偏移（字节），仅解析时使用
    pub end_index: i64,
    /// 章节内容长度（字节），仅解析时使用
    pub content_length: i64,
}

// ==================== 分类 ====================

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct BookCategory {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub sort_order: i32,
    pub is_system: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: Option<DateTime<Utc>>,
}

// ==================== 生词本 ====================

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque)]
pub struct VocabEntry {
    pub id: String,
    pub word: String,
    pub pinyin: String,
    pub translation: String,
    pub context_sentence: Option<String>,
    pub book_id: Option<String>,
    pub chapter_index: Option<i64>,
    pub char_offset: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub review_count: i32,
    pub last_reviewed_at: Option<DateTime<Utc>>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct VocabStats {
    pub total_words: i64,
    pub learning_count: i64,
    pub known_count: i64,
    pub mastered_count: i64,
}

// ==================== 统计辅助 ====================

/// 笔记统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque, dart_metadata=("freezed"))]
pub struct NoteStats {
    pub total_count: i32,
    pub highlight_count: i32,
    pub annotation_count: i32,
}
