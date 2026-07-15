//! 备份数据模型

use flutter_rust_bridge::frb;
use chrono::{DateTime, Utc};
use uuid::Uuid;
use serde::{Deserialize, Serialize};

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
        start_index: i64,
        end_index: i64,
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
