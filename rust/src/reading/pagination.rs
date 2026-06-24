//! 分页 API（`paginate_chapter` / `paginate_all_content` / `get_page_content`）。
//!
//! Phase 2 实施：迁自 `api/core.rs` 的分页 + layout cache + provider cache 相关代码。

use std::time::Instant;

use crate::domain::{
    AppError, ChapterPaginationMode, PageBlockSlice, PageContent, PaginateResult, TypesetConfig,
};
use crate::storage::models::BookFormat;
use crate::text::{paginate_all, paginate_chapter_ir, PageStreamer};
use crate::utils::security::validate_file_path;

use super::block_state::BlockPaginationState;
use super::chapter_access::{format_from_file_path, get_chapter_bounds};
use super::chapter_ir::load_chapter_content_ir;
use super::layout_cache::{try_get_cached, try_save_cached};
use super::pagination_engine::PaginationEngine;
use super::pagination_store::{PaginationKey, PaginationStore};
use super::provider_cache::get_or_create_provider;

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
    let content = if matches!(format, BookFormat::Txt | BookFormat::Epub) {
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
        return Err(AppError::UnsupportedFormat {
            format: format!("unsupported format for pagination: {:?}", format).into(),
        });
    };

    let chapter_idx = chapter_index;
    let pages = tokio::task::spawn_blocking(move || paginate_all(content, chapter_idx, config))
        .await
        .map_err(|e| AppError::TaskPanic { task_name: "pagination".into(), details: e.to_string().into() })?;

    try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone()).await;

    Ok(pages)
}

/// 全章 + 含 Image 块时走 BlockPaginator；否则沿用 Phase 1 `PageStreamer`。
async fn try_paginate_chapter_blocks(
    validated_path: &str,
    chapter_index: i32,
    config: &TypesetConfig,
    max_chars: Option<u64>,
) -> Result<Option<PaginateResult>, AppError> {
    if max_chars.is_some() {
        return Ok(None);
    }

    let format = format_from_file_path(validated_path)?;
    if !matches!(format, BookFormat::Txt | BookFormat::Epub) {
        return Ok(None);
    }

    let config_hash = config.config_hash();
    let key = PaginationKey::new(validated_path, chapter_index, config_hash);
    let store = PaginationStore::global();

    if let Some(result) = store.try_block_full_hit(&key) {
        return Ok(Some(result));
    }

    let ir = load_chapter_content_ir(validated_path, chapter_index).await?;
    if ir.image_block_count() == 0 {
        return Ok(None);
    }

    let config = config.clone();
    let ir_for_paginate = ir.clone();
    let block_result =
        tokio::task::spawn_blocking(move || paginate_chapter_ir(&ir_for_paginate, config))
        .await
        .map_err(|e| AppError::TaskPanic {
            task_name: "block_paginate".into(),
            details: e.to_string().into(),
        })?;

    let state = BlockPaginationState::new(ir, block_result, false);
    let result = state.to_paginate_result(config_hash);
    store.put(key, PaginationEngine::Block(state));

    tracing::info!(
        "[Timing] paginate_chapter block_path config_hash={:016x} chapter={} pages={}",
        config_hash,
        chapter_index,
        result.descriptors.len()
    );

    Ok(Some(result))
}

