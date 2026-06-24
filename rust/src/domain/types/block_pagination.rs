//! 块分页描述符（Phase 2 `BlockPaginator` 输出）
//!
//! 与 Phase 1 [`PageDescriptor`]（plain 行切）并存；M3 接入 session 前不替换现有 FFI。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use super::content_ir::BlockPlainRange;

/// 页内 Image 块的排版方式（ADR-003）。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb]
pub enum ImageBlockLayout {
    /// 剩余页高足够：缩放 contain，与文本同页。
    InlineContain,
    /// 放不下：独占一页（全屏 contain）。
    FullPage,
}

/// 某一 Image 块在本页的 layout 元数据。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct PageImageLayout {
    /// 对应 `ChapterContentIr.blocks` 的下标。
    pub block_index: u32,
    pub layout: ImageBlockLayout,
}

/// 块分页页面描述符（轻量；不含块正文/图片字节）。
///
/// - 块范围：`[first_block_index, last_block_index)` 半开区间。
/// - plain 范围：章级 Unicode 字符索引（与 ADR-001 / ADR-008 一致）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct BlockPageDescriptor {
    pub page_index: i32,
    pub first_block_index: u32,
    /// 不含尾（半开上界）。
    pub last_block_index: u32,
    pub plain: BlockPlainRange,
    pub is_last_page: bool,
    /// 本页 Image 块的 layout；纯文页为空。
    pub image_layouts: Vec<PageImageLayout>,
}

impl BlockPageDescriptor {
    pub fn new(
        page_index: i32,
        first_block_index: u32,
        last_block_index: u32,
        plain: BlockPlainRange,
        is_last_page: bool,
    ) -> Self {
        Self {
            page_index,
            first_block_index,
            last_block_index,
            plain,
            is_last_page,
            image_layouts: Vec::new(),
        }
    }

    pub fn with_image_layouts(mut self, layouts: Vec<PageImageLayout>) -> Self {
        self.image_layouts = layouts;
        self
    }

    pub fn block_count(&self) -> u32 {
        self.last_block_index.saturating_sub(self.first_block_index)
    }

    pub fn contains_block(&self, block_index: u32) -> bool {
        block_index >= self.first_block_index && block_index < self.last_block_index
    }

    /// plain 半开上界（字符索引）。
    pub fn plain_end_exclusive(&self) -> u32 {
        self.plain.end_exclusive()
    }

    /// 转为 Phase 1 [`super::pagination::PageDescriptor`]（过渡用；plain 字符索引写入 offset 字段）。
    ///
    /// M3 前仅用于桥接/测试；legacy 路径语义为字节 offset 时勿用于生产。
    pub fn to_legacy_page_descriptor(&self) -> super::pagination::PageDescriptor {
        super::pagination::PageDescriptor {
            page_index: self.page_index,
            start_offset: self.plain.plain_start as i32,
            end_offset: self.plain_end_exclusive() as i32,
            first_paragraph_index: self.first_block_index as i32,
            last_paragraph_index: self.last_block_index.saturating_sub(1) as i32,
            is_last_page: self.is_last_page,
        }
    }
}

/// 块分页结果（对标 [`super::pagination::PaginateResult`]）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct BlockPaginateResult {
    pub descriptors: Vec<BlockPageDescriptor>,
    pub config_hash: u64,
    pub is_partial: bool,
}

impl BlockPaginateResult {
    pub fn new(
        descriptors: Vec<BlockPageDescriptor>,
        config_hash: u64,
        is_partial: bool,
    ) -> Self {
        Self {
            descriptors,
            config_hash,
            is_partial,
        }
    }

    pub fn page_count(&self) -> usize {
        self.descriptors.len()
    }

    /// `charOffset`（章级 plain Unicode 索引）→ 页码；末页上界外返回最后一页。
    pub fn page_index_at_char_offset(&self, char_offset: u32) -> Option<i32> {
        for desc in &self.descriptors {
            if char_offset >= desc.plain.plain_start && char_offset < desc.plain_end_exclusive() {
                return Some(desc.page_index);
            }
        }
        self.descriptors
            .last()
            .filter(|d| d.is_last_page && char_offset == d.plain_end_exclusive())
            .map(|d| d.page_index)
    }

    pub fn to_legacy_paginate_result(&self, mode: super::pagination::ChapterPaginationMode) -> super::pagination::PaginateResult {
        super::pagination::PaginateResult {
            descriptors: self
                .descriptors
                .iter()
                .map(|d| d.to_legacy_page_descriptor())
                .collect(),
            config_hash: self.config_hash,
            is_partial: self.is_partial,
            mode,
        }
    }
}

/// 页内 Text 块切片（相对页 plain 范围裁剪后的 UTF-8 文本）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageTextBlockSlice {
    pub block_index: u32,
    pub text: String,
    /// 本切片是否为 IR Text 块的末尾（跨页续排时为 false）。
    pub is_block_end: bool,
}

/// 页内 Image 块切片。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageImageBlockSlice {
    pub block_index: u32,
    pub asset_id: String,
    pub layout: ImageBlockLayout,
    pub alt: Option<String>,
}

/// 单页块列表项（M3.2 `get_page_blocks` 输出）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum PageBlockSlice {
    Text(PageTextBlockSlice),
    Image(PageImageBlockSlice),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn block_range_is_half_open() {
        let d = BlockPageDescriptor::new(
            0,
            1,
            4,
            BlockPlainRange::new(10, 20),
            false,
        );
        assert_eq!(d.block_count(), 3);
        assert!(d.contains_block(1));
        assert!(d.contains_block(3));
        assert!(!d.contains_block(0));
        assert!(!d.contains_block(4));
    }

    #[test]
    fn plain_end_exclusive() {
        let d = BlockPageDescriptor::new(
            2,
            0,
            1,
            BlockPlainRange::new(5, 3),
            true,
        );
        assert_eq!(d.plain_end_exclusive(), 8);
    }

    #[test]
    fn image_layouts_attach_to_descriptor() {
        let d = BlockPageDescriptor::new(0, 0, 2, BlockPlainRange::new(0, 10), false)
            .with_image_layouts(vec![PageImageLayout {
                block_index: 1,
                layout: ImageBlockLayout::FullPage,
            }]);
        assert_eq!(d.image_layouts.len(), 1);
        assert_eq!(d.image_layouts[0].layout, ImageBlockLayout::FullPage);
    }

    #[test]
    fn legacy_bridge_maps_plain_char_to_offset_fields() {
        let d = BlockPageDescriptor::new(0, 2, 5, BlockPlainRange::new(100, 50), true);
        let legacy = d.to_legacy_page_descriptor();
        assert_eq!(legacy.start_offset, 100);
        assert_eq!(legacy.end_offset, 150);
        assert_eq!(legacy.first_paragraph_index, 2);
        assert_eq!(legacy.last_paragraph_index, 4);
    }

    #[test]
    fn page_index_at_char_offset_finds_page() {
        let d0 = BlockPageDescriptor::new(0, 0, 1, BlockPlainRange::new(0, 10), false);
        let d1 = BlockPageDescriptor::new(1, 1, 2, BlockPlainRange::new(10, 5), true);
        let result = BlockPaginateResult::new(vec![d0, d1], 0, false);
        assert_eq!(result.page_index_at_char_offset(0), Some(0));
        assert_eq!(result.page_index_at_char_offset(9), Some(0));
        assert_eq!(result.page_index_at_char_offset(10), Some(1));
        assert_eq!(result.page_index_at_char_offset(15), Some(1));
    }
}
