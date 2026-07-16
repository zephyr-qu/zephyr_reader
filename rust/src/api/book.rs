//! 书籍管理 API — FRB 薄封装层

use std::collections::HashMap;

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::book::service;
use crate::domain::book::{Book, BookStatus, BookshelfBook};
use crate::domain::category::Category;
use crate::domain::chapter::Chapter;
use crate::domain::note::NoteStats;

use crate::domain::progress::models::ReadingProgress;
use crate::parser::epub::EpubMetadata;

// ============================================================
// API 响应 DTO
// ============================================================

/// 书籍详情聚合
#[frb(dart_metadata = ("freezed"))]
pub struct BookDetail {
    pub book: Book,
    pub progress: Option<ReadingProgress>,
    pub note_stats: NoteStats,
    pub chapters: Vec<Chapter>,
    pub categories: Vec<Category>,
    pub session_count: i32,
    pub vocab_count: i32,
}

// ============================================================
// 书籍 CRUD — 薄 FFI 封装
// ============================================================

/// 获取书籍详情（聚合查询）
#[frb]
pub async fn get_book_detail(book_id: String) -> Result<BookDetail, AppError> {
    tracing::debug!("[book] get_book_detail: book_id={}", book_id);
    let (book, progress, note_stats, chapters, categories, session_count, vocab_count) =
        service::get_book_detail(&book_id).await?;
    Ok(BookDetail {
        book,
        progress,
        note_stats,
        chapters,
        categories,
        session_count,
        vocab_count,
    })
}

/// 获取所有书籍列表
#[frb]
pub async fn list_books() -> Result<Vec<Book>, AppError> {
    service::list_books().await
}

/// 获取书架展示用的书籍列表（含阅读进度），支持分类/状态筛选。
#[frb]
pub async fn list_bookshelf_books(
    category_id: Option<String>,
    status: Option<BookStatus>,
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] list_bookshelf_books: category={:?} status={:?} sort={:?}/{:?}", category_id, status, sort_by, sort_order);
    service::list_bookshelf_books(
        category_id.as_deref(),
        status,
        sort_by.as_deref(),
        sort_order.as_deref(),
    ).await
}

/// 获取书名映射
#[frb]
pub async fn list_book_titles() -> Result<HashMap<String, String>, AppError> {
    tracing::debug!("[book] list_book_titles");
    service::list_book_titles().await
}

/// 新增或更新书籍
#[frb]
pub async fn upsert_book(book: Book) -> Result<(), AppError> {
    tracing::info!("[book] upsert_book: book_id={}, title={}", book.book_id, book.title);
    service::upsert_book(&book).await
}

/// 删除书籍及其缓存、搜索索引和封面文件
#[frb]
pub async fn delete_book(book_id: String, covers_dir: String) -> Result<(), AppError> {
    tracing::info!("[book] delete_book: book_id={}", book_id);
    service::delete_book(&book_id, &covers_dir).await?;
    // 搜索索引清理由 API 层负责（避免 service → api 循环依赖）
    if let Err(e) = crate::api::search::delete_by_book(book_id).await {
        tracing::warn!("[book] failed to clear search index: {}", e);
    }
    Ok(())
}

/// 搜索书籍
#[frb]
pub async fn search_books(keyword: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] search_books: keyword={}", keyword);
    service::search_books(&keyword).await
}

/// 书架搜索（含阅读进度）
#[frb]
pub async fn search_bookshelf_books(keyword: String) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] search_bookshelf_books: keyword={}", keyword);
    service::search_bookshelf_books(&keyword).await
}

/// 根据 ID 获取书籍
#[frb]
pub async fn get_book(book_id: String) -> Result<Option<Book>, AppError> {
    tracing::debug!("[book] get_book: book_id={}", book_id);
    service::get_book(&book_id).await
}

/// 根据状态获取书籍列表
#[frb]
pub async fn list_books_by_status(status: BookStatus) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_books_by_status: status={:?}", status);
    service::list_books_by_status(status).await
}



/// 根据书籍路径获取
#[frb]
pub async fn get_book_by_file_path(validated_path: String) -> Result<Option<Book>, AppError> {
    tracing::debug!("[book] get_book_by_file_path: path={}", validated_path);
    service::get_book_by_file_path(&validated_path).await
}

/// 获取置顶书籍列表
#[frb]
pub async fn list_pinned_books() -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_pinned_books");
    service::list_pinned_books().await
}

/// 获取最近阅读的书籍
#[frb]
pub async fn list_recently_opened_books(limit: i32) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_recently_opened_books: limit={}", limit);
    service::list_recently_opened_books(limit as i64).await
}

