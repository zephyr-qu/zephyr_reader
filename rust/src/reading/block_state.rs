//! 块分页 session 状态（IR + `BlockPaginateResult`）。

use std::collections::HashMap;

use crate::domain::{
    slice_by_char_range, slice_rich_spans, BlockPaginateResult, ChapterContentIr, ContentBlock,
    ImageBlockLayout, PageBlockSlice, PageContent, PageImageBlockSlice, PageTextBlockSlice,
    PaginateResult, TypesetConfig,
};

/// 块路径分页状态（session / `PAGINATION_ENGINE_CACHE` 持有）。
#[allow(dead_code)]
#[derive(Debug, Clone)]
pub(crate) struct BlockPaginationState {
    pub ir: ChapterContentIr,
    pub result: BlockPaginateResult,
    pub is_partial: bool,
    pub typeset_config: TypesetConfig,
}

#[allow(dead_code)]
impl BlockPaginationState {
    pub fn new(
        ir: ChapterContentIr,
        result: BlockPaginateResult,
        is_partial: bool,
        typeset_config: TypesetConfig,
    ) -> Self {
        Self {
            ir,
            result,
            is_partial,
            typeset_config: typeset_config.validate_and_fix(),
        }
    }

    pub fn to_paginate_result(&self, config_hash: u64) -> PaginateResult {
        self.result
            .to_legacy_paginate_result(crate::domain::ChapterPaginationMode::ContentBlocks)
            .into_with_config_hash(config_hash)
    }

    /// 页 plain 投影（含 `\uFFFC` 占位）。
    pub fn page_plain_text(&self, page_index: usize) -> Option<String> {
        let desc = self.result.descriptors.get(page_index)?;
        let text = slice_by_char_range(
            &self.ir.plain_text,
            desc.plain.plain_start,
            desc.plain.plain_len,
        );
        // Trace: log last 3 pages and first page for diagnosis
        let total = self.result.page_count();
        if page_index == 0 || page_index + 3 >= total {
            let preview: String = text.chars().take(60).collect();
            let preview = if text.chars().count() > 60 {
                format!("{preview}...")
            } else {
                preview
            };
            tracing::info!(
                "[Trace] page_plain_text p={page_index}/{total} plain=[{}..+{}] len={} preview=\"{preview}\"",
                desc.plain.plain_start,
                desc.plain.plain_len,
                text.len()
            );
        }
        Some(text)
    }

    /// P0: 将所有页面展开为 `Vec<PageContent>`（对标 `paginate_all_content` 的全量输出）。
    pub fn to_page_content_list(&self, chapter_index: i32) -> Vec<PageContent> {
        let total = self.result.page_count();
        (0..total)
            .filter_map(|i| {
                let desc = self.result.descriptors.get(i)?;
                self.page_plain_text(i).map(|content| PageContent {
                    chapter_index,
                    page_index: desc.page_index,
                    content,
                    is_last_page: desc.is_last_page,
                    start_offset: desc.plain.plain_start as i32,
                    end_offset: desc.plain_end_exclusive() as i32,
                    first_paragraph_index: desc.first_block_index as i32,
                    last_paragraph_index: desc.last_block_index.saturating_sub(1) as i32,
                })
            })
            .collect()
    }

    /// M3.2：页内块切片（Text 裁剪 + Image asset_id/layout）。
    pub fn page_blocks(&self, page_index: usize) -> Option<Vec<PageBlockSlice>> {
        let desc = self.result.descriptors.get(page_index)?;
        let total = self.result.page_count();
        let block_range = desc.first_block_index..desc.last_block_index;
        // Trace: log last 3 pages block info
        if page_index + 3 >= total {
            tracing::info!(
                "[Trace] page_blocks p={page_index}/{total} blocks={:?} ir_blocks={}",
                block_range,
                self.ir.blocks.len()
            );
        }
        let page_plain_start = desc.plain.plain_start;
        let page_plain_end = desc.plain_end_exclusive();

        let layout_map: HashMap<u32, ImageBlockLayout> = desc
            .image_layouts
            .iter()
            .map(|l| (l.block_index, l.layout))
            .collect();

        let mut slices = Vec::new();
        for bi in desc.first_block_index..desc.last_block_index {
            let block = self.ir.blocks.get(bi as usize)?;
            match block {
                ContentBlock::Text(t) => {
                    let block_start = t.plain.plain_start;
                    let block_end = t.plain.end_exclusive();
                    let slice_start = page_plain_start.max(block_start);
                    let slice_end = page_plain_end.min(block_end);
                    if slice_start >= slice_end {
                        continue;
                    }
                    let local_start = slice_start - block_start;
                    let local_len = slice_end - slice_start;
                    let text = slice_by_char_range(&t.text, local_start, local_len);
                    if text.is_empty() {
                        continue;
                    }
                    let spans = slice_rich_spans(&t.spans, local_start, local_len);
                    slices.push(PageBlockSlice::Text(PageTextBlockSlice {
                        block_index: bi,
                        text,
                        is_block_start: local_start == 0,
                        is_block_end: slice_end == block_end,
                        style: t.style.clone(),
                        spans,
                    }));
                }
                ContentBlock::Image(img) => {
                    let block_start = img.plain.plain_start;
                    let block_end = img.plain.end_exclusive();
                    if page_plain_start >= block_end || page_plain_end <= block_start {
                        continue;
                    }
                    let layout = layout_map
                        .get(&bi)
                        .copied()
                        .unwrap_or(ImageBlockLayout::InlineContain);
                    slices.push(PageBlockSlice::Image(PageImageBlockSlice {
                        block_index: bi,
                        asset_id: img.asset_id.clone(),
                        layout,
                        alt: img.alt.clone(),
                    }));
                }
            }
        }
        if page_index + 3 >= total {
            tracing::info!(
                "[Trace] page_blocks p={page_index}/{total} slices={} plain_len={}",
                slices.len(),
                desc.plain.plain_len
            );
        }
        Some(slices)
    }
}

