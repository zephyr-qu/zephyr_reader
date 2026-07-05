//! 分页 API（`paginate_chapter` / `get_page_content`）。
//!
//! Phase 2 实施：迁自 `api/core.rs` 的分页 + layout cache + provider cache 相关代码。
//!
//! P0: 所有章节（包括纯文本书）统一走 IR → BlockPaginator 路径。
//! PageStreamer 仅用于 `max_chars` partial 分页（首屏快速分页），不再作为全章主路径。

use std::time::Instant;

use crate::domain::{
    AppError, BlockPageDescriptor, BlockPaginateResult, ChapterContentIr,
    ChapterPaginationMode, PageBlockSlice, PaginateResult, TypesetConfig,
};
use crate::storage::models::BookFormat;
use crate::text::PageStreamer;
use crate::utils::security::validate_file_path;

use super::block_state::BlockPaginationState;
use super::chapter_access::{format_from_file_path, get_chapter_bounds};
use super::chapter_ir::load_chapter_content_ir;
use super::layout_cache::{try_get_block_cached, try_save_block_cached};
use super::pagination_store::PaginationEngine;
use super::pagination_store::{PaginationKey, PaginationStore};
use super::provider_cache::get_or_create_provider;

/// 全章 + 含 Image 块时走 BlockPaginator；否则沿用 Phase 1 `PageStreamer`。

