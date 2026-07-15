//! 书籍管理 API
//!
//! 提供书籍的 CRUD 操作、搜索、分页、状态管理等功能。

use flutter_rust_bridge::frb;
use std::collections::HashMap;

use super::async_storage;
use crate::api::search;
use crate::domain::AppError;
use crate::storage::ensure_storage;
use crate::storage::repos::{
    BookRepository, CategoryRepository, ChapterRepository, IrCacheRepository,
    NoteRepository, ProgressRepository, SessionRepository, VocabRepository,
};

pub use crate::storage::models::{
    Book, BookFormat, BookStatus, BookshelfBook, BookTitle, Category, Chapter, NoteStats,
    ReadingProgress, ReadingSession, Vocab,
};

// ============================================================
// 文件作用：书籍管理 API — 书籍 CRUD、搜索、分页、状态管理。
//
// 公有结构体：
//   - BookDetail — 书籍详情聚合（含进度/笔记/章节/分类）
//
// 公有函数：
//   - get_book_detail() — 获取书籍详情
//   - list_books() — 获取所有书籍列表
//   - list_bookshelf_books() — 书架书籍列表（含进度）
//   - map_book_titles() — 获取书名映射
//   - upsert_book() — 新增或更新书籍
//   - delete_book() — 删除书籍及缓存
//   - search_books() — 搜索书籍
//   - search_bookshelf_books() — 书架搜索（含进度）
//   - get_book() — 根据 ID 获取书籍
//   - list_books_by_status() — 按状态获取
//   - list_bookshelf_books_by_status() — 书架版按状态筛选
//   - get_book_by_file_path() — 根据路径获取
//   - list_pinned_books() — 置顶书籍列表
//   - list_recently_opened_books() — 最近阅读
//   - list_books_paginated() — 分页查询
//   - count_books() — 书籍总数
//   - update_book_status() — 更新状态
//   - update_book_pin() — 更新置顶
//   - update_book_title() — 更新标题
//   - update_book_metadata() — 批量更新元数据
//   - create_web_book() — 创建外部导入书籍
//   - batch_update_book_status() — 批量更新状态
//   - batch_set_categories_for_books() — 批量设置分类
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