/// 分页获取书籍列表
#[frb]
pub async fn list_books_paginated(
    limit: i32,
    offset: i32,
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_books_paginated");
    let sort_by = sort_by.unwrap_or_else(|| "added_at".to_string());
    let sort_order = sort_order.unwrap_or_else(|| "desc".to_string());
    service::list_books_paginated(limit as i64, offset as i64, &sort_by, &sort_order).await
}

/// 获取书籍总数
#[frb]
pub async fn count_books() -> Result<i64, AppError> {
    tracing::debug!("[book] count_books");
    service::count_books().await
}

/// 更新书籍状态
#[frb]
pub async fn update_book_status(book_id: String, status: BookStatus) -> Result<(), AppError> {
    tracing::info!("[book] update_book_status: book_id={}", book_id);
    service::update_book_status(&book_id, status).await
}

/// 更新书籍置顶状态
#[frb]
pub async fn update_book_pin(book_id: String, is_pinned: bool) -> Result<(), AppError> {
    tracing::info!("[book] update_book_pin: book_id={}", book_id);
    service::update_book_pin(&book_id, is_pinned).await
}

/// 更新书籍标题
#[frb]
pub async fn update_book_title(book_id: String, title: String) -> Result<(), AppError> {
    tracing::info!("[book] update_book_title: book_id={}", book_id);
    service::update_book_title(&book_id, &title).await
}

/// 批量更新书籍元数据
#[frb]
pub async fn update_book_metadata(
    book_id: String,
    title: Option<String>,
    author: Option<String>,
    description: Option<String>,
) -> Result<(), AppError> {
    tracing::info!("[book] update_book_metadata: book_id={}", book_id);
    service::update_book_metadata(&book_id, title.as_deref(), author.as_deref(), description.as_deref()).await
}

/// 创建外部导入的书籍
#[frb]
pub async fn create_web_book(
    title: String,
    author: String,
    file_path: String,
    chapter_count: i32,
    total_characters: i64,
    cover_path: Option<String>,
    description: Option<String>,
) -> Result<Book, AppError> {
    tracing::info!("[book] create_web_book: title={}", title);
    service::create_web_book(
        &title, &author, &file_path, chapter_count as i64, total_characters,
        cover_path.as_deref(), description.as_deref(),
    ).await
}

/// 批量更新书籍阅读状态
#[frb]
pub async fn batch_update_book_status(
    book_ids: Vec<String>,
    status: BookStatus,
) -> Result<(), AppError> {
    tracing::info!("[book] batch_update_book_status: count={}", book_ids.len());
    service::batch_update_book_status(&book_ids, status).await
}

/// 批量设置书籍分类
#[frb]
pub async fn batch_set_categories_for_books(
    book_ids: Vec<String>,
    category_ids: Vec<String>,
) -> Result<(), AppError> {
    tracing::info!("[book] batch_set_categories_for_books: count={}", book_ids.len());
    service::batch_set_categories_for_books(&book_ids, &category_ids).await
}

// ============================================================
// EPUB 特定 API
// ============================================================

/// 快速获取 EPUB 元数据
#[frb]
pub async fn get_epub_metadata(file_path: String) -> Result<EpubMetadata, AppError> {
    let validated = crate::common::security::validate_file_path(&file_path)?;
    let metadata = crate::parser::epub::unzip::get_epub_metadata(&validated)?;
    Ok(metadata)
}

/// 解码 EPUB 图片并缩放为字节
#[frb(sync)]
pub fn get_processed_epub_image_bytes(
    file_path: String,
    asset_id: String,
    max_width_px: i32,
) -> Result<Vec<u8>, AppError> {
    let validated = crate::common::security::validate_file_path(&file_path)?;
    crate::parser::epub::processed_image::get_processed_epub_image_bytes(
        &validated, &asset_id, max_width_px.max(1) as u32,
    )
}

/// 解码 EPUB 图片并缓存到本地
#[frb(sync)]
pub fn get_processed_epub_image(
    file_path: String,
    asset_id: String,
    max_width_px: i32,
) -> Result<String, AppError> {
    let validated = crate::common::security::validate_file_path(&file_path)?;
    crate::parser::epub::processed_image::get_processed_epub_image(
        &validated, &asset_id, max_width_px.max(1) as u32,
    )
}

/// 解析书籍文件
#[frb]
pub async fn parse_book(file_path: String) -> Result<String, AppError> {
    tracing::info!("[book] parse_book: file_path={}", file_path);
    service::parse_book(&file_path).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_epub_metadata_file_not_found() {
        let result = get_epub_metadata("non_existent.epub".into()).await;
        assert!(result.is_err());
        assert!(matches!(result, Err(AppError::FileNotFound { .. })));
    }
}
