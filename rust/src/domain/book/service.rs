//! 书籍管理业务逻辑
//!
//! 提供书籍的聚合查询、级联删除、创建和解析等业务操作。
//! 数据访问委托给 book_repo 及其他关联 repo。

use std::collections::HashMap;

use crate::common::AppError;
use crate::common::security::validate_file_path;
use crate::domain::book::{Book, BookFormat, BookStatus, BookshelfBook};
use crate::domain::book::book_repo::BookRepository;
use crate::domain::category::Category;
use crate::domain::category::category_repo::CategoryRepository;
use crate::domain::chapter::Chapter;
use crate::domain::chapter::chapter_repo::ChapterRepository;
use crate::domain::note::NoteStats;
use crate::domain::note::note_repo::NoteRepository;
use crate::domain::progress::models::ReadingProgress;
use crate::domain::progress::progress_repo::ProgressRepository;
use crate::domain::sessions::session_repo::SessionRepository;
use crate::domain::vocabulary::vocab_repo::VocabRepository;
use crate::infra::manager::storage_pool;
use crate::parser::registry::parser_for_file;
use crate::pipeline::chapter_ir::IrCacheRepository;

/// 获取书籍详情（聚合查询，返回各组件供 API 层组装 BookDetail）
pub async fn get_book_detail(
    book_id: &str,
) -> Result<
    (
        Book,
        Option<ReadingProgress>,
        NoteStats,
        Vec<Chapter>,
        Vec<Category>,
        i32,
        i32,
    ),
    AppError,
> {
    let pool = storage_pool()?;

    let book = BookRepository::find_by_id(&pool, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound { entity: "book".into() })?;
    let progress = ProgressRepository::find_by_book(&pool, book_id).await?;
    let note_stats = NoteRepository::find_note_stats(&pool, book_id).await?;
    let chapters = ChapterRepository::find_by_book(&pool, book_id).await?;
    let categories = CategoryRepository::list_by_book(&pool, book_id).await?;
    let session_count = SessionRepository::count_by_book(&pool, book_id).await?;
    let vocab_count = VocabRepository::count_by_book(&pool, book_id).await?;

    Ok((book, progress, note_stats, chapters, categories, session_count, vocab_count))
}

/// 列出所有书籍
pub async fn list_books() -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list(&pool).await
}

/// 列出书架书籍（含进度）
pub async fn list_bookshelf_books(sort_by: &str, sort_order: &str) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_bookshelf(&pool, sort_by, sort_order).await
}

/// 获取书名映射
pub async fn map_book_titles() -> Result<HashMap<String, String>, AppError> {
    let pool = storage_pool()?;
    let titles = BookRepository::list_titles(&pool).await?;
    Ok(titles.into_iter().map(|t| (t.book_id, t.title)).collect())
}

/// 保存书籍
pub async fn upsert_book(book: &Book) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookRepository::save(&pool, book).await
}

/// 级联删除书籍（含封面文件删除、缓存失效）
///
/// 注意：搜索索引清理由调用方负责（search::delete_by_book）
pub async fn delete_book(book_id: &str, covers_dir: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;

    // 删除封面文件
    if let Ok(Some(cover_path)) = BookRepository::find_cover_path(&pool, book_id).await {
        let full_path = std::path::Path::new(covers_dir).join(&cover_path);
        if full_path.exists()
            && let Err(e) = tokio::fs::remove_file(&full_path).await {
                tracing::warn!("[book] failed to delete cover file: {}", e);
            }
    }

    // 级联删除关联数据
    BookRepository::delete_cascade(&pool, book_id)
        .await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string() })?;

    // 失效 IR 缓存
    let kv = crate::infra::ensure_storage()?.kv();
    let cache_repo = IrCacheRepository::new(kv);
    if let Err(e) = cache_repo.invalidate_book_cache(book_id) {
        tracing::warn!("[book] failed to clear book cache: {}", e);
    }

    Ok(())
}

/// 搜索书籍
pub async fn search_books(keyword: &str) -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::search(&pool, keyword).await
}

/// 书架搜索（含进度）
pub async fn search_bookshelf_books(keyword: &str) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    BookRepository::search_bookshelf(&pool, keyword).await
}

/// 根据 ID 获取书籍
pub async fn get_book(book_id: &str) -> Result<Option<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::find_by_id(&pool, book_id).await
}

