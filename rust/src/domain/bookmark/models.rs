use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

//// 章节内书签
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Bookmark {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub locator_json: Option<String>,
    pub title: String,
    pub created_at: DateTime<Utc>,
}

impl Bookmark {
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        chapter_id: Option<String>,
        char_offset: i64,
        locator_json: Option<String>,
        title: &str,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            chapter_id,
        char_offset,
        locator_json,
        title: title.to_string(),
            created_at: Utc::now(),
        }
    }
}
