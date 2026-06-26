//! Phase 2 块分页引擎（M2 `BlockPaginator`）
//!
//! 输入 `ChapterContentIr` + `TypesetConfig`，输出 [`BlockPaginateResult`]。
//! 文本断行复用 [`super::pagination::compute_line_breaks_from_indices`]。

use crate::domain::{
    BlockPageDescriptor, BlockPaginateResult, BlockPlainRange, ChapterContentIr, ContentBlock,
    ImageBlock, ImageBlockLayout, PageImageLayout, TextBlock, TextBlockStyle, TypesetConfig,
};
use crate::text::char_width::CharWidthTable;
use crate::text::pagination::compute_line_breaks_from_indices;

const SAFETY_MARGIN_PX: f32 = 2.0;
/// 无 intrinsic 尺寸时，图片显示高度 = page_width × ratio。
const DEFAULT_IMAGE_HEIGHT_RATIO: f32 = 0.55;

/// 排版度量（由 [`TypesetConfig`] 派生）。
struct BlockLayoutMetrics {
    font_size_px: f32,
    line_height_px: f32,
    page_height_px: f32,
    page_width_px: f32,
    max_line_width_px: f32,
    first_line_indent_width_px: f32,
    first_line_indent_chars: u8,
    paragraph_spacing_extra_px: f32,
    width_table: CharWidthTable,
    auto_space_px: f32,
    letter_spacing_px: f32,
    punctuation_squeeze: bool,
}

impl BlockLayoutMetrics {
    fn from_config(config: &TypesetConfig) -> Self {
        let font_size = config.font_size as f32;
        let page_width_px = config.page_width as f32;
        let page_height_px = config.page_height as f32;
        let line_height_px = (font_size * config.line_spacing).max(1.0);
        let effective_width = (page_width_px - SAFETY_MARGIN_PX).max(1.0);
        let first_line_indent_width_px = font_size * config.first_line_indent as f32;
        let max_line_width_px = (effective_width - first_line_indent_width_px).max(font_size);
        let paragraph_spacing_extra_px =
            (config.paragraph_spacing * font_size).max(0.0);

        Self {
            font_size_px: font_size,
            line_height_px,
            page_height_px,
            page_width_px,
            max_line_width_px,
            first_line_indent_width_px,
            first_line_indent_chars: config.first_line_indent,
            paragraph_spacing_extra_px,
            width_table: CharWidthTable::from_calibration(
                config.calibration.as_ref().unwrap_or(&Default::default()),
            ),
            auto_space_px: (font_size * config.auto_space_ratio).max(1.0),
            letter_spacing_px: config.letter_spacing,
            punctuation_squeeze: config.punctuation_squeeze,
        }
    }
}

/// 文本块内一条视觉行（Unicode 字符索引，相对块内 `text`）。
struct TextLineSegment {
    char_start: u32,
    char_len: u32,
}

fn char_index_at_byte(text: &str, byte: usize) -> u32 {
    text.char_indices()
        .take_while(|(b, _)| *b < byte)
        .count() as u32
}

/// 块级首行缩进（ADR-010）：IR 字段优先，否则 TypesetConfig。
fn effective_first_line_indent(
    style: &TextBlockStyle,
    metrics: &BlockLayoutMetrics,
) -> (bool, f32) {
    if style.is_heading {
        return (false, 0.0);
    }
    match style.text_indent_em {
        Some(em) if em <= 0.0 => (false, 0.0),
        Some(em) => (true, em * metrics.font_size_px),
        None if metrics.first_line_indent_chars > 0 => (
            true,
            metrics.first_line_indent_width_px,
        ),
        None => (false, 0.0),
    }
}

fn block_top_spacing_px(style: &TextBlockStyle, font_size_px: f32) -> f32 {
    style
        .margin_top_em
        .map(|em| em * font_size_px)
        .unwrap_or(0.0)
        .max(0.0)
}

fn block_bottom_spacing_px(style: &TextBlockStyle, metrics: &BlockLayoutMetrics) -> f32 {
    style
        .margin_bottom_em
        .map(|em| em * metrics.font_size_px)
        .unwrap_or(metrics.paragraph_spacing_extra_px)
        .max(0.0)
}