/// 按状态列出书籍
pub async fn list_books_by_status(status: BookStatus) -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_by_status(&pool, status).await
}

/// 按状态列出书架书籍
pub async fn list_bookshelf_books_by_status(status: BookStatus) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_bookshelf_by_status(&pool, status).await
}

/// 根据文件路径获取书籍
pub async fn get_book_by_file_path(validated_path: &str) -> Result<Option<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::find_by_file_path(&pool, validated_path).await
}

/// 获取置顶书籍
pub async fn list_pinned_books() -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_pinned(&pool).await
}

/// 获取最近阅读书籍
pub async fn list_recently_opened_books(limit: i64) -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_recent(&pool, limit).await
}

/// 分页查询书籍
pub async fn list_books_paginated(
    limit: i64,
    offset: i64,
    sort_by: &str,
    sort_order: &str,
) -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    BookRepository::list_paginated(&pool, limit, offset, sort_by, sort_order).await
}

/// 统计书籍总数
pub async fn count_books() -> Result<i64, AppError> {
    let pool = storage_pool()?;
    BookRepository::count(&pool).await
}

/// 更新书籍状态
pub async fn update_book_status(book_id: &str, status: BookStatus) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookRepository::update_status(&pool, book_id, status).await
}

/// 更新书籍置顶
pub async fn update_book_pin(book_id: &str, is_pinned: bool) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookRepository::update_pin(&pool, book_id, is_pinned).await
}

/// 更新书籍标题
pub async fn update_book_title(book_id: &str, title: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookRepository::update_title(&pool, book_id, title).await
}

/// 批量更新书籍元数据
pub async fn update_book_metadata(
    book_id: &str,
    title: Option<&str>,
    author: Option<&str>,
    description: Option<&str>,
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookRepository::update_metadata(&pool, book_id, title, author, description).await
}

/// 创建外部导入的书籍（如来自网页搜索）
pub async fn create_web_book(
    title: &str,
    author: &str,
    file_path: &str,
    chapter_count: i64,
    total_characters: i64,
    cover_path: Option<&str>,
    description: Option<&str>,
) -> Result<Book, AppError> {
    let book = Book::new(
        file_path.to_string(), 0, title.to_string(), BookFormat::Txt, chapter_count, total_characters,
        None, None, Some(author.to_string()), cover_path.map(|s| s.to_string()), description.map(|s| s.to_string()), None, None, None,
    );
    let pool = storage_pool()?;
    BookRepository::save(&pool, &book).await?;
    BookRepository::save_metadata(&pool, &book).await?;
    Ok(book)
}

/// 批量更新书籍阅读状态
pub async fn batch_update_book_status(book_ids: &[String], status: BookStatus) -> Result<(), AppError> {
    let pool = storage_pool()?;
    for book_id in book_ids {
        BookRepository::update_status(&pool, book_id, status).await?;
    }
    Ok(())
}

/// 批量设置书籍分类
pub async fn batch_set_categories_for_books(
    book_ids: &[String],
    category_ids: &[String],
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    for book_id in book_ids {
        CategoryRepository::set_by_book(&pool, book_id, category_ids).await?;
    }
    Ok(())
}

/// 解析书籍文件
///
/// 验证路径、检查大小限制、选择解析器、保存元数据。
pub async fn parse_book(file_path: &str) -> Result<String, AppError> {
    const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;

    let validated_path = validate_file_path(file_path)?;
    let metadata = tokio::fs::metadata(&validated_path).await
        .map_err(|e| AppError::FileReadError { path: validated_path.clone(), details: e.to_string() })?;
    if metadata.len() > MAX_FILE_SIZE {
        return Err(AppError::SecurityError {
            reason: format!("file size exceeds limit (max {} MB)", MAX_FILE_SIZE / 1024 / 1024),
            path: validated_path,
        });
    }

    let pool = storage_pool()?;
    if let Some(existing) = BookRepository::find_by_file_path(&pool, &validated_path).await? {
        return Ok(existing.book_id);
    }

    let parser = parser_for_file(&validated_path)?;
    let result = parser.parse(&validated_path).await?;
    BookRepository::save(&pool, &result.book_info).await?;
    BookRepository::save_metadata(&pool, &result.book_info).await?;
    ChapterRepository::save(&pool, &result.book_info.book_id, &result.chapters).await?;
    Ok(result.book_info.book_id)
}
