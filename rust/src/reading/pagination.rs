//! 分页 API（`paginate_chapter` / `get_page_content`）。
//!
//! 所有章节统一走 IR → BlockPaginator 路径。

use std::time::Instant;

use crate::domain::types::content_ir::{BlockPlainRange, ContentBlock, TextBlock};
use crate::domain::{
    AppError, BlockPageDescriptor, BlockPaginateResult, ChapterContentIr, PageBlockSlice,
    PaginateResult, TypesetConfig,
};
use crate::storage::models::BookFormat;
use crate::utils::security::validate_file_path;

use super::block_state::BlockPaginationState;
use super::chapter_access::format_from_file_path;
use super::chapter_ir::load_chapter_content_ir;
use super::layout_cache::{try_get_block_cached, try_save_block_cached};
use super::pagination_store::PaginationEngine;
use super::orchestrator::LINE_BREAKS_STORE;
use super::pagination_store::{PaginationKey, PaginationStore};

/// 全章统一走 BlockPaginator。
///
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
                let chunk_result =
                    BlockPaginateResult::new(chunk_descriptors, config_hash, result.is_partial);
                try_save_block_cached(
                    validated_path,
                    chapter_index,
                    Some(i as u32),
                    config_hash,
                    sub_ir,
                    chunk_result,
                )
                .await;
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
        )
        .await;
    }
}
/// 截取 plain_text 中前 max_chars 个字符对应的 ContentBlock 集合。
/// 保留完整包含的块 + 截断最后一个跨越边界的 TextBlock（ImageBlock 不可截断）。
fn filter_blocks_to_chars(blocks: &[ContentBlock], max_chars: u64) -> Vec<ContentBlock> {
    let max_chars = max_chars as usize;
    let mut filtered = Vec::new();
    let mut had_truncation = false;

    for block in blocks {
        let start = block.plain_start() as usize;
        let len = block.plain_len() as usize;
        let end = start + len;

        if end <= max_chars {
            filtered.push(block.clone());
        } else if start < max_chars {
            // 跨越边界：仅截断 TextBlock（ImageBlock 不可截断，跳过）
            if let ContentBlock::Text(tb) = block {
                let truncated_len = (max_chars - start) as u32;
                let truncated_text: String = tb.text.chars().take(truncated_len as usize).collect();
                had_truncation = true;
                // 边界块丢弃 spans（首屏展示可接受；完整 IR 已缓存供 expand 使用）
                filtered.push(ContentBlock::Text(TextBlock {
                    plain: BlockPlainRange::new(tb.plain.plain_start, truncated_len),
                    text: truncated_text,
                    style: tb.style.clone(),
                    spans: Vec::new(),
                }));
            }
        }
        if end >= max_chars {
            break;
        }
    }
    tracing::info!(
        "[Trace] filter_blocks_to_chars in={} out={} max_chars={max_chars} truncated={had_truncation} last_plain_end={}",
        blocks.len(),
        filtered.len(),
        filtered
            .last()
            .map(|b| b.plain_start() + b.plain_len())
            .unwrap_or(0)
    );
    filtered
}

/// Phase 6: 从全局行断点缓存中取出预计算索引并注入 IR。
///
/// 如缓存中存在 `(book_id, chapter_index, config_hash)` 的索引，
/// 通过 `with_line_breaks()` 注入 IR，使 `paginate_chapter_ir`
/// 走精确的 `paginate_from_line_breaks` 路径（跳过贪心断行）。
fn inject_line_breaks(
    mut ir: ChapterContentIr,
    book_id: &str,
    chapter_index: i32,
    config_hash: u64,
) -> ChapterContentIr {
    if let Some(indices) = LINE_BREAKS_STORE
        .lock()
        .remove(&(book_id.to_string(), chapter_index, config_hash))
        && !indices.is_empty() {
            tracing::info!(
                "[LineBreaks] inject {} indices for ch={} hash={:016x}",
                indices.len(),
                chapter_index,
                config_hash,
            );
            ir.line_break_indices = Some(indices);
        }
    ir
}

