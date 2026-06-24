//! 块分页 session 状态（IR + `BlockPaginateResult`）。

use std::collections::HashMap;

use crate::domain::{
    BlockPaginateResult, ChapterContentIr, ChapterPaginationMode, ContentBlock,
    ImageBlockLayout, PageBlockSlice, PageImageBlockSlice, PageTextBlockSlice, PaginateResult,
    slice_by_char_range,
};

/// 块路径分页状态（session / `PAGINATION_ENGINE_CACHE` 持有）。
#[derive(Debug, Clone)]
pub(crate) struct BlockPaginationState {
    pub ir: ChapterContentIr,
    pub result: BlockPaginateResult,
    pub is_partial: bool,
}

impl BlockPaginationState {
    pub fn new(
        ir: ChapterContentIr,
        result: BlockPaginateResult,
        is_partial: bool,
    ) -> Self {
        Self {
            ir,
            result,
            is_partial,
        }
    }

    pub fn to_paginate_result(&self, config_hash: u64) -> PaginateResult {
        self.result
            .to_legacy_paginate_result(ChapterPaginationMode::ContentBlocks)
            .into_with_config_hash(config_hash)
    }

    /// 页 plain 投影（含 `\uFFFC` 占位）；对标 `PageStreamer::get_page` 文本字段。
    pub fn page_plain_text(&self, page_index: usize) -> Option<String> {
        let desc = self.result.descriptors.get(page_index)?;
        Some(slice_by_char_range(
            &self.ir.plain_text,
            desc.plain.plain_start,
            desc.plain.plain_len,
        ))
    }

    /// M3.2：页内块切片（Text 裁剪 + Image asset_id/layout）。
    pub fn page_blocks(&self, page_index: usize) -> Option<Vec<PageBlockSlice>> {
        let desc = self.result.descriptors.get(page_index)?;
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
                    if !text.is_empty() {
                        slices.push(PageBlockSlice::Text(PageTextBlockSlice {
                            block_index: bi,
                            text,
                        }));
                    }
                }
                ContentBlock::Image(img) => {
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
        Some(slices)
    }

    pub fn char_offset_to_page_index(&self, char_offset: u32) -> Option<i32> {
        self.result.page_index_at_char_offset(char_offset)
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
        BlockJoinedPlainBuilder, PageBlockSlice, PageImageBlockSlice, TextBlockStyle,
        TypesetConfig,
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
        let result = paginate_chapter_ir(&ir, config);
        let state = BlockPaginationState::new(ir, result, false);

        let blocks = state.page_blocks(0).expect("page 0 blocks");
        assert!(!blocks.is_empty());
        assert!(
            blocks.iter().any(|s| matches!(
                s,
                PageBlockSlice::Image(PageImageBlockSlice { asset_id, .. })
                    if asset_id == "img1"
            ))
        );
    }

    #[test]
    fn char_offset_maps_to_page() {
        let ir = sample_ir_with_image();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config);
        let state = BlockPaginationState::new(ir.clone(), result, false);

        assert_eq!(state.char_offset_to_page_index(0), Some(0));
        assert_eq!(
            state.char_offset_to_page_index(5),
            state.char_offset_to_page_index(6)
        );
    }

    #[test]
    fn page_plain_matches_descriptor_range() {
        let ir = sample_ir_with_image();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config);
        let state = BlockPaginationState::new(ir.clone(), result.clone(), false);

        for (i, desc) in result.descriptors.iter().enumerate() {
            let plain = state.page_plain_text(i).unwrap();
            assert_eq!(plain.chars().count() as u32, desc.plain.plain_len);
        }
    }
}