/// 将 Text 块拆成视觉行（含块内 `\n` 硬换行）。
fn layout_text_block_lines(
    text: &str,
    metrics: &BlockLayoutMetrics,
    style: &TextBlockStyle,
) -> Vec<TextLineSegment> {
    let (indent_first, indent_width_px) = effective_first_line_indent(style, metrics);
    let char_indices: Vec<(usize, char)> = text.char_indices().collect();
    let mut segments = Vec::new();
    let mut global_char = 0u32;

    for line_with_ending in text.split_inclusive('\n') {
        let line_char_len = line_with_ending.chars().count() as u32;
        let body = line_with_ending.trim_end_matches(['\r', '\n']);
        let body_char_len = body.chars().count() as u32;

        if body.is_empty() {
            if line_char_len > 0 {
                segments.push(TextLineSegment {
                    char_start: global_char,
                    char_len: line_char_len,
                });
            }
            global_char += line_char_len;
            continue;
        }

        let para_start_char = global_char;
        let para_start_byte = char_indices
            .get(para_start_char as usize)
            .map(|(b, _)| *b)
            .unwrap_or(0);
        let end_char = para_start_char + body_char_len;
        let para_end_byte = if (end_char as usize) < char_indices.len() {
            char_indices[end_char as usize].0
        } else {
            text.len()
        };

        let start_idx = para_start_char as usize;
        let end_idx = (para_start_char + body_char_len) as usize;
        let para_indices = &char_indices[start_idx..end_idx.min(char_indices.len())];

        let is_first_line_in_block = segments.is_empty();
        let max_width = if is_first_line_in_block && indent_first {
            (metrics.max_line_width_px - indent_width_px)
                .max(metrics.width_table.char_width('A'))
        } else {
            metrics.max_line_width_px
        };

        let line_breaks = compute_line_breaks_from_indices(
            para_indices,
            para_start_byte,
            para_end_byte,
            max_width,
            &metrics.width_table,
            metrics.auto_space_px,
            metrics.letter_spacing_px,
            metrics.punctuation_squeeze,
        );

        for (rel_start, rel_end) in line_breaks {
            let abs_start = para_start_byte + rel_start;
            let abs_end = para_start_byte + rel_end;
            let char_start = char_index_at_byte(text, abs_start);
            let char_end = char_index_at_byte(text, abs_end);
            segments.push(TextLineSegment {
                char_start,
                char_len: char_end.saturating_sub(char_start),
            });
        }

        let newline_chars = line_char_len.saturating_sub(body_char_len);
        if newline_chars > 0 {
            segments.push(TextLineSegment {
                char_start: global_char + body_char_len,
                char_len: newline_chars,
            });
        }
        global_char += line_char_len;
    }

    segments
}

fn image_display_height(
    page_width_px: f32,
    intrinsic_width: Option<u32>,
    intrinsic_height: Option<u32>,
) -> f32 {
    match (intrinsic_width, intrinsic_height) {
        (Some(w), Some(h)) if w > 0 && h > 0 => {
            let scale = (page_width_px / w as f32).min(1.0);
            h as f32 * scale
        }
        _ => page_width_px * DEFAULT_IMAGE_HEIGHT_RATIO,
    }
}

struct CurrentPage {
    first_block: u32,
    last_block: u32,
    plain_start: u32,
    plain_end: u32,
    image_layouts: Vec<PageImageLayout>,
}

impl CurrentPage {
    fn is_empty(&self) -> bool {
        self.plain_end <= self.plain_start && self.image_layouts.is_empty()
    }
}

struct BlockPaginator {
    metrics: BlockLayoutMetrics,
    remaining_height: f32,
    pages: Vec<BlockPageDescriptor>,
    current: CurrentPage,
    page_index: i32,
}

impl BlockPaginator {
    fn new(metrics: BlockLayoutMetrics) -> Self {
        let page_height = metrics.page_height_px;
        Self {
            metrics,
            remaining_height: page_height,
            pages: Vec::new(),
            current: CurrentPage {
                first_block: 0,
                last_block: 0,
                plain_start: 0,
                plain_end: 0,
                image_layouts: Vec::new(),
            },
            page_index: 0,
        }
    }