/// 轻量级分页排版（只获取页面描述符，文本按需加载）。
///
/// 创建 `PageStreamer` 或 `BlockPaginationState` 并缓存；Dart 侧按需取页。
/// 如果指定 `max_chars`，只读取前 N 字符进行分页（惰性转换）。
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
    let store = PaginationStore::global();
    let engine_key = PaginationKey::new(&validated_path, chapter_index, config_hash);

    // 全章（max_chars=None）：含图章优先 block 路径，避免 stale plain streamer/layout 缓存抢先返回。
    if max_chars.is_none() {
        if let Some(result) =
            try_paginate_chapter_blocks(&validated_path, chapter_index, &config, None).await?
        {
            tracing::info!(
                "[Timing] paginate_chapter block_path config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(result);
        }

        if let Some(result) = store.try_plain_full_hit(&engine_key) {
            tracing::info!(
                "[Timing] paginate_chapter engine_cache=HIT config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(result);
        }
        if let Some(pages) = try_get_cached(&validated_path, chapter_index, None, config_hash).await {
            let mut streamer = PageStreamer::from_pages(pages);
            streamer.is_partial = false;
            let descriptors = streamer.get_descriptors();
            store.put(
                engine_key.clone(),
                PaginationEngine::Plain(streamer),
            );
            tracing::info!(
                "[Timing] paginate_chapter layout_cache=HIT config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(PaginateResult {
                descriptors,
                config_hash,
                is_partial: false,
                mode: ChapterPaginationMode::PlainText,
            });
        }
    }

    // 提取章节文本（只读取必要的 spine，惰性转换）
    let format = format_from_file_path(&validated_path)?;
    let (content, is_partial) = if matches!(format, BookFormat::Txt | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        // 短路：如果 max_chars >= 全文长度，降级为完整分页（避免不完整结果）
        let effective_max = match max_chars {
            Some(limit) if limit >= content_len => None,
            x => x,
        };
        match effective_max {
            Some(limit) => {
                if format == BookFormat::Txt {
                    // TXT: chapter bounds are byte offsets in the file.
                    // The provider operates on the full file, so for
                    // chapter_index > 0 we must read from the chapter's
                    let (cs, _ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
                    let chapter_start = cs.max(0) as u64;
                    // max_chars 是字符数，但 read_text_range 用字节偏移。
                    // UTF-8 CJK 最多 3 字节/字符，预读 limit*3 字节再取 limit 个字符。
                    let read_end = (chapter_start + limit * 3).min(content_len);
                    let content = provider.read_text_range(chapter_start, read_end)?;
                    let partial: String = content.chars().take(limit as usize).collect();
                    (partial, true)
                } else {
                    // EPUB: provider is already spine-scoped via
                    // open_from_bounds.  Read up to limit*3 bytes from
                    // start, then truncate to limit chars (CJK safety).
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
                    // TXT: chapter bounds are byte offsets in the file.
                    let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
                    (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
                };
                (provider.read_text_range(start, end)?, false)
            }
         }
     } else {
         return Err(AppError::UnsupportedFormat {
             format: format!("unsupported format for pagination: {:?}", format).into(),
         });
     };

    let mut streamer = PageStreamer::new(content, config);
    streamer.is_partial = is_partial;
    let descriptors = streamer.get_descriptors();
    // 提取全页内容用于 KV 缓存保存（在 engine 移入 LRU 之前完成）
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

    store.put(
        PaginationKey::new(&validated_path, chapter_index, config_hash),
        PaginationEngine::Plain(streamer),
    );

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
        mode: ChapterPaginationMode::PlainText,
    })
}

fn ensure_non_negative_page_index(page_index: i32) -> Result<(), AppError> {
    if page_index < 0 {
        return Err(AppError::InvalidInput {
            reason: format!("page_index must be non-negative, got {page_index}"),
        });
    }
    Ok(())
}

fn page_content_entity(chapter_index: i32, config_hash: u64, page_index: i32) -> String {
    format!(
        "page content for chapter {chapter_index} page {page_index} (config_hash={config_hash:016x})"
    )
}

/// 块路径单页块列表（对标 `get_session_page_blocks`）。
pub(crate) fn get_page_blocks(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<Vec<PageBlockSlice>, AppError> {
    ensure_non_negative_page_index(page_index)?;
    let validated_path = validate_file_path(&file_path)?;
    let key = PaginationKey::new(&validated_path, chapter_index, config_hash);
    PaginationStore::global().with_engine(&key, |engine| {
        match engine {
            PaginationEngine::Block(state) => state
                .page_blocks(page_index as usize)
                .ok_or_else(|| AppError::NotFound {
                    entity: page_content_entity(chapter_index, config_hash, page_index),
                }),
            PaginationEngine::Plain(_) => Err(AppError::InvalidInput {
                reason: "plain text pagination has no block slices".into(),
            }),
        }
    })
}

/// 章 IR 是否含 Image 块（staging 预加载分支用）。
pub(crate) async fn chapter_has_image_blocks(
    file_path: String,
    chapter_index: i32,
) -> Result<bool, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let ir = load_chapter_content_ir(&validated_path, chapter_index).await?;
    Ok(ir.image_block_count() > 0)
}

/// 按需获取单页内容（同步，纯内存操作）。
///
/// 从 `PAGINATION_ENGINE_CACHE` 查找引擎并按模式取页。
/// 缓存未命中或页码越界时返回 `NotFound`，调用方应回退到 `paginate_chapter`。
pub(crate) fn get_page_content(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<String, AppError> {
    ensure_non_negative_page_index(page_index)?;
    let validated_path = validate_file_path(&file_path)?;
    let key = PaginationKey::new(&validated_path, chapter_index, config_hash);
    PaginationStore::global().with_engine(&key, |engine| {
        match engine {
            PaginationEngine::Plain(streamer) => streamer
                .get_page(page_index as usize, chapter_index)
                .map(|p| p.content)
                .ok_or_else(|| AppError::NotFound {
                    entity: page_content_entity(chapter_index, config_hash, page_index),
                }),
            PaginationEngine::Block(state) => state
                .page_plain_text(page_index as usize)
                .ok_or_else(|| AppError::NotFound {
                    entity: page_content_entity(chapter_index, config_hash, page_index),
                }),
        }
    })
}