/// 获取书籍详情（聚合查询，一次调用返回所有详情页数据）
#[frb]
pub async fn get_book_detail(book_id: String) -> Result<BookDetail, AppError> {

    tracing::debug!("[book] get_book_detail: book_id={}", book_id);
    let pool = crate::storage::storage_pool()?;

    let book = BookRepository::find_by_id(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?
        .ok_or_else(|| AppError::NotFound { entity: "book".into() })?;
    let progress = ProgressRepository::find_by_book(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let note_stats = NoteRepository::find_note_stats(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let categories = CategoryRepository::list_by_book(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let session_count = SessionRepository::count_by_book(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let vocab_count = VocabRepository::count_by_book(&pool, &book_id).await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

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

/// 获取所有书籍列表（按添加时间倒序）
///
/// # 返回
/// 所有书籍列表
#[frb]
pub async fn list_books() -> Result<Vec<Book>, AppError> {
    async_storage!(|pool|BookRepository::list(pool))
}

/// 获取书架展示用的书籍列表（含阅读进度，单次 JOIN 查询）
///
/// 一次查询完成所有书架所需数据。
/// 排序字段支持：title / author / last_opened_at / added_at / progress
#[frb]
pub async fn list_bookshelf_books(
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] list_bookshelf_books: sort_by={:?}, sort_order={:?}", sort_by, sort_order);
    let sort_by = sort_by.unwrap_or_else(|| "last_opened_at".to_string());
    let sort_order = sort_order.unwrap_or_else(|| "desc".to_string());
    async_storage!(|pool| BookRepository::list_bookshelf(pool, &sort_by, &sort_order))
}
#[frb]
pub async fn map_book_titles() -> Result<HashMap<String, String>, AppError> {
    tracing::debug!("[book] map_book_titles");
    let pool = crate::storage::storage_pool()?;
    let titles = BookRepository::list_titles(&pool).await?;
    Ok(titles.into_iter().map(|t| (t.book_id, t.title)).collect())
}

/// 新增或更新书籍(upsert)
///
/// # 参数
/// * `book` - 要保存的书籍对象
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn upsert_book(book: Book) -> Result<(), AppError> {
    tracing::info!("[book] upsert_book: book_id={}, title={}", book.book_id, book.title);
    async_storage!(|pool| BookRepository::save(pool, &book))
}

/// 删除书籍及其缓存、搜索索引和封面文件
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `covers_dir` - 封面文件存储目录路径，用于拼接完整路径后删除封面文件
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_book(book_id: String, covers_dir: String) -> Result<(), AppError> {
    tracing::info!("[book] delete_book: book_id={}", book_id);
    let storage = ensure_storage()?;
    let pool = storage.pool()?;

    // 删除封面文件
    if let Ok(Some(cover_path)) = BookRepository::find_cover_path(&pool, &book_id).await {
        let full_path = std::path::Path::new(&covers_dir).join(&cover_path);
        if full_path.exists() {
            if let Err(e) = tokio::fs::remove_file(&full_path).await {
                tracing::warn!("failed to delete cover file: {}", e);
            }
        }
    }

    BookRepository::delete_cascade(&pool, &book_id)
        .await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    let kv = storage.kv();
    let cache_repo = IrCacheRepository::new(kv);
    if let Err(e) = cache_repo.invalidate_book_cache(&book_id) {
        tracing::warn!("failed to clear book cache: {}", e);
    }
    if let Err(e) = search::delete_by_book(book_id).await {
        tracing::warn!("failed to clear search index: {}", e);
    }
    Ok(())
}

/// 搜索书籍
///
/// # 参数
/// * `keyword` - 搜索关键词
///
/// # 返回
/// 匹配关键词的书籍列表
#[frb]
pub async fn search_books(keyword: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] search_books: keyword={}", keyword);
    async_storage!(|pool| BookRepository::search(pool, &keyword))
}

/// 书架搜索（标题或作者模糊匹配，含阅读进度）
///
/// 返回 BookshelfBook 结构体，直接供给书架展示，无需二次转换。
#[frb]
pub async fn search_bookshelf_books(keyword: String) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] search_bookshelf_books: keyword={}", keyword);
    async_storage!(|pool| BookRepository::search_bookshelf(pool, &keyword))
}

/// 根据 ID 获取书籍
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 存在则返回 Some(Book), 否则返回 None
#[frb]
pub async fn get_book(book_id: String) -> Result<Option<Book>, AppError> {
    tracing::debug!("[book] get_book: book_id={}", book_id);
    async_storage!(|pool| BookRepository::find_by_id(pool, &book_id))
}

/// 根据状态获取书籍列表
///
/// # 参数
/// * `status` - 书籍状态枚举值
///
/// # 返回
/// 指定状态的书籍列表
#[frb]
pub async fn list_books_by_status(status: BookStatus) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_books_by_status: status={:?}", status);
    async_storage!(|pool| BookRepository::list_by_status(pool, status))
}

/// 按阅读状态筛选书籍（书架版，含进度）
#[frb]
pub async fn list_bookshelf_books_by_status(status: BookStatus) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[book] list_bookshelf_books_by_status: status={:?}", status);
    async_storage!(|pool| BookRepository::list_bookshelf_by_status(pool, status))
}

/// 根据书籍路径获取
///
/// # 参数
/// * `validated_path` - 已验证的文件路径
///
/// # 返回
/// 存在则返回 Some(Book), 否则返回 None
#[frb]
pub async fn get_book_by_file_path(validated_path: String) -> Result<Option<Book>, AppError> {
    tracing::debug!("[book] get_book_by_file_path: path={}", validated_path);
    async_storage!(|pool| BookRepository::find_by_file_path(pool, &validated_path))
}

/// 获取置顶书籍列表
///
/// # 返回
/// 置顶排序的书籍列表
#[frb]
pub async fn list_pinned_books() -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_pinned_books");
    async_storage!(BookRepository::list_pinned)
}

/// 获取最近阅读的书籍
///
/// # 参数
/// * `limit` - 返回数量限制
///
/// # 返回
/// 按最近打开时间排序的书籍列表
#[frb]
pub async fn list_recently_opened_books(limit: i32) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[book] list_recently_opened_books: limit={}", limit);
    async_storage!(|pool| BookRepository::list_recent(pool, limit as i64))
}

