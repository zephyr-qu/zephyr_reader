//! 书籍管理 API — FRB 薄封装层

use std::collections::HashMap;

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use crate::common::AppError;
use crate::domain::book::book_repo::BookRepository;
use crate::domain::book::service;
use crate::domain::book::{Book, BookStatus, BookshelfBook};
use crate::domain::category::Category;
use crate::domain::chapter::Chapter;
use crate::domain::progress::models::ReadingProgress;
use crate::infra::manager::storage_pool;

/// 书籍详情聚合
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata = ("freezed"))]
pub struct BookDetail {
    pub book: Book,
    pub progress: Option<ReadingProgress>,
    pub chapters: Vec<Chapter>,
    pub categories: Vec<Category>,
    pub session_count: i32,
    /// 本书累计阅读时长（秒），来自 reading_sessions 聚合（与统计页同一真相源）。
    pub total_reading_seconds: i64,
}
// ============================================================
// 书籍 CRUD — 薄 FFI 封装
// ============================================================

/// 获取书籍详情（聚合查询）
#[frb]
pub async fn get_book_detail(book_id: String) -> Result<BookDetail, AppError> {
    tracing::debug!("[book] get_book_detail: book_id={}", book_id);
    Ok(service::get_book_detail(&book_id).await?)
}

/// 获取书架展示用的书籍列表（含阅读进度），支持分类/状态筛选。
#[frb]
pub async fn list_bookshelf_books(
    category_id: Option<String>,
    status: Option<BookStatus>,
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!(
        "[book] list_bookshelf_books: category={:?} status={:?} sort={:?}/{:?}",
        category_id,
        status,
        sort_by,
        sort_order
    );
    service::list_bookshelf_books(
        category_id.as_deref(),
        status,
        sort_by.as_deref(),
        sort_order.as_deref(),
    )
    .await
}

/// 获取书名映射
#[frb]
pub async fn list_book_titles() -> Result<HashMap<String, String>, AppError> {
    tracing::debug!("[book] list_book_titles");
    let pool = storage_pool()?;
    let titles = BookRepository::list_titles(&pool).await?;
    Ok(titles.into_iter().map(|t| (t.book_id, t.title)).collect())
}

/// 新增或更新书籍
#[frb]
pub async fn upsert_book(book: Book) -> Result<(), AppError> {
    tracing::info!(
        "[book] upsert_book: book_id={}, title={}",
        book.book_id,
        book.title
    );
    let pool = storage_pool()?;
    BookRepository::save(&pool, &book).await
}

/// 删除书籍及其缓存、搜索索引和封面文件
#[frb]
pub async fn delete_book(book_id: String, covers_dir: String) -> Result<(), AppError> {
    tracing::info!("[book] delete_book: book_id={}", book_id);
    service::delete_book(&book_id, &covers_dir).await?;
    Ok(())
}

/// 搜索书籍
#[frb]
pub async fn search_books(keyword: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] search_books: keyword={}", keyword);
    let pool = storage_pool()?;
    BookRepository::search(&pool, &keyword).await
}

/// 书架搜索（含阅读进度）
#[frb]
pub async fn search_bookshelf_books(keyword: String) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] search_bookshelf_books: keyword={}", keyword);
    let pool = storage_pool()?;
    BookRepository::search_bookshelf(&pool, &keyword).await
}

/// 根据 ID 获取书籍
#[frb]
pub async fn get_book(book_id: String) -> Result<Option<Book>, AppError> {
    tracing::debug!("[book] get_book: book_id={}", book_id);
    let pool = storage_pool()?;
    BookRepository::find_by_id(&pool, &book_id).await
}

/// 获取最近阅读的书籍
#[frb]
pub async fn list_recently_opened_books(limit: i32) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_recently_opened_books: limit={}", limit);
    let pool = storage_pool()?;
    BookRepository::list_recent(&pool, limit as i64).await
}

/// 更新书籍状态
#[frb]
pub async fn update_book_status(book_id: String, status: BookStatus) -> Result<(), AppError> {
    tracing::info!("[book] update_book_status: book_id={}", book_id);
    let pool = storage_pool()?;
    BookRepository::update_status(&pool, &book_id, status).await
}

/// 更新书籍置顶状态
#[frb]
pub async fn update_book_pin(book_id: String, is_pinned: bool) -> Result<(), AppError> {
    tracing::info!("[book] update_book_pin: book_id={}", book_id);
    let pool = storage_pool()?;
    BookRepository::update_pin(&pool, &book_id, is_pinned).await
}

/// 记录书籍被打开（更新 last_opened_at，驱动「最近阅读」）
#[frb]
pub async fn touch_book(book_id: String) -> Result<(), AppError> {
    tracing::debug!("[book] touch_book: book_id={}", book_id);
    let pool = storage_pool()?;
    BookRepository::update_last_opened(&pool, &book_id).await
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
    tracing::info!(
        "[book] batch_set_categories_for_books: count={}",
        book_ids.len()
    );
    service::batch_set_categories_for_books(&book_ids, &category_ids).await
}

/// 导入书籍文件（校验→解析→入库）
#[frb]
pub async fn import_book(file_path: String) -> Result<String, AppError> {
    tracing::info!("[book] import_book: file_path={}", file_path);
    service::import_book(&file_path).await
}