    fn flush_page(&mut self, is_last: bool) {
        if self.current.is_empty() {
            return;
        }
        let plain_len = self.current.plain_end.saturating_sub(self.current.plain_start);
        let descriptor = BlockPageDescriptor::new(
            self.page_index,
            self.current.first_block,
            self.current.last_block,
            BlockPlainRange::new(self.current.plain_start, plain_len),
            is_last,
        )
        .with_image_layouts(std::mem::take(&mut self.current.image_layouts));
        self.pages.push(descriptor);
        self.page_index += 1;
        self.remaining_height = self.metrics.page_height_px;
        self.current = CurrentPage {
            first_block: 0,
            last_block: 0,
            plain_start: 0,
            plain_end: 0,
            image_layouts: Vec::new(),
        };
    }

    fn begin_block_on_page(&mut self, block_index: u32, plain_char_start: u32) {
        if self.current.is_empty() {
            self.current.first_block = block_index;
            self.current.plain_start = plain_char_start;
        }
        self.current.last_block = block_index + 1;
    }

    fn extend_plain_end(&mut self, plain_end: u32) {
        if plain_end > self.current.plain_end {
            self.current.plain_end = plain_end;
        }
    }

    fn paginate_text_block(&mut self, block_index: u32, block: &TextBlock) {
        let top_spacing = block_top_spacing_px(&block.style, self.metrics.font_size_px);
        if top_spacing > 0.0 {
            self.remaining_height = (self.remaining_height - top_spacing).max(0.0);
        }

        let lines = layout_text_block_lines(&block.text, &self.metrics, &block.style);
        let base_plain = block.plain.plain_start;
        let bottom_spacing = block_bottom_spacing_px(&block.style, &self.metrics);

        for (i, seg) in lines.iter().enumerate() {
            if self.remaining_height < self.metrics.line_height_px {
                self.flush_page(false);
            }

            let seg_plain_start = base_plain + seg.char_start;
            let seg_plain_end = base_plain + seg.char_start + seg.char_len;
            self.begin_block_on_page(block_index, seg_plain_start);
            self.extend_plain_end(seg_plain_end);
            self.remaining_height -= self.metrics.line_height_px;

            if i + 1 == lines.len() && bottom_spacing > 0.0 {
                self.remaining_height = (self.remaining_height - bottom_spacing).max(0.0);
            }
        }
    }

    fn paginate_image_block(&mut self, block_index: u32, block: &ImageBlock) {
        let height = image_display_height(
            self.metrics.page_width_px,
            block.intrinsic_width,
            block.intrinsic_height,
        );
        let plain_start = block.plain.plain_start;
        let plain_end = plain_start + block.plain.plain_len;

        if height <= self.remaining_height {
            self.begin_block_on_page(block_index, plain_start);
            self.extend_plain_end(plain_end);
            self.current.image_layouts.push(PageImageLayout {
                block_index,
                layout: ImageBlockLayout::InlineContain,
            });
            self.remaining_height -= height;
            return;
        }

        if !self.current.is_empty() {
            self.flush_page(false);
        }

        self.begin_block_on_page(block_index, plain_start);
        self.extend_plain_end(plain_end);
        self.current.image_layouts.push(PageImageLayout {
            block_index,
            layout: ImageBlockLayout::FullPage,
        });
        self.remaining_height = 0.0;
        self.flush_page(false);
    }

    fn finish(mut self) -> BlockPaginateResult {
        if !self.current.is_empty() {
            self.flush_page(true);
        } else if let Some(last) = self.pages.last_mut() {
            last.is_last_page = true;
        }

        if self.pages.is_empty() {
            self.pages.push(BlockPageDescriptor::new(
                0,
                0,
                0,
                BlockPlainRange::new(0, 0),
                true,
            ));
        } else {
            let last_idx = self.pages.len() - 1;
            for (i, page) in self.pages.iter_mut().enumerate() {
                page.is_last_page = i == last_idx;
            }
        }

        let config_hash = 0; // filled by caller
        BlockPaginateResult::new(self.pages, config_hash, false)
    }
}