/// 分页获取书籍列表
///
/// # 参数
/// * `limit` - 每页数量
/// * `offset` - 偏移量
/// * `sort_by` - 排序字段(可选,默认"added_at")
/// * `sort_order` - 排序方向(可选,默认"desc")
///
/// # 返回
/// 分页后的书籍列表
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
    async_storage!(|pool| BookRepository::list_paginated(
        pool,
        limit as i64,
        offset as i64,
        &sort_by,
        &sort_order
    ))
}

/// 获取书籍总数
///
/// # 返回
/// 数据库中书籍总记录数
#[frb]
pub async fn count_books() -> Result<i64, AppError> {
    tracing::debug!("[book] count_books");
    async_storage!(BookRepository::count)
}

/// 更新书籍状态
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `status` - 新的状态值
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_book_status(book_id: String, status: BookStatus) -> Result<(), AppError> {
    tracing::info!("[book] update_book_status: book_id={}", book_id);
    async_storage!(|pool| BookRepository::update_status(pool, &book_id, status))
}

/// 更新书籍置顶状态
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `is_pinned` - 是否置顶
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_book_pin(book_id: String, is_pinned: bool) -> Result<(), AppError> {
    tracing::info!("[book] update_book_pin: book_id={}", book_id);
    async_storage!(|pool| BookRepository::update_pin(pool, &book_id, is_pinned))
}

/// 更新书籍标题
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `title` - 新标题
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_book_title(book_id: String, title: String) -> Result<(), AppError> {
    tracing::info!("[book] update_book_title: book_id={}", book_id);
    async_storage!(|pool| BookRepository::update_title(pool, &book_id, &title))
}

/// 批量更新书籍元数据(仅更新 Some 字段)
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `title` - 新标题(可选)
/// * `author` - 新作者(可选)
/// * `description` - 新描述(可选)
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_book_metadata(
    book_id: String,
    title: Option<String>,
    author: Option<String>,
    description: Option<String>,
) -> Result<(), AppError> {
    tracing::info!("[book] update_book_metadata: book_id={}", book_id);
    async_storage!(|pool| BookRepository::update_metadata(
        pool,
        &book_id,
        title.as_deref(),
        author.as_deref(),
        description.as_deref(),
    ))
}

/// 创建外部导入的书籍(如来自网页搜索)
///
/// 生成 UUID book_id，写入 DB，返回完整 Book 对象。
/// 适用于无本地文件的导入场景(如 Web 文章添加)。
///
/// # 参数
/// * `title` - 标题
/// * `author` - 作者
/// * `file_path` - 文件路径
/// * `chapter_count` - 章节数量
/// * `total_characters` - 总字符数
/// * `cover_path` - 封面路径(可选)
/// * `description` - 描述(可选)
///
/// # 返回
/// 创建完成的书籍对象
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
    let book = Book::new(
        &file_path,
        0,
        &title,
        BookFormat::Txt,
        chapter_count as i64,
        total_characters,
        None,
        None,
        Some(&author),
        cover_path.as_deref(),
        description.as_deref(),
        None,
        None,
        None,
    );
    let book_for_db = book.clone();
    async_storage!(|pool| async move {
        BookRepository::save(pool, &book_for_db).await?;
        BookRepository::save_metadata(pool, &book_for_db).await?;
        Ok::<_, AppError>(())
    })?;

    Ok(book)
}


/// 批量更新书籍阅读状态（单次 FFI 调用）
#[frb]
pub async fn batch_update_book_status(
    book_ids: Vec<String>,
    status: BookStatus,
) -> Result<(), AppError> {
    tracing::info!("[book] batch_update_book_status: count={}", book_ids.len());
    let pool = crate::storage::ensure_storage()?.pool()?;
    for book_id in &book_ids {
        BookRepository::update_status(&pool, book_id, status.clone()).await?;
    }
    Ok(())
}

/// 批量设置书籍分类（单次 FFI 调用）
#[frb]
pub async fn batch_set_categories_for_books(
    book_ids: Vec<String>,
    category_ids: Vec<String>,
) -> Result<(), AppError> {
    tracing::info!("[book] batch_set_categories_for_books: count={}", book_ids.len());
    let pool = crate::storage::ensure_storage()?.pool()?;
    use crate::storage::repos::category_repo::CategoryRepository;
    for book_id in &book_ids {
        CategoryRepository::set_by_book(&pool, book_id, &category_ids).await?;
    }
    Ok(())
}
