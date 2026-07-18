//! 书籍管理业务逻辑
//!
//! 提供书籍的聚合查询、级联删除、创建和解析等业务操作。
//! 纯 CRUD 透传已内联到 api/ 层，此处只保留有实际业务逻辑的操作。

use crate::api::book::BookDetail;
use crate::common::AppError;
use crate::common::security::validate_file_path;
use crate::domain::book::book_repo::BookRepository;
use crate::domain::book::{Book, BookFormat, BookStatus, BookshelfBook};
use crate::domain::category::category_repo::CategoryRepository;
use crate::domain::chapter::chapter_repo::ChapterRepository;
use crate::domain::note::note_repo::NoteRepository;
use crate::domain::progress::progress_repo::ProgressRepository;
use crate::domain::sessions::session_repo::SessionRepository;
use crate::domain::vocab::vocab_repo::VocabRepository;
use crate::infra::manager::storage_pool;
use crate::parser::registry::parser_for_file;
use crate::pipeline::chapter_ir::IrCacheRepository;
use std::path::Path;

/// 获取书籍详情（聚合查询）
pub async fn get_book_detail(book_id: &str) -> Result<BookDetail, AppError> {
    let pool = storage_pool()?;

    let book = BookRepository::find_by_id(&pool, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound {
            entity: "book".into(),
        })?;
    let progress = ProgressRepository::find_by_book(&pool, book_id).await?;
    let note_stats = NoteRepository::find_note_stats(&pool, book_id).await?;
    let chapters = ChapterRepository::find_by_book(&pool, book_id).await?;
    let categories = CategoryRepository::list_by_book(&pool, book_id).await?;
    let session_count = SessionRepository::count_by_book(&pool, book_id).await?;
    let vocab_count = VocabRepository::count_by_book(&pool, book_id).await?;

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

/// 列出书架书籍（含进度），支持按分类/状态筛选/排序。
pub async fn list_bookshelf_books(
    category_id: Option<&str>,
    status: Option<BookStatus>,
    sort_by: Option<&str>,
    sort_order: Option<&str>,
) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    match (category_id, status) {
        (Some(cat_id), Some(st)) => {
            CategoryRepository::list_bookshelf_by_category_and_status(&pool, cat_id, st).await
        }
        (Some(cat_id), None) => CategoryRepository::list_bookshelf_by_category(&pool, cat_id).await,
        (None, Some(st)) => BookRepository::list_bookshelf_by_status(&pool, st).await,
        (None, None) => {
            let sort_by = sort_by.unwrap_or("last_opened_at");
            let sort_order = sort_order.unwrap_or("desc");
            BookRepository::list_bookshelf(&pool, sort_by, sort_order).await
        }
    }
}

/// 级联删除书籍（含封面文件删除、缓存失效）
///
/// 注意：搜索索引清理由调用方负责（search::delete_by_book）
pub async fn delete_book(book_id: &str, covers_dir: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;

    // 先查 file_path（级联删除后 book 行消失）
    let file_path = match BookRepository::find_by_id(&pool, book_id).await {
        Ok(Some(book)) => Some(book.file_path),
        _ => None,
    };

    // 删除封面文件
    if let Ok(Some(cover_path)) = BookRepository::find_cover_path(&pool, book_id).await {
        let full_path = std::path::Path::new(covers_dir).join(&cover_path);
        if full_path.exists()
            && let Err(e) = tokio::fs::remove_file(&full_path).await
        {
            tracing::warn!("[book] failed to delete cover file: {}", e);
        }
    }

    // 级联删除关联数据
    BookRepository::delete_cascade(&pool, book_id)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: e.to_string(),
        })?;

    // 失效 IR 缓存
    if let Some(ref fp) = file_path {
        let kv = crate::infra::ensure_storage()?.kv();
        let cache_repo = IrCacheRepository::new(kv);
        if let Err(e) = cache_repo.invalidate_book_cache(fp) {
            tracing::warn!("[book] failed to clear ir cache for '{}': {}", fp, e);
        }
    } else {
        tracing::warn!(
            "[book] book '{}' not found — cannot invalidate IR cache",
            book_id
        );
    }

    Ok(())
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
    let cover = cover_path
        .and_then(|s| Path::new(s).file_name())
        .map(|f| f.to_string_lossy().into_owned());
    let book = Book::new(
        file_path.to_string(),
        0,
        title.to_string(),
        BookFormat::Txt,
        chapter_count,
        total_characters,
        None,
        None,
        Some(author.to_string()),
        cover,
        description.map(|s| s.to_string()),
        None,
        None,
        None,
    );
    let pool = storage_pool()?;
    BookRepository::save(&pool, &book).await?;
    BookRepository::save_metadata(&pool, &book).await?;
    Ok(book)
}

/// 批量更新书籍阅读状态
pub async fn batch_update_book_status(
    book_ids: &[String],
    status: BookStatus,
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    let mut tx = pool.begin().await?;
    for book_id in book_ids {
        sqlx::query("UPDATE books SET status = ? WHERE id = ?")
            .bind(status.as_ref())
            .bind(book_id)
            .execute(&mut *tx)
            .await?;
    }
    tx.commit().await?;
    Ok(())
}

/// 批量设置书籍分类
pub async fn batch_set_categories_for_books(
    book_ids: &[String],
    category_ids: &[String],
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    let mut tx = pool.begin().await?;
    for book_id in book_ids {
        sqlx::query("DELETE FROM book_categories WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;
        for cat_id in category_ids {
            sqlx::query(
                "INSERT INTO book_categories (book_id, category_id) VALUES (?, ?) \
                 ON CONFLICT(book_id, category_id) DO NOTHING",
            )
            .bind(book_id)
            .bind(cat_id)
            .execute(&mut *tx)
            .await?;
        }
    }
    tx.commit().await?;
    Ok(())
}

/// 解析书籍文件
///
/// 导入书籍：验证路径、检查大小限制、选择解析器、保存元数据。
pub async fn import_book(file_path: &str) -> Result<String, AppError> {
    const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;

    let validated_path = validate_file_path(file_path)?;
    let metadata =
        tokio::fs::metadata(&validated_path)
            .await
            .map_err(|e| AppError::FileReadError {
                path: validated_path.clone(),
                details: e.to_string(),
            })?;
    if metadata.len() > MAX_FILE_SIZE {
        return Err(AppError::SecurityError {
            reason: format!(
                "file size exceeds limit (max {} MB)",
                MAX_FILE_SIZE / 1024 / 1024
            ),
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
