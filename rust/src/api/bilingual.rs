//! 双语对齐 & 双语高亮配对 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::bilingual::{BilingualAlignment, BilingualHighlightPair, BilingualHighlightParams};
use crate::domain::bilingual::service;

/// 对齐双语文本（基于相似度匹配）
#[frb]
pub async fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, AppError> {
    tracing::info!("[bilingual] align_bilingual_content: chinese_len={}, english_len={}",
        chinese_content.len(), english_content.len());
    service::align_bilingual_content(chinese_content, english_content, min_similarity).await
}

/// 创建双语高亮配对（同时创建中文和英文两条高亮）
#[frb]
pub async fn create_bilingual_highlight_pair(
    params: BilingualHighlightParams,
) -> Result<BilingualHighlightPair, AppError> {
    tracing::info!("[bilingual] create_bilingual_highlight_pair: book_id={}, chapter_index={}",
        params.book_id, params.chapter_index);
    service::create_bilingual_highlight_pair(&params).await
}

/// 获取章节的所有双语高亮配对
#[frb]
pub async fn get_bilingual_highlight_pairs(
    book_id: String,
    chapter_index: i32,
) -> Result<Vec<BilingualHighlightPair>, AppError> {
    tracing::debug!("[bilingual] get_bilingual_highlight_pairs: book_id={}, chapter_index={}",
        book_id, chapter_index);
    service::get_bilingual_highlight_pairs(&book_id, chapter_index as i64).await
}

/// 删除一对双语高亮
#[frb]
pub async fn delete_bilingual_highlight_pair(
    chinese_note_id: String,
    english_note_id: String,
) -> Result<(), AppError> {
    tracing::info!("[bilingual] delete_bilingual_highlight_pair");
    service::delete_bilingual_highlight_pair(&chinese_note_id, &english_note_id).await
}
