// ============================================================
// 文件作用：块分页描述符（BlockPaginator 输出）
//
// 公有类型/函数：
//   - enum ImageBlockLayout — 页内 Image 块排版方式
//   - struct PageImageLayout — 某一 Image 块在本页的 layout 元数据
//   - struct BlockPageDescriptor — 块分页页面描述符
//   - struct BlockPaginateResult — 块分页结果
//   - struct PageTextBlockSlice — 页内 Text 块切片
//   - struct PageImageBlockSlice — 页内 Image 块切片
//   - enum PageBlockSlice — 单页块列表项
// ============================================================

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use super::content_ir::{BlockPlainRange, TextBlockStyle};
use super::rich_text::RichTextSpan;

/// 页内 Image 块的排版方式（ADR-003）。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
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
    pub fn new(descriptors: Vec<BlockPageDescriptor>, config_hash: u64, is_partial: bool) -> Self {
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

    /// 合并另一个 chunk 的 [BlockPaginateResult]。
    /// 追加 descriptors 并调整 `page_index` 偏移。
    /// 调用方需在 merge 前通过 [offset_block_indices] 将 chunk-relative
    /// 的 `first_block_index`/`last_block_index`/`image_layouts[].block_index`
    /// 转换为全章绝对索引。
    pub fn merge(&mut self, other: BlockPaginateResult) {
        let offset = self.page_count() as i32;
        for mut desc in other.descriptors {
            desc.page_index += offset;
            self.descriptors.push(desc);
        }
        self.is_partial = self.is_partial || other.is_partial;
    }

    /// 将 block 索引（`first_block_index`、`last_block_index`、`image_layouts[].block_index`）
    /// 统一增加 `offset`，用于 chunked pagination 合并。
    pub fn offset_block_indices(&mut self, offset: u32) {
        for desc in &mut self.descriptors {
            desc.first_block_index += offset;
            desc.last_block_index += offset;
            for layout in &mut desc.image_layouts {
                layout.block_index += offset;
            }
        }
    }
}

/// 页内 Text 块切片（相对页 plain 范围裁剪后的 UTF-8 文本）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageTextBlockSlice {
    pub block_index: u32,
    pub text: String,
    /// 本切片是否为 IR Text 块的开头（跨页续排时为 false）。
    pub is_block_start: bool,
    /// 本切片是否为 IR Text 块的末尾（跨页续排时为 false）。
    pub is_block_end: bool,
    /// 源 IR 块样式（ADR-010）。
    pub style: TextBlockStyle,
    /// 页内行内格式段（ADR-010）；空 → 按 [text] plain 渲染。
    pub spans: Vec<RichTextSpan>,
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
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
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
        let d = BlockPageDescriptor::new(0, 1, 4, BlockPlainRange::new(10, 20), false);
        assert_eq!(d.block_count(), 3);
        assert!(d.contains_block(1));
        assert!(d.contains_block(3));
        assert!(!d.contains_block(0));
        assert!(!d.contains_block(4));
    }

    #[test]
    fn plain_end_exclusive() {
        let d = BlockPageDescriptor::new(2, 0, 1, BlockPlainRange::new(5, 3), true);
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
    fn page_index_at_char_offset_finds_page() {
        let d0 = BlockPageDescriptor::new(0, 0, 1, BlockPlainRange::new(0, 10), false);
        let d1 = BlockPageDescriptor::new(1, 1, 2, BlockPlainRange::new(10, 5), true);
        let result = BlockPaginateResult::new(vec![d0, d1], 0, false);
        assert_eq!(result.page_index_at_char_offset(0), Some(0));
        assert_eq!(result.page_index_at_char_offset(9), Some(0));
        assert_eq!(result.page_index_at_char_offset(10), Some(1));
        assert_eq!(result.page_index_at_char_offset(15), Some(1));
    }

    #[test]
    fn offset_block_indices_shifts_all_references() {
        let d = BlockPageDescriptor::new(0, 3, 7, BlockPlainRange::new(0, 10), false)
            .with_image_layouts(vec![PageImageLayout {
                block_index: 5,
                layout: ImageBlockLayout::InlineContain,
            }]);
        let mut result = BlockPaginateResult::new(vec![d], 0, false);

        result.offset_block_indices(200);

        let desc = &result.descriptors[0];
        assert_eq!(desc.first_block_index, 203);
        assert_eq!(desc.last_block_index, 207);
        assert_eq!(desc.image_layouts[0].block_index, 205);
        // plain ranges must NOT be offset
        assert_eq!(desc.plain.plain_start, 0);
        assert_eq!(desc.plain.plain_len, 10);
    }
}
