//! 分页 API（`paginate_chapter` / `paginate_all_content` / `get_page_content`）。
//!
//! Phase 2 实施：迁自 `api/core.rs` 的分页 + layout cache + provider cache 相关代码。

use std::time::Instant;

use crate::domain::{AppError, PageContent, PaginateResult, TypesetConfig};
use crate::storage::models::BookFormat;
use crate::text::{paginate_all, PageStreamer};
use crate::utils::security::validate_file_path;

use super::chapter_access::{extract_chapter_content, format_from_file_path, get_chapter_bounds};
use super::layout_cache::{try_get_cached, try_save_cached};
use super::provider_cache::get_or_create_provider;
use super::streamer_cache::STREAMER_CACHE;

/// 分页排版指定文件的所有章节。
///
/// 返回完整的分页结果，适用于全量排版场景。
pub(crate) async fn paginate_all_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<PageContent>, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();

    // 查缓存
    if let Some(pages) = try_get_cached(&validated_path, chapter_index, None, config_hash).await {
        return Ok(pages);
    }

    // 优先使用 Provider LRU 路径（与 getChapter 共享解析器缓存，避免重复 I/O）
    let format = format_from_file_path(&validated_path)?;
    let content = if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        let (start, end) = if format == BookFormat::Epub {
            (0u64, content_len)
        } else {
            let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
        };
        provider.read_text_range(start, end)?
    } else {
        extract_chapter_content(&validated_path, chapter_index).await?
    };

    let chapter_idx = chapter_index;
    let pages = tokio::task::spawn_blocking(move || paginate_all(content, chapter_idx, config))
        .await
        .map_err(|e| AppError::TaskPanic { task_name: "pagination".into(), details: e.to_string().into() })?;

    try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone()).await;

    Ok(pages)
}

/// 轻量级分页排版（只获取页面描述符，文本按需加载）。
///
/// 创建 `PageStreamer` 并缓存到 LRU 缓存中，Dart 侧通过 `get_page_content` 按需获取页面内容。
/// 如果指定 `max_chars`，只读取前 N 字符进行分页（惰性转换，只转换必要的 spine），
/// 用于初始快速分页。不指定则读取全文。
/// 与 `paginate_all_content` 相比，显著减少 FFI 数据量（只传偏移量，不传文本）。
pub(crate) async fn paginate_chapter(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let start = Instant::now();

    // 提取章节文本（只读取必要的 spine，惰性转换）
    let format = format_from_file_path(&validated_path)?;
    let (content, is_partial) = if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        // 短路：如果 max_chars >= 全文长度，降级为完整分页（避免不完整结果）
        let effective_max = match max_chars {
            Some(limit) if limit >= content_len => None,
            x => x,
        };
        match effective_max {
            Some(limit) => {
                if matches!(format, BookFormat::Txt | BookFormat::Md) {
                    // max_chars 是字符数，但 read_text_range 用字节偏移。
                    // UTF-8 CJK 最多 3 字节/字符，预读 limit*3 字节再取 limit 个字符。
                    let read_end = (limit * 3).min(content_len);
                    let content = provider.read_text_range(0, read_end)?;
                    let partial: String = content.chars().take(limit as usize).collect();
                    (partial, true)
                } else {
                    // EPUB: same char-take logic as TXT/MD.
                    // read_text_range uses byte offsets; pre-read limit*3
                    // bytes then truncate to limit chars (CJK safety).
                    let read_end = (limit * 3).min(content_len);
                    let content = provider.read_text_range(0, read_end)?;
                    let partial: String = content.chars().take(limit as usize).collect();
                    (partial, true)
                }
            }
            None => {
                let (start, end) = if matches!(format, BookFormat::Epub) {
                    // EPUB provider is already scoped to the chapter's spine
                    // bounds by `open_from_bounds`; `content_length` is the
                    // total byte length across those spines.  Read from 0 so
                    // we don't accidentally treat spine indices as byte offsets.
                    (0u64, content_len)
                } else {
                    // TXT/MD: chapter bounds are byte offsets in the file.
                    let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
                    (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
                };
                (provider.read_text_range(start, end)?, false)
            }
        }
    } else {
        (extract_chapter_content(&validated_path, chapter_index).await?, false)
    };

    // 全章分页 KV 缓存命中路径：跳过 CPU 排版直接复用
    if max_chars.is_none() {
        if let Some(pages) = try_get_cached(&validated_path, chapter_index, None, config_hash).await {
            let streamer = PageStreamer::from_pages(pages);
            let descriptors = streamer.get_descriptors();
            STREAMER_CACHE.lock().put((validated_path, chapter_index, config_hash), streamer);
            tracing::info!(
                "[Timing] paginate_chapter cache=HIT config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(PaginateResult {
                descriptors,
                config_hash,
                is_partial: false,
            });
        }
    }

    let mut streamer = PageStreamer::new(content, config);
    streamer.is_partial = is_partial;
    let descriptors = streamer.get_descriptors();

    // 提取全页内容用于 KV 缓存保存（在 streamer 移入 STREAMER_CACHE 之前完成）
    let cached_pages = if !is_partial {
        let total = descriptors.len();
        Some(
            (0..total)
                .filter_map(|i| streamer.get_page(i, chapter_index))
                .collect::<Vec<PageContent>>(),
        )
    } else {
        None
    };

    // 缓存 PageStreamer 供后续按需获取页面内容
    {
        let mut cache = STREAMER_CACHE.lock();
        cache.put((validated_path.clone(), chapter_index, config_hash), streamer);
    }

    // 全章分页完成后写入持久化 KV 缓存
    if let Some(pages) = cached_pages {
        try_save_cached(&validated_path, chapter_index, None, config_hash, pages).await;
    }

    tracing::info!(
        "[Timing] paginate_chapter cache=MISS config_hash={:016x} chapter={} elapsed={:?}",
        config_hash, chapter_index, start.elapsed()
    );
    Ok(PaginateResult {
        descriptors,
        config_hash,
        is_partial,
    })
}

/// 按需获取单页内容（同步，纯内存操作）。
///
/// 从 LRU 缓存中查找对应章节的 `PageStreamer`，调用 `get_page` 获取指定页的文本内容。
/// 如果缓存中不存在（过期或被驱逐），返回空字符串，调用方应回退到 `paginate_all_content`。
pub(crate) fn get_page_content(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> String {
    let key = (file_path, chapter_index, config_hash);
    let mut cache = STREAMER_CACHE.lock();
    if let Some(streamer) = cache.get(&key) {
        if let Some(page) = streamer.get_page(page_index as usize, chapter_index) {
            return page.content;
        }
    }
    String::new()
}
