//! 备份数据模型

use flutter_rust_bridge::frb;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

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
        language: Option<String>,
        paired_note_id: Option<String>,
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
            paired_note_id,
            language,
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
        selected_text: Option<String>,
        language: Option<String>,
        paired_note_id: Option<String>,
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
            selected_text,
            highlight_color: None,
            paired_note_id,
            language,
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