async fn try_paginate_chapter_blocks(
    book_id: &str,
    validated_path: &str,
    chapter_index: i32,
    config: &TypesetConfig,
    max_chars: Option<u64>,
) -> Result<Option<PaginateResult>, AppError> {
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
                try_get_block_cached(validated_path, chapter_index, Some(next_chunk), config_hash)
                    .await
            {
                merged_ir.blocks.extend(ir_n.blocks);
                merged_result.merge(block_result_n);
                next_chunk += 1;
            } else {
                break;
            }
        }
        let state =
            BlockPaginationState::new(merged_ir, merged_result.clone(), false, config.clone());
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
        let state = BlockPaginationState::new(ir, block_result, false, config.clone());
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
    let full_ir = load_chapter_content_ir(validated_path, chapter_index).await?;

    // Phase 6: 注入 Flutter 预计算的行断点索引（如存在），
    // 使 paginate_chapter_ir 走精确的 paginate_from_line_breaks 路径
    let full_ir = inject_line_breaks(full_ir, book_id, chapter_index, config_hash);

    let config = config.clone();

    if let Some(chars) = max_chars {
        // Partial paginate: 截取前 N 字符对应的 blocks
        let ir_block_count = full_ir.blocks.len();
        let ir_plain_len = full_ir.plain_text.chars().count();
        let partial_blocks = filter_blocks_to_chars(&full_ir.blocks, chars);
        let partial_block_count = partial_blocks.len();
        let mut partial_ir = ChapterContentIr::new(partial_blocks, full_ir.plain_text.clone());
        // 保留落入 partial plain 范围的行断点，与全章 ICU 路径一致
        if let Some(ref indices) = full_ir.line_break_indices {
            let partial_end = partial_ir
                .blocks
                .last()
                .map(|b| b.plain_start() + b.plain_len())
                .unwrap_or(0);
            let filtered: Vec<u32> = indices
                .iter()
                .copied()
                .filter(|&i| i > 0 && i <= partial_end)
                .collect();
            if !filtered.is_empty() {
                partial_ir.line_break_indices = Some(filtered);
            }
        }
        let ir_for_paginate = partial_ir.clone();
        let config_for_paginate = config.clone();
        let partial_result = tokio::task::spawn_blocking(move || {
            crate::text::block_paginator::paginate_chapter_ir_chunked(
                &ir_for_paginate,
                config_for_paginate,
            )
        })
        .await
        .map_err(|e| AppError::TaskPanic {
            task_name: "block_paginate_partial".into(),
            details: e.to_string(),
        })?;

        // 存储完整 IR + partial result（expand 时用完整 IR 重新 paginate）
        let state =
            BlockPaginationState::new(full_ir, partial_result.clone(), true, config.clone());
        let result = state.to_paginate_result(config_hash);
        store.put(key, PaginationEngine::Block(state));

        tracing::info!(
            "[Timing] paginate_chapter block_path_partial config_hash={:016x} chapter={} pages={} max_chars={chars} ir_blocks={ir_block_count} partial_blocks={partial_block_count} ir_plain_len={ir_plain_len}",
            config_hash,
            chapter_index,
            result.descriptors.len()
        );
        return Ok(Some(result));
    }

    let ir_for_paginate = full_ir.clone();
    let config_for_paginate = config.clone();
    let block_result = tokio::task::spawn_blocking(move || {
        // Use chunked paginator — transparently splits large chapters
        crate::text::block_paginator::paginate_chapter_ir_chunked(
            &ir_for_paginate,
            config_for_paginate,
        )
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "block_paginate".into(),
        details: e.to_string(),
    })?;

    let state =
        BlockPaginationState::new(full_ir.clone(), block_result.clone(), false, config.clone());
    let result = state.to_paginate_result(config_hash);
    store.put(key, PaginationEngine::Block(state));

    // Save caches: if blocks > CHUNK_BLOCK_COUNT, save per-chunk; else single
    save_block_caches_chunked(
        validated_path,
        chapter_index,
        config_hash,
        &full_ir,
        &block_result,
    )
    .await;

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
/// 创建 `BlockPaginationState` 并缓存；Dart 侧按需取页。
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
    let _store = PaginationStore::global();

    // P0: ALL paths (full + partial) use block pagination.
    let result =
        try_paginate_chapter_blocks(book_id, &validated_path, chapter_index, &config, max_chars)
            .await?
            .ok_or_else(|| AppError::UnsupportedFormat {
                format: "unsupported format for pagination (only Txt/Epub supported)".into(),
            })?;

    tracing::info!(
        "[Timing] paginate_chapter block_path config_hash={:016x} chapter={} elapsed={:?}",
        config_hash,
        chapter_index,
        start.elapsed()
    );
    Ok(result)
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
    PaginationStore::global().with_engine(&key, |engine| match engine {
        PaginationEngine::Block(state) => {
            state
                .page_blocks(page_index as usize)
                .ok_or_else(|| AppError::NotFound {
                    entity: page_content_entity(chapter_index, config_hash, page_index),
                })
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
    PaginationStore::global().with_engine(&key, |engine| match engine {
        PaginationEngine::Block(state) => {
            state
                .page_plain_text(page_index as usize)
                .ok_or_else(|| AppError::NotFound {
                    entity: page_content_entity(chapter_index, config_hash, page_index),
                })
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        BlockJoinedPlainBuilder, ChapterContentIr, ChapterPaginationMode, ContentBlock,
        TextBlockStyle, TypesetConfig,
    };

    fn make_ir_with_n_blocks(n: usize) -> ChapterContentIr {
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..n {
            b.push_text(
                format!("Block {i}: {}", "X".repeat(200)),
                TextBlockStyle::default(),
            );
        }
        b.finish()
    }

    #[test]
    fn filter_blocks_to_chars_all_blocks_within_limit() {
        let ir = make_ir_with_n_blocks(3);
        // 3 blocks × ~210 chars each ≈ 630 chars, max_chars=5000 should include all
        let filtered = filter_blocks_to_chars(&ir.blocks, 5000);
        assert_eq!(filtered.len(), 3, "all blocks should fit within 5000 chars");
    }

    #[test]
    fn filter_blocks_to_chars_truncates_at_boundary() {
        let ir = make_ir_with_n_blocks(5);
        // first block ~210 chars, max_chars=300 → includes first block + truncated second block
        let filtered = filter_blocks_to_chars(&ir.blocks, 300);
        assert!(filtered.len() >= 1, "should include at least first block");
        assert!(
            filtered.len() <= 2,
            "should include at most first + truncated second"
        );

        // first block should be intact
        let first = &filtered[0];
        let first_len = first.plain_len() as usize;
        assert_eq!(first_len, ir.blocks[0].plain_len() as usize);
    }

    #[test]
    fn filter_blocks_to_chars_empty_on_zero() {
        let ir = make_ir_with_n_blocks(3);
        let filtered = filter_blocks_to_chars(&ir.blocks, 0);
        assert_eq!(filtered.len(), 0, "max_chars=0 should produce empty result");
    }

    #[test]
    fn filter_blocks_to_chars_preserves_block_count_at_exact_boundary() {
        let ir = make_ir_with_n_blocks(3);
        let first_block_end = ir.blocks[0].plain_start() + ir.blocks[0].plain_len();
        let filtered = filter_blocks_to_chars(&ir.blocks, first_block_end as u64);
        assert_eq!(
            filtered.len(),
            1,
            "exact boundary should include exactly first block"
        );
    }

    /// P0: partial pagination 应返回 contentBlocks 模式（非 plainText）。
    #[test]
    fn filter_blocks_to_chars_partial_has_fewer_blocks() {
        let ir = make_ir_with_n_blocks(10);
        let filtered = filter_blocks_to_chars(&ir.blocks, 1000);
        assert!(!filtered.is_empty());
        for block in &filtered {
            assert!(block.plain_len() > 0, "filtered block must have content");
        }
        assert!(
            filtered.len() < ir.blocks.len(),
            "partial should have fewer blocks than full"
        );
    }
}