/// 保存块分页缓存（透明 chunking：超过阈值时按 chunk 保存，否则单条目）。
async fn save_block_caches_chunked(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
    ir: &ChapterContentIr,
    result: &BlockPaginateResult,
) {
    use crate::text::block_paginator::CHUNK_BLOCK_COUNT;
    if ir.blocks.len() > CHUNK_BLOCK_COUNT {
        // Per-chunk save for large chapters
        for (i, chunk) in ir.blocks.chunks(CHUNK_BLOCK_COUNT).enumerate() {
            let sub_ir = ChapterContentIr::new(chunk.to_vec(), ir.plain_text.clone());
            // Build per-chunk result: filter descriptors for this chunk's block range
            let block_start = (i * CHUNK_BLOCK_COUNT) as u32;
            let block_end = block_start + chunk.len() as u32;
            let chunk_descriptors: Vec<BlockPageDescriptor> = result
                .descriptors
                .iter()
                .filter(|d| d.first_block_index < block_end && d.last_block_index > block_start)
                .cloned()
                .collect();
            if !chunk_descriptors.is_empty() {
                let chunk_result = BlockPaginateResult::new(
                    chunk_descriptors,
                    config_hash,
                    result.is_partial,
                );
                try_save_block_cached(
                    validated_path,
                    chapter_index,
                    Some(i as u32),
                    config_hash,
                    sub_ir,
                    chunk_result,
                ).await;
            }
        }
    } else {
        // Single save for normal chapters
        try_save_block_cached(
            validated_path,
            chapter_index,
            None,
            config_hash,
            ir.clone(),
            result.clone(),
        ).await;
    }
}
async fn try_paginate_chapter_blocks(
    book_id: &str,
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
    let key = PaginationKey::new(book_id, chapter_index, config_hash);
    let store = PaginationStore::global();

    if let Some(result) = store.try_block_full_hit(&key) {
        return Ok(Some(result));
    }

    // Try chunked cache first (chunk_index=0 hit means all chunks should be cached)
    if let Some((ir0, block_result0)) =
        try_get_block_cached(validated_path, chapter_index, Some(0), config_hash).await
    {
        let mut merged_ir = ir0;
        let mut merged_result = block_result0;
        let mut next_chunk = 1u32;
        loop {
            if let Some((ir_n, block_result_n)) =
                try_get_block_cached(validated_path, chapter_index, Some(next_chunk), config_hash).await
            {
                merged_ir.blocks.extend(ir_n.blocks);
                merged_result.merge(block_result_n);
                next_chunk += 1;
            } else {
                break;
            }
        }
        let state = BlockPaginationState::new(merged_ir, merged_result.clone(), false);
        let result = state.to_paginate_result(config_hash);
        store.put(key, PaginationEngine::Block(state));
        tracing::info!(
            "[Timing] paginate_chapter block_path layout_cache=CHUNKED_HIT chunks={next_chunk} pages={}",
            merged_result.page_count()
        );
        return Ok(Some(result));
    }

    // Fallback: non-chunked cache (backward compatibility)
    if let Some((ir, block_result)) =
        try_get_block_cached(validated_path, chapter_index, None, config_hash).await
    {
        let state = BlockPaginationState::new(ir, block_result, false);
        let result = state.to_paginate_result(config_hash);
        store.put(key, PaginationEngine::Block(state));
        tracing::info!(
            "[Timing] paginate_chapter block_path layout_cache=HIT config_hash={:016x} chapter={} pages={}",
            config_hash,
            chapter_index,
            result.descriptors.len()
        );
        return Ok(Some(result));
    }

    // Cache miss: load IR and paginate (chunked if large)
    // P0: ALL chapters now go through block pagination, regardless of
    // image content. This eliminates the dual truth source (PageStreamer
    // vs BlockPaginator) — "分页引擎只认 IR" (TARGET_ARCHITECTURE §4).
    let ir = load_chapter_content_ir(validated_path, chapter_index).await?;

    let config = config.clone();
    let ir_for_paginate = ir.clone();
    let block_result = tokio::task::spawn_blocking(move || {
        // Use chunked paginator — transparently splits large chapters
        crate::text::block_paginator::paginate_chapter_ir_chunked(&ir_for_paginate, config)
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "block_paginate".into(),
        details: e.to_string(),
    })?;

    let state = BlockPaginationState::new(ir.clone(), block_result.clone(), false);
    let result = state.to_paginate_result(config_hash);
    store.put(key, PaginationEngine::Block(state));

    // Save caches: if blocks > CHUNK_BLOCK_COUNT, save per-chunk; else single
    save_block_caches_chunked(
        validated_path,
        chapter_index,
        config_hash,
        &ir,
        &block_result,
    ).await;

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
/// M2: `book_id` 用于 PaginationKey，`file_path` 用于文件操作（ADR-014）。
pub(crate) async fn paginate_chapter(
    book_id: &str,
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

    // 全章（max_chars=None）：P0 — 所有章节统一走 block 路径。
    // P1: plain sled 缓存已移除，不再有 fallback 到 PageStreamer 的路径。
    if max_chars.is_none()
        && let Some(result) =
            try_paginate_chapter_blocks(book_id, &validated_path, chapter_index, &config, None).await?
        {
            tracing::info!(
                "[Timing] paginate_chapter block_path config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(result);
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
             format: format!("unsupported format for pagination: {:?}", format),
         });
     };

    let mut streamer = PageStreamer::new(content, config);
    streamer.is_partial = is_partial;
    let descriptors = streamer.get_descriptors();

    store.put(
        PaginationKey::new(book_id, chapter_index, config_hash),
        PaginationEngine::Plain(streamer),
    );

    // P1: plain sled 缓存已移除。Partial 引擎不持久化到 sled（全章应走 block 路径）。

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
/// M2: `book_id` 替代 `file_path`（ADR-014）。
pub(crate) fn get_page_blocks(
    book_id: &str,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<Vec<PageBlockSlice>, AppError> {
    ensure_non_negative_page_index(page_index)?;
    let key = PaginationKey::new(book_id, chapter_index, config_hash);
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

/// 按需获取单页内容（同步，纯内存操作）。
///
/// 从 `PAGINATION_ENGINE_CACHE` 查找引擎并按模式取页。
/// 缓存未命中或页码越界时返回 `NotFound`，调用方应回退到 `paginate_chapter`。
/// M2: `book_id` 替代 `file_path`（ADR-014）。
pub(crate) fn get_page_content(
    book_id: &str,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<String, AppError> {
    ensure_non_negative_page_index(page_index)?;
    let key = PaginationKey::new(book_id, chapter_index, config_hash);
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
