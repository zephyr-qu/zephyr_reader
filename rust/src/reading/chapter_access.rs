// ============================================================
// 文件作用：章节访问相关函数：章节边界、格式识别、章节读取。
//
// 公有类型/函数：
//   - format_from_file_path() — 从文件路径推断格式
//   - get_chapter_bounds() — 从 DB 获取章节边界信息
//
// 私有函数：
//   - get_chapter() — 获取指定章节的原始文本内容
// ============================================================

//! 章节访问相关函数：章节边界、格式识别、章节读取（first_spine/partial/full）。
//!
//! Phase 1 只迁出 `format_from_file_path` + `get_chapter_bounds`。
//! 章节读取函数（`get_chapter`）
//! 留到 Phase 4。
//!
//! P1: `get_chapter(config)` 改走 block 路径（IR → BlockPaginator）。

use crate::domain::AppError;
use crate::parser::registry;
use crate::storage::models::BookFormat;
use crate::storage::repos::{BookRepository, ChapterRepository};
use crate::storage::storage_pool;

use super::BOOK_ID_CACHE;
use crate::reading::provider_cache::get_or_create_provider;
use crate::utils::security::validate_file_path;

/// 从文件路径推断格式
pub fn format_from_file_path(file_path: &str) -> Result<BookFormat, AppError> {
    let ext = std::path::Path::new(file_path)
        .extension()
        .and_then(|e| e.to_str())
        .ok_or_else(|| AppError::UnsupportedFormat {
            format: "file has no extension".into(),
        })?;
    registry::format_from_extension(ext)
}

/// 从 DB 获取章节边界信息（TXT 的文件字节偏移，EPUB 的 spine 索引）。
///
/// 流程：
/// 1. 命中 `BOOK_ID_CACHE` → 直接读 chapter row
/// 2. 未命中 → `find_by_file_path` 反查 book_id → 写缓存 → 读 chapter row
///
/// `parking_lot::MutexGuard` 不是 Send，所有锁内操作必须仅做 clone/get，跨 `await` 之前释放。
pub async fn get_chapter_bounds(
    validated_path: &str,
    chapter_index: i32,
) -> Result<(i32, i32), AppError> {
    let pool = storage_pool()?;

    // Try cached book_id first (fast path).
    // M8 fix: if `find_by_index` misses, the cached book_id may be
    // stale (e.g. user re-imported the same path with different book_id,
    // or DB row was reset). Invalidate the cache entry and retry via
    // `find_by_file_path` once. Without this, stale cache returns
    // `ChapterExtractError` and the user has to clear the cache
    // manually to recover.
    let cached_book_id = {
        let mut cache = BOOK_ID_CACHE.lock();
        cache.get(validated_path).cloned()
    };
    if let Some(book_id) = cached_book_id {
        if let Ok(Some(chapter)) =
            ChapterRepository::find_by_index(&pool, &book_id, chapter_index).await
        {
            return Ok((chapter.start_index as i32, chapter.end_index as i32));
        }
        // Miss → invalidate and fall through to fresh lookup.
        {
            let mut cache = BOOK_ID_CACHE.lock();
            cache.pop(validated_path);
        }
        tracing::debug!(
            "BOOK_ID_CACHE invalidated for {validated_path} (find_by_index miss), retrying via find_by_file_path"
        );
    }

    // Slow path: no cached book_id (or stale one was just invalidated).
    // Resolve via DB and populate the cache for next time.
    let book = BookRepository::find_by_file_path(&pool, validated_path)
        .await?
        .ok_or_else(|| AppError::FileNotFound {
            path: validated_path.into(),
        })?;
    let book_id = book.book_id.clone();
    {
        let mut cache = BOOK_ID_CACHE.lock();
        cache.put(validated_path.to_string(), book_id.clone());
    }

    let chapter = ChapterRepository::find_by_index(&pool, &book_id, chapter_index)
        .await?
        .ok_or_else(|| AppError::ChapterExtractError {
            index: chapter_index,
            reason: "chapter not found in DB".into(),
        })?;

    Ok((chapter.start_index as i32, chapter.end_index as i32))
}



/// 获取指定章节的原始文本内容。
pub(crate) async fn get_chapter(
    file_path: String,
    chapter_index: i32,
) -> Result<String, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    if matches!(format, BookFormat::Txt | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();

        let text = if format == BookFormat::Epub {
            provider.read_text_range(0, content_len)?
        } else {
            let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            let start = cs.max(0) as u64;
            let end = (ce.max(0) as u64).min(content_len);
            provider.read_text_range(start, end)?
        };
        Ok(text)
    } else {
        Err(AppError::UnsupportedFormat {
            format: format!("unsupported format for chapter read: {:?}", format),
        })
    }
}
