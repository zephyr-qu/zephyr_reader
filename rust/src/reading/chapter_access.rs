//! 章节访问相关函数：章节边界、格式识别、章节读取（first_spine/partial/full）。
//!
//! Phase 1 只迁出 `format_from_file_path` + `get_chapter_bounds`。
//! 章节读取函数（`get_chapter_first_spine_only` / `get_chapter_partial` / `get_chapter`）
//! 留到 Phase 4。

use crate::domain::{AppError, TypesetConfig};
use crate::parser::registry;
use crate::storage::models::BookFormat;
use crate::storage::repos::{BookRepository, ChapterRepository};
use crate::storage::storage_pool;

use super::book_id_cache::BOOK_ID_CACHE;
use crate::api::core::{ChapterContent, FirstSpineResult};
use crate::domain::PageContent;
use crate::reading::layout_cache::{try_get_cached, try_save_cached};
use crate::reading::provider_cache::get_or_create_provider;
use crate::text::paginate_all;
use crate::utils::security::validate_file_path;

/// 从文件路径推断格式
pub fn format_from_file_path(file_path: &str) -> Result<BookFormat, AppError> {
    let ext = std::path::Path::new(file_path)
        .extension()
        .and_then(|e| e.to_str())
        .ok_or_else(|| {
            AppError::UnsupportedFormat {
                format: "file has no extension".into(),
            }
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
        .ok_or_else(|| AppError::FileNotFound { path: validated_path.into() })?;
    let book_id = book.book_id.clone();
    {
        let mut cache = BOOK_ID_CACHE.lock();
        cache.put(validated_path.to_string(), book_id.clone());
    }

    let chapter = ChapterRepository::find_by_index(&pool, &book_id, chapter_index)
        .await?
        .ok_or_else(|| AppError::ChapterExtractError { index: chapter_index, reason: "chapter not found in DB".into() })?;

    Ok((chapter.start_index as i32, chapter.end_index as i32))
}

/// 提取章节原始文本内容（仅 TXT；EPUB 走 provider 路径）。
#[allow(dead_code)]

/// 构造 Pages 变体，当页数 > 100 时记录警告（防止偶发大章节 FFI 序列化瓶颈）
fn chapter_content_pages(pages: Vec<PageContent>) -> ChapterContent {
    if pages.len() > 100 {
        tracing::warn!(
            "ChapterContent::Pages has {} pages (>100), potential FFI serialization bottleneck",
            pages.len()
        );
    }
    ChapterContent::Pages(pages)
}

/// 快速获取章节首段文本（仅读第一个 spine，不做分页）。
///
/// Dart 侧用于快速渲染第 0 页，全文和分页后台异步补齐。
/// EPUB: 只读第一个 spine 的 HTML → 截断为 8KB → html_to_plain_text → 再截断 2000 字符
/// TXT: 读文件前 2000 字符
pub(crate) async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<FirstSpineResult, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    let text = if format == BookFormat::Epub {
        let (start_idx, _) = get_chapter_bounds(&validated_path, chapter_index).await?;
        let path = validated_path.clone();
        let idx = chapter_index;
        let spine_start = start_idx;
        tokio::task::spawn_blocking(move || -> Result<String, AppError> {
            let mut epub =
                crate::parser::epub::unzip::EpubFile::open(&path)
                    .map_err(|e| AppError::ChapterExtractError { index: idx, reason: e.to_string().into() })?;
            let spine = epub.spine();
            let start = spine_start.max(0) as usize;
            if start >= spine.len() {
                return Ok(String::new());
            }

            let href = &spine[start];
            let html = epub
                .read_resource(href)
                .map_err(|e| AppError::ChapterExtractError { index: idx, reason: e.to_string().into() })?;

            // 截断 HTML 到 8KB 避免 html_to_plain_text 处理大文件
            let truncated: String = html.chars().take(8 * 1024).collect();
            let plain =
                crate::parser::epub::provider::html_to_plain_text(&truncated);
            // 只取前 2000 字符用作首屏
            Ok(plain.chars().take(2000).collect())
        })
        .await
        .map_err(|e| AppError::TaskPanic { task_name: "first_spine".into(), details: e.to_string().into() })??
    } else {
        // TXT/MD: 读前 2000 字符
        let content = tokio::fs::read_to_string(&validated_path)
            .await
            .map_err(|e| AppError::FileReadError { path: validated_path.into(), details: e.to_string().into() })?;
        content.chars().take(2000).collect()
    };

    Ok(FirstSpineResult { text })
}

/// 获取章节前 N 字符（惰性转换，只读取必要的 spine）。
///
/// EPUB: 只转换覆盖前 `max_chars` 字符的 spine item，其余保持未转换状态。
/// TXT/MD: 直接读取文件前 N 字符。
pub(crate) async fn get_chapter_partial(
    file_path: String,
    chapter_index: i32,
    max_chars: u64,
) -> Result<String, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    if matches!(format, BookFormat::Txt | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        if format == BookFormat::Txt {
            // provider's `content_length` and `read_text_range` operate on the
            // full file, so for chapter_index > 0 we must read from the
            // chapter's start offset, not from byte 0.
            let (cs, _ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            let chapter_start = cs.max(0) as u64;
            // max_chars 是字符数，但 read_text_range 用字节偏移。
            // UTF-8 CJK 最多 3 字节/字符，预读 limit*3 字节再取 limit 个字符。
            let read_end = (chapter_start + max_chars * 3).min(content_len);
            let content = provider.read_text_range(chapter_start, read_end)?;
            Ok(content.chars().take(max_chars as usize).collect())
        } else {
            // EPUB: provider is already spine-scoped via open_from_bounds.
            // Read up to limit*3 bytes from start, then truncate to limit chars.
            let read_end = (max_chars * 3).min(content_len);
            let content = provider.read_text_range(0, read_end)?;
            Ok(content.chars().take(max_chars as usize).collect())
        }
    } else {
        Err(AppError::UnsupportedFormat {
            format: format!("unsupported format for partial read: {:?}", format).into(),
        })
    }
}

/// 获取指定章节的原始文本内容。
///
/// 返回章节全文的字符串，适用于无需分页的场景。
pub(crate) async fn get_chapter(
    file_path: String,
    chapter_index: i32,
    config: Option<TypesetConfig>,
) -> Result<ChapterContent, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    // 支持分块格式走 Provider 路径
    if matches!(format, BookFormat::Txt | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();

        let text = if format == BookFormat::Epub {
            // EPUB provider is already scoped to the chapter's spine
            // bounds by `open_from_bounds`; `content_length` is the
            // total byte length across those spines.  Read from 0 so
            // we don't accidentally treat spine indices as byte offsets.
            provider.read_text_range(0, content_len)?
        } else {
            // TXT: chapter bounds are byte offsets in the file.
            let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            let start = cs.max(0) as u64;
            let end = (ce.max(0) as u64).min(content_len);
            provider.read_text_range(start, end)?
        };
        match config {
            Some(cfg) => {
                let cfg = cfg.validate_and_fix();
                let config_hash = cfg.config_hash();

                // 查缓存
                if let Some(pages) =
                    try_get_cached(&validated_path, chapter_index, None, config_hash).await
                {
                    return Ok(chapter_content_pages(pages));
                }

                let chapter_idx = chapter_index;
                let pages =
                    tokio::task::spawn_blocking(move || paginate_all(text, chapter_idx, cfg))
                        .await
                        .map_err(|e| AppError::TaskPanic { task_name: "pagination".into(), details: e.to_string().into() })?;

                // 写缓存
                try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone())
                    .await;

                Ok(chapter_content_pages(pages))
            }
            None => Ok(ChapterContent::Raw(text)),
        }
    } else {
        Err(AppError::UnsupportedFormat {
            format: format!("unsupported format for chapter read: {:?}", format).into(),
        })
    }
}
