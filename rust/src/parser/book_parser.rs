use flutter_rust_bridge::frb;

/// 书籍元数据，用于 Dart FFI 交互
#[derive(Debug, Clone, Default)]
#[frb]
pub struct BookMetadata {
    pub title: String,
    pub author: String,
    pub description: Option<String>,
    pub cover_path: Option<String>,
    pub publisher: Option<String>,
    pub translator: Option<String>,
    pub isbn: Option<String>,
    pub publish_year: Option<i32>,
    pub language: Option<String>,
    pub chapter_count: i64,
    pub total_characters: i64,
}