/// 对章 IR 执行块分页。
pub fn paginate_chapter_ir(
    ir: &ChapterContentIr,
    config: TypesetConfig,
) -> BlockPaginateResult {
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let metrics = BlockLayoutMetrics::from_config(&config);
    let mut paginator = BlockPaginator::new(metrics);

    if ir.blocks.is_empty() {
        let mut result = paginator.finish();
        result.config_hash = config_hash;
        return result;
    }

    for (idx, block) in ir.blocks.iter().enumerate() {
        let block_index = idx as u32;
        match block {
            ContentBlock::Text(t) => paginator.paginate_text_block(block_index, t),
            ContentBlock::Image(img) => paginator.paginate_image_block(block_index, img),
        }
    }

    let mut result = paginator.finish();
    result.config_hash = config_hash;
    result
}

/// 块数阈值：超过此值时分 chunk 独立分页，避免单次 `BlockPaginator` O(pathological_size)。
pub const CHUNK_BLOCK_COUNT: usize = 200;

/// 分 chunk 块分页：将 `ir.blocks` 按 [CHUNK_BLOCK_COUNT] 拆分，
/// 每 chunk 独立分页后合并 page descriptors。
///
/// 每个 chunk 的 [BlockPaginateResult] 可独立存入 sled 缓存（`chunk_index`）。
/// chunks ≤ 1 时委托给 [`paginate_chapter_ir`] 零开销。
pub fn paginate_chapter_ir_chunked(
    ir: &ChapterContentIr,
    config: TypesetConfig,
) -> BlockPaginateResult {
    if ir.blocks.len() <= CHUNK_BLOCK_COUNT {
        return paginate_chapter_ir(ir, config);
    }

    let config_hash = config.config_hash();
    let mut merged = BlockPaginateResult::new(vec![], config_hash, false);

    for chunk in ir.blocks.chunks(CHUNK_BLOCK_COUNT) {
        let sub_ir = ChapterContentIr::new(chunk.to_vec(), ir.plain_text.clone());
        let result = paginate_chapter_ir(&sub_ir, config.clone());
        merged.merge(result);
    }

    merged
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{BlockJoinedPlainBuilder, PlainProjectionStyle, TextBlockStyle};

    fn test_config() -> TypesetConfig {
        TypesetConfig {
            page_width: 400,
            page_height: 200,
            font_size: 16,
            line_spacing: 1.5,
            first_line_indent: 0,
            paragraph_spacing: 0.0,
            ..TypesetConfig::default()
        }
    }

    fn long_text_ir(repeats: usize) -> ChapterContentIr {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("你好".repeat(repeats), TextBlockStyle::default());
        b.finish()
    }

    #[test]
    fn pure_text_splits_across_pages() {
        let ir = long_text_ir(200);
        ir.validate_plain(PlainProjectionStyle::BlockJoined).unwrap();

        let result = paginate_chapter_ir(&ir, test_config());
        assert!(result.page_count() > 1, "expected multiple pages, got {}", result.page_count());
        assert!(result.descriptors.iter().all(|d| d.block_count() >= 1));
    }

    #[test]
    fn paragraph_spacing_increases_page_count() {
        let ir = long_text_ir(80);
        let mut config_no = test_config();
        config_no.paragraph_spacing = 0.0;
        let mut config_yes = test_config();
        config_yes.paragraph_spacing = 1.0;

        let result_no = paginate_chapter_ir(&ir, config_no);
        let result_yes = paginate_chapter_ir(&ir, config_yes);
        assert!(
            result_yes.page_count() >= result_no.page_count(),
            "paragraph_spacing should not reduce page count"
        );
    }

    #[test]
    fn small_image_inline_with_text() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello".into(), TextBlockStyle::default());
        b.push_image("img".into(), None);
        let mut ir = b.finish();
        if let ContentBlock::Image(img) = &mut ir.blocks[1] {
            *img = img.clone().with_intrinsic_size(Some(200), Some(100));
        }

        let result = paginate_chapter_ir(&ir, test_config());
        let inline_page = result.descriptors.iter().find(|d| {
            d.image_layouts
                .iter()
                .any(|l| l.layout == ImageBlockLayout::InlineContain)
        });
        assert!(inline_page.is_some(), "small image should fit inline");
    }

    #[test]
    fn large_image_gets_full_page() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Before".into(), TextBlockStyle::default());
        b.push_image("big".into(), None);
        let mut ir = b.finish();
        if let ContentBlock::Image(img) = &mut ir.blocks[1] {
            *img = img.clone().with_intrinsic_size(Some(400), Some(800));
        }

        let result = paginate_chapter_ir(&ir, test_config());
        let full = result.descriptors.iter().any(|d| {
            d.image_layouts
                .iter()
                .any(|l| l.layout == ImageBlockLayout::FullPage)
        });
        assert!(full, "tall image should use FullPage layout");
    }

    #[test]
    fn descriptors_cover_plain_monotonically() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Line one".into(), TextBlockStyle::default());
        b.push_text("Line two with more chars".into(), TextBlockStyle::default());
        let ir = b.finish();

        let result = paginate_chapter_ir(&ir, test_config());
        let mut prev_end = 0u32;
        for d in &result.descriptors {
            assert!(d.plain.plain_start >= prev_end.saturating_sub(1));
            prev_end = d.plain_end_exclusive();
        }
    }

    // === Chunked pagination tests ===

    #[test]
    fn chunked_small_chapter_delegates_to_plain() {
        // Chapter with ≤ CHUNK_BLOCK_COUNT blocks → identical to non-chunked
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..10 {
            b.push_text(format!("Block {i} text here."), TextBlockStyle::default());
        }
        let ir = b.finish();
        assert!(ir.block_count() <= CHUNK_BLOCK_COUNT);

        let plain = paginate_chapter_ir(&ir, test_config());
        let chunked = paginate_chapter_ir_chunked(&ir, test_config());

        assert_eq!(plain.page_count(), chunked.page_count());
        assert_eq!(plain.descriptors, chunked.descriptors);
    }

    #[test]
    fn chunked_large_chapter_produces_valid_descriptors() {
        // Large chapter (>200 blocks) — should chunk and merge
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..(CHUNK_BLOCK_COUNT + 50) {
            b.push_text(format!("Block {i}: some text to paginate."), TextBlockStyle::default());
        }
        let ir = b.finish();
        assert!(ir.block_count() > CHUNK_BLOCK_COUNT);

        let result = paginate_chapter_ir_chunked(&ir, test_config());
        assert!(result.page_count() > 1, "expected {} pages, got {}", result.page_count(), result.page_count());

        // Verify monotonic plain ranges across all descriptors
        let mut prev_end = 0u32;
        for d in &result.descriptors {
            assert!(
                d.plain.plain_start >= prev_end.saturating_sub(1),
                "descriptor page={} plain_start={} < prev_end={}",
                d.page_index, d.plain.plain_start, prev_end
            );
            prev_end = d.plain_end_exclusive();
        }

        // Verify page_index is sequential
        for (i, d) in result.descriptors.iter().enumerate() {
            assert_eq!(d.page_index as usize, i, "page_index mismatch at descriptor {}", i);
        }
    }

    #[test]
    fn merge_preserves_page_continuity() {
        let mut a = BlockPaginateResult::new(vec![], 0x1234, false);
        let d0 = BlockPageDescriptor::new(0, 0, 1, BlockPlainRange::new(0, 100), false);
        let d1 = BlockPageDescriptor::new(1, 1, 2, BlockPlainRange::new(100, 80), false);
        let b = BlockPaginateResult::new(vec![d0, d1], 0x1234, false);
        a.merge(b);
        assert_eq!(a.page_count(), 2);
        assert_eq!(a.descriptors[0].page_index, 0);
        assert_eq!(a.descriptors[1].page_index, 1);

        let d2 = BlockPageDescriptor::new(0, 0, 2, BlockPlainRange::new(180, 50), false);
        let c = BlockPaginateResult::new(vec![d2], 0x1234, false);
        a.merge(c);
        assert_eq!(a.page_count(), 3);
        // Third page should have page_index shifted to 2
        assert_eq!(a.descriptors[2].page_index, 2);
        assert_eq!(a.descriptors[2].plain.plain_start, 180);
    }

    #[test]
    fn merge_partial_propagation() {
        let mut a = BlockPaginateResult::new(vec![], 0, false);
        let b = BlockPaginateResult::new(vec![], 0, true);
        a.merge(b);
        assert!(a.is_partial);

        let mut c = BlockPaginateResult::new(vec![], 0, true);
        let d = BlockPaginateResult::new(vec![], 0, false);
        c.merge(d);
        assert!(c.is_partial);
    }
}
