//! 书籍管理 API
//!
//! 提供书籍的 CRUD 操作、搜索、分页、状态管理等功能。

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::api::search;
use crate::domain::AppError;
use crate::storage::ensure_storage;
use crate::storage::repos::{
    BookRepository, CategoryRepository, ChapterRepository, LayoutCacheRepository,
    NoteRepository, ProgressRepository, SessionRepository, VocabRepository,
};

pub use crate::storage::models::{
    Book, BookFormat, BookStatus, Category, Chapter, NoteStats, ReadingProgress,
    ReadingSession, Vocab,
};

/// 书籍详情聚合（1 次 FFI 替代 7 次调用）
#[frb(dart_metadata = ("freezed"))]
pub struct BookDetail {
    pub book: Option<Book>,
    pub progress: Option<ReadingProgress>,
    pub note_stats: NoteStats,
    pub chapters: Vec<Chapter>,
    pub categories: Vec<Category>,
    pub sessions: Vec<ReadingSession>,
    pub vocab_list: Vec<Vocab>,
}

/// 获取书籍详情（聚合查询，一次调用返回所有详情页数据）
#[frb]
pub async fn get_book_detail(book_id: String) -> Result<BookDetail, AppError> {

    let pool = crate::storage::storage_pool()?;

    let book = BookRepository::find_by_id(&pool, &book_id).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let progress = ProgressRepository::find_by_book(&pool, &book_id).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let note_stats = NoteRepository::find_note_stats(&pool, &book_id).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let categories = CategoryRepository::list_by_book(&pool, &book_id).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let sessions = SessionRepository::find_by_book(&pool, &book_id, 100).await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let vocab_list = VocabRepository::find_by_status(&pool, Some(&book_id), None, None).await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    Ok(BookDetail {
        book,
        progress,
        note_stats,
        chapters,
        categories,
        sessions,
        vocab_list,
    })
}

/// 获取所有书籍列表
///
/// # 返回
/// 书籍列表
#[frb]
pub async fn list_books() -> Result<Vec<Book>, AppError> {
    async_storage!(BookRepository::list)
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
    let storage = ensure_storage().map_err(|_| AppError::storage_not_initialized())?;
    let pool = storage
        .pool()
        .map_err(|e| AppError::database_error(e.to_string()))?;

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
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let kv = storage.kv();
    let cache_repo = LayoutCacheRepository::new(kv);
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
    async_storage!(|pool| BookRepository::search(pool, &keyword))
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
    async_storage!(|pool| BookRepository::list_by_status(pool, status))
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
    async_storage!(|pool| BookRepository::find_by_file_path(pool, &validated_path))
}

/// 获取置顶书籍列表
///
/// # 返回
/// 置顶排序的书籍列表
#[frb]
pub async fn list_pinned_books() -> Result<Vec<Book>, AppError> {
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
pub async fn list_recently_opened_books(limit: usize) -> Result<Vec<Book>, AppError> {
    async_storage!(|pool| BookRepository::list_recent(pool, limit))
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
    let book = Book::new(
        &file_path,
        0,
        &title,
        BookFormat::Txt,
        chapter_count,
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