trait PaginateResultPatch {
    fn into_with_config_hash(self, config_hash: u64) -> PaginateResult;
}

impl PaginateResultPatch for PaginateResult {
    fn into_with_config_hash(mut self, config_hash: u64) -> PaginateResult {
        self.config_hash = config_hash;
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{
        BlockJoinedPlainBuilder, BlockPageDescriptor, BlockPlainRange, ChapterContentIr,
        PageBlockSlice, PageImageBlockSlice, TextBlockStyle, TypesetConfig,
    };
    use crate::text::paginate_chapter_ir;

    fn sample_ir_with_image() -> ChapterContentIr {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello".into(), TextBlockStyle::default());
        b.push_image("img1".into(), None);
        b.push_text("World".into(), TextBlockStyle::default());
        b.finish()
    }

    #[test]
    fn page_blocks_returns_text_and_image_slices() {
        let ir = sample_ir_with_image();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config.clone());
        let state = BlockPaginationState::new(ir, result, false, config);

        let blocks = state.page_blocks(0).expect("page 0 blocks");
        assert!(!blocks.is_empty());
        assert!(blocks.iter().any(|s| matches!(
            s,
            PageBlockSlice::Image(PageImageBlockSlice { asset_id, .. })
                if asset_id == "img1"
        )));
    }

    #[test]
    fn page_blocks_filters_images_outside_page_plain_range() {
        let ir = sample_ir_with_image();
        let result = BlockPaginateResult::new(
            vec![BlockPageDescriptor::new(
                0,
                0,
                3,
                BlockPlainRange::new(0, 5),
                false,
            )],
            0,
            false,
        );
        let state = BlockPaginationState::new(ir, result, false, TypesetConfig::default());

        let blocks = state.page_blocks(0).expect("page 0 blocks");

        assert_eq!(blocks.len(), 1);
        assert!(matches!(
            &blocks[0],
            PageBlockSlice::Text(t) if t.text == "Hello"
        ));
    }

    #[test]
    fn page_blocks_marks_block_end_on_complete_text_slice() {
        let ir = sample_ir_with_image();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config.clone());
        let state = BlockPaginationState::new(ir, result, false, config);

        let blocks = state.page_blocks(0).expect("page 0 blocks");
        let text_slices: Vec<_> = blocks
            .iter()
            .filter_map(|s| match s {
                PageBlockSlice::Text(t) => Some(t),
                _ => None,
            })
            .collect();
        assert_eq!(text_slices.len(), 2);
        assert!(text_slices[0].is_block_end);
        assert!(text_slices[1].is_block_end);
    }

    #[test]
    fn page_blocks_continuation_slice_not_block_end() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("你好".repeat(200), TextBlockStyle::default());
        let ir = b.finish();
        let config = TypesetConfig {
            page_width: 400,
            page_height: 200,
            font_size: 16,
            line_spacing: 1.5,
            first_line_indent: 0,
            paragraph_spacing: 0.0,
            ..TypesetConfig::default()
        };
        let result = paginate_chapter_ir(&ir, config.clone());
        let page_count = result.page_count();
        assert!(
            page_count > 1,
            "expected multi-page split, got {page_count}"
        );
        let state = BlockPaginationState::new(ir, result, false, config);

        let page0 = state.page_blocks(0).expect("page 0");
        let page0_text_slices: Vec<_> = page0
            .iter()
            .filter_map(|s| match s {
                PageBlockSlice::Text(t) => Some(t),
                _ => None,
            })
            .collect();
        assert_eq!(
            page0_text_slices.len(),
            1,
            "a single Text block page range must render as one contiguous slice, not one slice per visual line"
        );
        let first = page0_text_slices[0];
        assert!(
            !first.is_block_end,
            "continuation slice must not be block end"
        );

        let last_page = state.page_blocks(page_count - 1).expect("last page");
        let last_text = last_page
            .iter()
            .filter_map(|s| match s {
                PageBlockSlice::Text(t) => Some(t),
                _ => None,
            })
            .last()
            .expect("last page text slice");
        assert!(last_text.is_block_end);
    }
}
