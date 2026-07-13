//! Phase 2 块分页引擎（M2 `BlockPaginator`）
//!
//! 输入 `ChapterContentIr` + `TypesetConfig`，输出 [`BlockPaginateResult`]。
//! 文本断行复用 [`super::line_breaking::compute_line_breaks_from_indices`]。
//!
//! # ADR-016 DEAD PATH
//!
//! 页装箱真理将迁至 Flutter（`explore/flutter-side-pagination`）。
//! **合入后删除或降为测试对照**；合并前勿再扩展装箱启发式 / 校准耦合。

use crate::domain::{
    BlockPageDescriptor, BlockPaginateResult, BlockPlainRange, ChapterContentIr, ContentBlock,
    ImageBlock, ImageBlockLayout, PageImageLayout, TextBlock, TextBlockStyle, TypesetConfig,
};
use crate::text::char_width::CharWidthTable;
use crate::text::line_breaking::compute_line_breaks_variable_width;

/// 断行字宽略放大：Rust 比 Flutter 略早换行，避免「少计行高 → 页末裁切」。
/// 与满行 [pageHeightLineBuffer] 一起构成永不溢出的双保险。
const FLUTTER_BREAK_CHAR_WIDTH_SCALE: f32 = 1.03;
/// 贪心兜底与主断行共用安全行宽（仅 fallback 路径；主路径已不再取 greedy）。
const GREEDY_LINE_WIDTH_RATIO: f32 = 1.0;
/// 无 calibration 时的默认有效行宽比。主断行已按 Flutter `maxWidth` 使用满页宽；
/// 此常量仅作校准缺省/诊断对齐（不再二次收窄 `full_line_width_px`）。
const DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO: f32 = 1.0;
/// 无 intrinsic 尺寸时，图片显示高度 = page_width × ratio。
const DEFAULT_IMAGE_HEIGHT_RATIO: f32 = 0.55;

fn calibration_line_height_px(config: &TypesetConfig, font_size: f32) -> f32 {
    let measured = config
        .calibration
        .as_ref()
        .map(|c| c.measured_line_height_px)
        .unwrap_or(0.0);
    if measured > 0.0 {
        measured
    } else {
        (font_size * config.line_spacing).max(1.0)
    }
}

/// 排版度量（由 [`TypesetConfig`] 派生）。
struct BlockLayoutMetrics {
    font_size_px: f32,
    line_height_px: f32,
    dpr: f32,
    page_height_px: f32,
    page_width_px: f32,
    /// 续行可用行宽（与 Flutter `constraints.maxWidth * dpr` 对齐，不含首行缩进）。
    full_line_width_px: f32,
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
        let dpr = config
            .calibration
            .as_ref()
            .map(|c| c.dpr)
            .unwrap_or(1.0)
            .max(0.1);
        let page_width_px = config.page_width as f32;
        let page_height_px = config.page_height as f32;
        let line_height_px = calibration_line_height_px(config, font_size);
        let effective_ratio = config
            .calibration
            .as_ref()
            .map(|c| c.effective_line_width_ratio)
            .unwrap_or(DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO)
            .clamp(0.85, 1.0);
        // Flutter SelectableText / TextPainter 使用满宽 constraints.maxWidth。
        // 再用 measured ratio（≈0.97）二次收窄会导致系统性少装（底空 ~2–4 行）。
        // ratio 仍记入日志与 config_hash，但不参与主断行行宽。
        let full_line_width_px = page_width_px.max(font_size);
        let first_line_indent_width_px = font_size * config.first_line_indent as f32;
        let paragraph_spacing_extra_px = (config.paragraph_spacing * font_size).max(0.0);
        // Flutter SelectableText 路径目前不插入中西文间距；若计入 auto_space，
        // 混排页会多断行 → 少装（真机常见 underfill + lineDelta≪0）。
        // auto_space_ratio 仍进 config_hash，待渲染侧对齐后再启用。
        let auto_space_px = 0.0;
        let _configured_auto_space = (font_size * config.auto_space_ratio).max(0.0);

        let est_lines = page_height_px / line_height_px;
        let ls = config.line_spacing;
        tracing::info!(
            "[PageEstimate] BlockLayoutMetrics page_h={:.0}px line_h={:.1}px font={:.0}px lsp={ls:.2} est_lines={est_lines:.1} page_w={:.0}px full_line_w={:.0}px calib_ratio={effective_ratio:.3} auto_space_cfg={_configured_auto_space:.1} auto_space_pack={auto_space_px:.1} break_scale={:.2} greedy_ratio={:.2}",
            page_height_px,
            line_height_px,
            font_size,
            page_width_px,
            full_line_width_px,
            FLUTTER_BREAK_CHAR_WIDTH_SCALE,
            GREEDY_LINE_WIDTH_RATIO,
        );

        Self {
            font_size_px: font_size,
            line_height_px,
            dpr,
            page_height_px,
            page_width_px,
            full_line_width_px,
            first_line_indent_width_px,
            first_line_indent_chars: config.first_line_indent,
            paragraph_spacing_extra_px,
            width_table: CharWidthTable::from_optional_calibration(
                config.calibration.as_ref(),
                font_size,
            ),
            auto_space_px,
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
        None if metrics.first_line_indent_chars > 0 => (true, metrics.first_line_indent_width_px),
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

fn block_bottom_spacing_px(
    style: &TextBlockStyle,
    font_size_px: f32,
    metrics: &BlockLayoutMetrics,
) -> f32 {
    style
        .margin_bottom_em
        .map(|em| em * font_size_px)
        .unwrap_or(metrics.paragraph_spacing_extra_px)
        .max(0.0)
}

fn heading_font_size_px(style: &TextBlockStyle, base_font_size_px: f32) -> Option<f32> {
    if !style.is_heading || style.heading_level == 0 {
        return None;
    }
    let multiplier = match style.heading_level {
        1 => 1.5,
        2 => 1.25,
        3 => 1.125,
        4 => 1.0,
        _ => 0.875,
    };
    Some(base_font_size_px * multiplier)
}

fn effective_font_size_px(style: &TextBlockStyle, metrics: &BlockLayoutMetrics) -> f32 {
    style
        .font_size
        .filter(|fs| *fs > 0.0)
        .map(|fs| fs * metrics.dpr)
        .or_else(|| heading_font_size_px(style, metrics.font_size_px))
        .unwrap_or(metrics.font_size_px)
}

/// 与 Flutter `page_blocks` slice 渲染一致：缩进仅在 `apply_block_start_indent` 时作用于首条视觉行。
fn layout_slice_text_lines(
    text: &str,
    apply_block_start_indent: bool,
    metrics: &BlockLayoutMetrics,
    style: &TextBlockStyle,
    width_table: &CharWidthTable,
    auto_space_px: f32,
    letter_spacing_px: f32,
) -> Vec<TextLineSegment> {
    let (indent_first, indent_width_px) = effective_first_line_indent(style, metrics);
    let char_indices: Vec<(usize, char)> = text.char_indices().collect();
    let mut segments = Vec::new();
    let mut global_char = 0u32;
    let mut is_first_visual_line = true;

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
            is_first_visual_line = false;
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

        let apply_indent = is_first_visual_line && apply_block_start_indent && indent_first;
        let break_table = width_table.scaled(FLUTTER_BREAK_CHAR_WIDTH_SCALE);
        let continuation_width = metrics.full_line_width_px;
        let first_line_width = if apply_indent {
            (continuation_width - indent_width_px).max(break_table.char_width('A'))
        } else {
            continuation_width
        };
        let first_for_break = if apply_indent {
            Some(first_line_width)
        } else {
            None
        };

        let line_breaks = compute_line_breaks_variable_width(
            para_indices,
            para_start_byte,
            para_end_byte,
            first_for_break,
            continuation_width,
            &break_table,
            auto_space_px,
            letter_spacing_px,
            metrics.punctuation_squeeze,
        );

        // 增量游标替代 char_index_at_byte O(N) 扫描：
        // para_indices 本身就是 byte→char 映射表，游标跨 breaks 单调递增
        let mut pi_cursor = 0usize;
        for (rel_start, rel_end) in line_breaks {
            let abs_start = para_start_byte + rel_start;
            let abs_end = para_start_byte + rel_end;
            while pi_cursor < para_indices.len() && para_indices[pi_cursor].0 < abs_start {
                pi_cursor += 1;
            }
            let char_start = para_start_char + pi_cursor as u32;
            let start_cursor = pi_cursor;
            while pi_cursor < para_indices.len() && para_indices[pi_cursor].0 < abs_end {
                pi_cursor += 1;
            }
            let char_len = pi_cursor.saturating_sub(start_cursor) as u32;
            if char_len > 0 {
                segments.push(TextLineSegment { char_start, char_len });
            }
        }

        let newline_chars = line_char_len.saturating_sub(body_char_len);
        if newline_chars > 0 {
            segments.push(TextLineSegment {
                char_start: global_char + body_char_len,
                char_len: newline_chars,
            });
        }
        global_char += line_char_len;
        is_first_visual_line = false;
    }

    segments
}

/// 将 Text 块拆成视觉行（含块内 `\n` 硬换行）。
fn layout_text_block_lines(
    text: &str,
    metrics: &BlockLayoutMetrics,
    style: &TextBlockStyle,
    width_table: &CharWidthTable,
    auto_space_px: f32,
    letter_spacing_px: f32,
) -> Vec<TextLineSegment> {
    layout_slice_text_lines(
        text,
        true,
        metrics,
        style,
        width_table,
        auto_space_px,
        letter_spacing_px,
    )
}

/// 按估算行宽贪心切分（layout 断行偏宽时的 Flutter 对齐兜底）。
///
/// TODO(ponytail): 贪心断行在极端场景（高标点密度 + 中西混排 + 标点挤压）下仍可能偏宽。
<<<<<<< Updated upstream
/// 若 `[LineBreak] overflow_dp` CI 门禁反复触发，评估引入 Knuth-Plass 简化版作为可选后端
/// （仅对超宽行启用，避免主路径性能退化）。必须以 benchmark 为前提。
///
/// NOTE: Phase 2 `line_break_indices` 缓存路径无需此函数。当前仅用于
/// 无预计算索引的旧数据。计划在 Phase 2 收尾时移除。
#[deprecated(since = "0.9.0", note = "Replaced by layout_slice_text_lines + line_break_indices mapping; kept temporarily for backward compat")]
fn greedy_split_text_lines(
    text: &str,
    apply_block_start_indent: bool,
    metrics: &BlockLayoutMetrics,
    style: &TextBlockStyle,
    width_table: &CharWidthTable,
) -> Vec<(u32, u32)> {
    let char_len = text.chars().count() as u32;
    if char_len == 0 {
        return Vec::new();
    }
    let break_table = width_table.scaled(FLUTTER_BREAK_CHAR_WIDTH_SCALE);
    let cjk_w = break_table.char_width('中').max(1.0);
    let full_line_chars = ((metrics.full_line_width_px * GREEDY_LINE_WIDTH_RATIO) / cjk_w)
        .floor()
        .max(1.0) as u32;
    let (indent_first, indent_width_px) = effective_first_line_indent(style, metrics);
    let first_line_chars = if apply_block_start_indent && indent_first {
        let narrow = (metrics.full_line_width_px - indent_width_px).max(cjk_w);
        ((narrow * GREEDY_LINE_WIDTH_RATIO) / cjk_w)
            .floor()
            .max(1.0) as u32
    } else {
        full_line_chars
    };

    let mut segments = Vec::new();
    let mut offset = 0u32;
    let mut is_first = true;
    while offset < char_len {
        let take = if is_first {
            first_line_chars.min(char_len - offset)
        } else {
            full_line_chars.min(char_len - offset)
        };
        segments.push((offset, take));
        offset += take;
        is_first = false;
    }
    segments
}

/// 按精确变宽断行切视觉行。不再与 greedy 取「更保守」结果——
/// greedy（纯 CJK 字数估算）在混排上会多断行，导致系统性少装。
fn visual_line_segments_for_slice(
    text: &str,
    apply_block_start_indent: bool,
    metrics: &BlockLayoutMetrics,
    style: &TextBlockStyle,
    width_table: &CharWidthTable,
    auto_space_px: f32,
    letter_spacing_px: f32,
) -> Vec<(u32, u32)> {
    let layout = layout_slice_text_lines(
        text,
        apply_block_start_indent,
        metrics,
        style,
        width_table,
        auto_space_px,
        letter_spacing_px,
    )
    .into_iter()
    .map(|s| (s.char_start, s.char_len))
    .collect::<Vec<_>>();
    if !layout.is_empty() {
        return layout;
    }
    // 精确断行为空时的兜底（空串/异常）；主路径不应依赖 greedy。
    #[allow(deprecated)]
    {
        greedy_split_text_lines(text, apply_block_start_indent, metrics, style, width_table)
    }
}

=======
>>>>>>> Stashed changes
/// 按 Flutter slice 语义切分（缩进仅 block 起点）；供 `page_blocks` 对页内裁剪文本再分行。
#[cfg(test)]
pub(crate) fn layout_slice_text_segments(
    text: &str,
    apply_block_start_indent: bool,
    config: &TypesetConfig,
    style: &TextBlockStyle,
) -> Vec<(u32, u32)> {
    if text.is_empty() {
        return Vec::new();
    }
    let metrics = BlockLayoutMetrics::from_config(config);
    let effective_font_size = effective_font_size_px(style, &metrics);
    let font_scale = if metrics.font_size_px > 0.0 {
        effective_font_size / metrics.font_size_px
    } else {
        1.0
    };
    let width_table = metrics.width_table.scaled(font_scale);
    let auto_space_px =
        (effective_font_size * metrics.auto_space_px / metrics.font_size_px.max(1.0)).max(1.0);
    layout_slice_text_lines(
        text,
        apply_block_start_indent,
        &metrics,
        style,
        &width_table,
        auto_space_px,
        metrics.letter_spacing_px,
    )
    .into_iter()
    .map(|s| (s.char_start, s.char_len))
    .collect()
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
    /// 上一段落结束后的段距：在下一块内容前消耗；`flush_page` 时丢弃（页末不留尾随空白）。
    pending_block_spacing_px: f32,
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
            pending_block_spacing_px: 0.0,
        }
    }

    fn flush_page(&mut self, is_last: bool) {
        if self.current.is_empty() {
            return;
        }
        let plain_len = self
            .current
            .plain_end
            .saturating_sub(self.current.plain_start);
        let consumed = self.metrics.page_height_px - self.remaining_height;
        let first_block = self.current.first_block;
        let last_block = self.current.last_block;
        tracing::info!(
            "!!!RUST!!! flush page={} plain={}..{} chars={} blocks={}..{} consumed={:.0}px remain={:.0}px page_h={:.0}px",
            self.page_index,
            self.current.plain_start,
            self.current.plain_end,
            plain_len,
            first_block,
            last_block.saturating_sub(1),
            consumed,
            self.remaining_height,
            self.metrics.page_height_px,
        );
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
        // 页末不保留段距尾随，避免与 Flutter「最后一块不加 spacing」不一致导致 overflow。
        self.pending_block_spacing_px = 0.0;
        self.current = CurrentPage {
            first_block: 0,
            last_block: 0,
            plain_start: 0,
            plain_end: 0,
            image_layouts: Vec::new(),
        };
    }

    /// 在下一块内容前消耗挂起的段距；当前页放不下则翻页并丢弃（不带到页顶）。
    fn apply_pending_spacing_before_content(&mut self) {
        let pending = self.pending_block_spacing_px;
        if pending <= 0.0 {
            return;
        }
        self.pending_block_spacing_px = 0.0;
        if self.current.is_empty() {
            return;
        }
        if self.remaining_height < pending {
            self.flush_page(false);
            return;
        }
        self.remaining_height -= pending;
    }

    fn queue_block_bottom_spacing(&mut self, spacing: f32) {
        self.pending_block_spacing_px = spacing.max(0.0);
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

    /// 当前页剩余高度不足时换页。
    fn ensure_vertical_space(&mut self, required_height: f32) {
        loop {
            if self.remaining_height >= required_height {
                return;
            }
            if self.current.is_empty() {
                return;
            }
            self.flush_page(false);
        }
    }

    fn paginate_text_block(&mut self, block_index: u32, block: &TextBlock) {
        // 行高由全局 calibration line_height 按字号比例缩放（ADR-015)
        let effective_font_size = effective_font_size_px(&block.style, &self.metrics);
        let height_ratio = effective_font_size / self.metrics.font_size_px.max(1.0);
        let effective_line_height = (self.metrics.line_height_px * height_ratio).max(1.0);
        let font_scale = if self.metrics.font_size_px > 0.0 {
            effective_font_size / self.metrics.font_size_px
        } else {
            1.0
        };
        let width_table = self.metrics.width_table.scaled(font_scale);
        let auto_space_px = (effective_font_size * self.metrics.auto_space_px
            / self.metrics.font_size_px.max(1.0))
        .max(1.0);

        self.apply_pending_spacing_before_content();

        let top_spacing = block_top_spacing_px(&block.style, effective_font_size);
        if top_spacing > 0.0 {
            self.ensure_vertical_space(top_spacing);
            self.remaining_height = (self.remaining_height - top_spacing).max(0.0);
        }

        let lines = layout_text_block_lines(
            &block.text,
            &self.metrics,
            &block.style,
            &width_table,
            auto_space_px,
            self.metrics.letter_spacing_px,
        );
        let base_plain = block.plain.plain_start;
        let bottom_spacing =
            block_bottom_spacing_px(&block.style, effective_font_size, &self.metrics);

        for seg in lines.iter() {
            let seg_text: String = block
                .text
                .chars()
                .skip(seg.char_start as usize)
                .take(seg.char_len as usize)
                .collect();
            let apply_block_start_indent = seg.char_start == 0;
            let visual_segments = layout_slice_text_lines(
                &seg_text,
                apply_block_start_indent,
                &self.metrics,
                &block.style,
                &width_table,
                auto_space_px,
                self.metrics.letter_spacing_px,
            )
            .into_iter()
            .map(|s| (s.char_start, s.char_len))
            .collect::<Vec<_>>();

            for (sub_start, sub_len) in visual_segments.iter() {
                let required_height = effective_line_height;
                self.ensure_vertical_space(required_height);

                let sub_plain_start = base_plain + seg.char_start + sub_start;
                let sub_plain_end = sub_plain_start + sub_len;
                self.begin_block_on_page(block_index, sub_plain_start);
                self.extend_plain_end(sub_plain_end);
                self.remaining_height -= effective_line_height;
            }
        }

        // 段距挂起：仅当页内还有后续块时才会被消耗；页末 flush 丢弃。
        self.queue_block_bottom_spacing(bottom_spacing);
    }

    fn paginate_image_block(&mut self, block_index: u32, block: &ImageBlock) {
        self.apply_pending_spacing_before_content();

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
///
/// 若 IR 含 [`line_break_indices`]，跳过断行计算，直接用预计算索引分页（纯数学映射）。
pub fn paginate_chapter_ir(ir: &ChapterContentIr, config: TypesetConfig) -> BlockPaginateResult {
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();

    // ── 缓存路径：有预计算行断点时，不跑贪心断行 ──
    if let Some(ref indices) = ir.line_break_indices
        && !indices.is_empty()
    {
        let metrics = BlockLayoutMetrics::from_config(&config);
        return paginate_from_line_breaks(indices, &ir.blocks, &metrics, config_hash);
    }

    // ── 原始路径：块级贪心分页 ──
    tracing::info!(
        "[PageEstimate] paginate_chapter_ir blocks={} config: w={} h={} font={} lsp={:.2} indent={}",
        ir.blocks.len(),
        config.page_width,
        config.page_height,
        config.font_size,
        config.line_spacing,
        config.first_line_indent,
    );
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

/// 在 `blocks` 中查找覆盖 `char_offset` 的块下标（半开 plain 区间）。
fn block_index_containing(blocks: &[ContentBlock], char_offset: u32) -> Option<usize> {
    blocks.iter().position(|b| {
        let start = b.plain_start();
        let end = start + b.plain_len();
        char_offset >= start && char_offset < end
    })
}

/// plain `[start, end)` 覆盖的块半开区间 `[first, last)`。
fn block_range_covering_plain(blocks: &[ContentBlock], start: u32, end: u32) -> (u32, u32) {
    let mut first: Option<u32> = None;
    let mut last_excl = 0u32;
    for (i, b) in blocks.iter().enumerate() {
        let bs = b.plain_start();
        let be = bs + b.plain_len();
        if be > start && bs < end {
            if first.is_none() {
                first = Some(i as u32);
            }
            last_excl = i as u32 + 1;
        }
    }
    match first {
        Some(f) => (f, last_excl.max(f + 1)),
        None => (0, 0),
    }
}

/// 将当前累计页写入 `pages`（与 [`BlockPaginator::flush_page`] 语义对齐）。
fn flush_line_break_page(
    pages: &mut Vec<BlockPageDescriptor>,
    page_idx: &mut i32,
    remaining: &mut f32,
    pending_spacing: &mut f32,
    page_plain_start: &mut Option<u32>,
    page_plain_end: &mut u32,
    page_image_layouts: &mut Vec<PageImageLayout>,
    blocks: &[ContentBlock],
    page_height_px: f32,
) {
    let Some(start) = *page_plain_start else {
        return;
    };
    let end = *page_plain_end;
    if end <= start && page_image_layouts.is_empty() {
        *page_plain_start = None;
        *page_plain_end = 0;
        page_image_layouts.clear();
        *remaining = page_height_px;
        *pending_spacing = 0.0;
        return;
    }
    let (mut first, mut last) = block_range_covering_plain(blocks, start, end);
    for layout in page_image_layouts.iter() {
        if last == 0 && first == 0 {
            first = layout.block_index;
            last = layout.block_index + 1;
        } else {
            first = first.min(layout.block_index);
            last = last.max(layout.block_index + 1);
        }
    }
    // 安全网：plain 有内容却未命中块时，避免写出 0..0 导致空页
    if last <= first && end > start && !blocks.is_empty() {
        first = 0;
        last = blocks.len() as u32;
    }
    let descriptor = BlockPageDescriptor::new(
        *page_idx,
        first,
        last,
        BlockPlainRange::new(start, end.saturating_sub(start)),
        false,
    )
    .with_image_layouts(std::mem::take(page_image_layouts));
    pages.push(descriptor);
    *page_idx += 1;
    *page_plain_start = None;
    *page_plain_end = 0;
    *remaining = page_height_px;
    *pending_spacing = 0.0;
}

/// 缓存路径：用 Flutter 预计算的行断点直接分页（零断行计算）。
///
/// `indices` 是每行结束字符在章级 plain 中的绝对位置。
///
/// **必须**写入真实的 `first_block_index..last_block_index`：`page_blocks` 按块半开
/// 区间切片；若写死 `0..1`，多段落后续页会变成空页/半页（根因）。
///
/// 高度按行装箱，并在块边界计入段距；图片块用 [`image_display_height`]。
fn paginate_from_line_breaks(
    indices: &[u32],
    blocks: &[ContentBlock],
    metrics: &BlockLayoutMetrics,
    config_hash: u64,
) -> BlockPaginateResult {
    if indices.is_empty() {
        return BlockPaginateResult::new(
            vec![BlockPageDescriptor::new(
                0,
                0,
                0,
                BlockPlainRange::new(0, 0),
                true,
            )],
            config_hash,
            false,
        );
    }

    tracing::info!(
        "[PageEstimate] paginate_from_line_breaks indices={} blocks={} page_h={:.0} line_h={:.1} para_sp={:.1}",
        indices.len(),
        blocks.len(),
        metrics.page_height_px,
        metrics.line_height_px,
        metrics.paragraph_spacing_extra_px,
    );

    let chapter_plain_start = blocks.first().map(|b| b.plain_start()).unwrap_or(0);
    let page_height = metrics.page_height_px;

    let mut pages: Vec<BlockPageDescriptor> = Vec::new();
    let mut page_idx = 0i32;
    let mut remaining = page_height;
    let mut pending_spacing = 0.0f32;
    let mut page_plain_start: Option<u32> = None;
    let mut page_plain_end: u32 = 0;
    let mut page_image_layouts: Vec<PageImageLayout> = Vec::new();
    let mut prev_line_end = chapter_plain_start;

    for &line_end in indices {
        if line_end <= prev_line_end {
            prev_line_end = line_end;
            continue;
        }
        let line_start = prev_line_end;

        let owner = block_index_containing(blocks, line_start);
        let Some(bi) = owner else {
            // plain 中间隔符（`\n`）：不计高度，只推进游标
            prev_line_end = line_end;
            if page_plain_start.is_some() && line_end > page_plain_end {
                page_plain_end = line_end;
            }
            continue;
        };

        let (cost, is_image) = match &blocks[bi] {
            ContentBlock::Image(img) => (
                image_display_height(
                    metrics.page_width_px,
                    img.intrinsic_width,
                    img.intrinsic_height,
                ),
                true,
            ),
            ContentBlock::Text(t) => {
                let eff = effective_font_size_px(&t.style, metrics);
                let ratio = eff / metrics.font_size_px.max(1.0);
                ((metrics.line_height_px * ratio).max(1.0), false)
            }
        };

        let spacing = if page_plain_start.is_some() && pending_spacing > 0.0 {
            pending_spacing
        } else {
            0.0
        };
        let total_need = spacing + cost;

        if page_plain_start.is_some() && remaining < total_need {
            flush_line_break_page(
                &mut pages,
                &mut page_idx,
                &mut remaining,
                &mut pending_spacing,
                &mut page_plain_start,
                &mut page_plain_end,
                &mut page_image_layouts,
                blocks,
                page_height,
            );
        }

        // 图片独占：当前页非空则先翻页；仍放不下则 FullPage
        let image_layout = if is_image {
            if page_plain_start.is_some() && cost > remaining {
                flush_line_break_page(
                    &mut pages,
                    &mut page_idx,
                    &mut remaining,
                    &mut pending_spacing,
                    &mut page_plain_start,
                    &mut page_plain_end,
                    &mut page_image_layouts,
                    blocks,
                    page_height,
                );
            }
            if cost > remaining {
                Some(ImageBlockLayout::FullPage)
            } else {
                Some(ImageBlockLayout::InlineContain)
            }
        } else {
            None
        };

        let spacing = if page_plain_start.is_some() && pending_spacing > 0.0 {
            pending_spacing
        } else {
            0.0
        };
        if spacing > 0.0 {
            remaining -= spacing;
            pending_spacing = 0.0;
        }

        if page_plain_start.is_none() {
            // 与上一页 plain 末尾衔接，吞掉块间 `\n` 间隙，避免 charOffset 落空
            page_plain_start = Some(
                pages
                    .last()
                    .map(|p| p.plain_end_exclusive())
                    .unwrap_or(line_start),
            );
        }
        page_plain_end = line_end;

        if matches!(image_layout, Some(ImageBlockLayout::FullPage)) {
            remaining = 0.0;
        } else {
            remaining = (remaining - cost).max(0.0);
        }

        if let Some(layout) = image_layout {
            page_image_layouts.push(PageImageLayout {
                block_index: bi as u32,
                layout,
            });
        }

        if let ContentBlock::Text(t) = &blocks[bi] {
            let block_end = t.plain.end_exclusive();
            if line_end >= block_end {
                let eff = effective_font_size_px(&t.style, metrics);
                pending_spacing = block_bottom_spacing_px(&t.style, eff, metrics);
            }
        }

        prev_line_end = line_end;

        if remaining <= 0.0 {
            flush_line_break_page(
                &mut pages,
                &mut page_idx,
                &mut remaining,
                &mut pending_spacing,
                &mut page_plain_start,
                &mut page_plain_end,
                &mut page_image_layouts,
                blocks,
                page_height,
            );
        }
    }

    flush_line_break_page(
        &mut pages,
        &mut page_idx,
        &mut remaining,
        &mut pending_spacing,
        &mut page_plain_start,
        &mut page_plain_end,
        &mut page_image_layouts,
        blocks,
        page_height,
    );

    if pages.is_empty() {
        pages.push(BlockPageDescriptor::new(
            0,
            0,
            0,
            BlockPlainRange::new(0, 0),
            true,
        ));
    } else {
        let last_idx = pages.len() - 1;
        for (i, p) in pages.iter_mut().enumerate() {
            p.is_last_page = i == last_idx;
        }
    }

    BlockPaginateResult::new(pages, config_hash, false)
}

/// 块数阈值：超过此值时分 chunk 独立分页，避免单次 `BlockPaginator` O(pathological_size)。
pub const CHUNK_BLOCK_COUNT: usize = 200;

/// 边界保护窗口：chunk 末尾 N 个块内如果出现 ImageBlock，扩展 chunk 使图片完整留在当前 chunk。
const CHUNK_BOUNDARY_GUARD: usize = 5;
/// 硬性上限：任何 chunk 的 block 数绝不超过此值（防极端恶意 EPUB）。
const MAX_CHUNK_SIZE_HARD: usize = 300;

/// 分 chunk 块分页：将 `ir.blocks` 按 [CHUNK_BLOCK_COUNT] 拆分，
/// 每 chunk 独立分页后合并 page descriptors。
///
/// 每个 chunk 的 [BlockPaginateResult] 可独立存入 sled 缓存（`chunk_index`）。
/// chunks ≤ 1 时委托给 [`paginate_chapter_ir`] 零开销。
///
/// **边界保护**：当 chunk 切割点附近（末尾 [CHUNK_BOUNDARY_GUARD] 个块内）有图片块时，
/// 将切割点向前推移，使图片完整归入当前 chunk，避免图片孤立在下一个 chunk 首部。
pub fn paginate_chapter_ir_chunked(
    ir: &ChapterContentIr,
    config: TypesetConfig,
) -> BlockPaginateResult {
    if ir.blocks.len() <= CHUNK_BLOCK_COUNT {
        return paginate_chapter_ir(ir, config);
    }

    // 务必先 validate_and_fix，确保 hash 与 paginate_chapter_ir 内部一致
    let config_hash = config.validate_and_fix().config_hash();
    let mut merged = BlockPaginateResult::new(vec![], config_hash, false);

    let mut offset = 0;
    while offset < ir.blocks.len() {
        let mut end = (offset + CHUNK_BLOCK_COUNT).min(ir.blocks.len());

        // 边界保护：如果切割点 end 之前的 guard 区域内有图片，向前扩展切割点
        // 把图片完整归入当前 chunk（但不超过整个剩余 blocks）
        if end < ir.blocks.len() {
            let guard_start = end.saturating_sub(CHUNK_BOUNDARY_GUARD);
            for i in guard_start..end {
                if matches!(ir.blocks[i], ContentBlock::Image(_)) {
                    // 找到最近图片块，将切割点扩展到该图片之后
                    // 但需继续扫描到下一个非图片块，避免连续图片仍被切断
                    let mut new_end = i + 1;
                    while new_end < ir.blocks.len()
                        && matches!(ir.blocks[new_end], ContentBlock::Image(_))
                    {
                        new_end += 1;
                    }
                    // 仅在扩展不超过原切割点 + guard 时生效（防止 chunk 过大）
                    if new_end <= offset + CHUNK_BLOCK_COUNT + CHUNK_BOUNDARY_GUARD {
                        end = new_end;
                    }
                    break; // 只需找到第一个图片即可触发扩展
                }
            }
        }

        // 硬性上限：图片连续块扩展后仍不得超过 MAX_CHUNK_SIZE_HARD
        let chunk_size = end - offset;
        if chunk_size > MAX_CHUNK_SIZE_HARD {
            end = offset + MAX_CHUNK_SIZE_HARD;
            tracing::warn!(
                "[ChunkGuard] chunk size capped to {} (was {}) due to continuous images near offset {}",
                MAX_CHUNK_SIZE_HARD, chunk_size, offset,
            );
        }

        let chunk = &ir.blocks[offset..end];
        let mut sub_ir = ChapterContentIr::new(chunk.to_vec(), ir.plain_text.clone());
        // 保留落入本 chunk plain 范围的行断点，避免大章丢失 ICU 路径
        if let Some(ref indices) = ir.line_break_indices {
            let chunk_start = chunk.first().map(|b| b.plain_start()).unwrap_or(0);
            let chunk_end = chunk
                .last()
                .map(|b| b.plain_start() + b.plain_len())
                .unwrap_or(0);
            let filtered: Vec<u32> = indices
                .iter()
                .copied()
                .filter(|&i| i > chunk_start && i <= chunk_end)
                .collect();
            if !filtered.is_empty() {
                sub_ir.line_break_indices = Some(filtered);
            }
        }
        let mut result = paginate_chapter_ir(&sub_ir, config.clone());
        // 将 chunk-relative 的 block 索引转换为全章绝对索引
        result.offset_block_indices(offset as u32);
        merged.merge(result);
        offset = end;
    }

    merged
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::types::typeset::TypesetCalibration;
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

    fn block_layout_metrics_for_test(config: &TypesetConfig) -> (f32, f32) {
        let m = BlockLayoutMetrics::from_config(config);
        (m.full_line_width_px, m.line_height_px)
    }

    fn long_text_ir(repeats: usize) -> ChapterContentIr {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("你好".repeat(repeats), TextBlockStyle::default());
        b.finish()
    }

    #[test]
    fn pure_text_splits_across_pages() {
        let ir = long_text_ir(200);
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();

        let result = paginate_chapter_ir(&ir, test_config());
        assert!(
            result.page_count() > 1,
            "expected multiple pages, got {}",
            result.page_count()
        );
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
    fn paragraph_spacing_must_fit_before_page_flush() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("你好你好".into(), TextBlockStyle::default());
        b.push_text("世界世界".into(), TextBlockStyle::default());
        let ir = b.finish();
        let mut config = test_config();
        config.page_width = 400;
        config.page_height = 100;
        config.font_size = 50;
        config.line_spacing = 1.0;
        config.paragraph_spacing = 1.0;

        let result = paginate_chapter_ir(&ir, config);

        assert!(
            result.page_count() >= 2,
            "line + paragraph spacing must not be squeezed onto one visual page"
        );
        assert_eq!(result.descriptors[0].plain.plain_start, 0);
        assert!(
            result.descriptors[0].plain.plain_len > 0,
            "first page must contain text"
        );
    }

    #[test]
    fn trailing_paragraph_spacing_does_not_block_last_line_on_page() {
        // 页高刚好放下 2 行；若尾随段距仍计入末行 required，会被迫少装一行。
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("甲乙丙丁戊己庚辛".into(), TextBlockStyle::default());
        let ir = b.finish();
        let mut config = test_config();
        config.page_width = 80; // ~2 CJK / line at font 16
        config.page_height = 48; // exactly 2 lines at line_h=24
        config.font_size = 16;
        config.line_spacing = 1.5;
        config.paragraph_spacing = 1.0; // would be +16px if trailing counted
        config.calibration = Some(TypesetCalibration {
            cjk_width: 16.0,
            ascii_width: 9.6,
            digit_width: 9.6,
            punct_width: 16.0,
            measured_line_height_px: 24.0,
            effective_line_width_ratio: 1.0,
            ..TypesetCalibration::default()
        });

        let result = paginate_chapter_ir(&ir, config);
        let first_len = result.descriptors[0].plain.plain_len;
        assert!(
            first_len >= 4,
            "without trailing spacing tax, first page should hold >=2 lines (~4 chars), got {first_len}"
        );
    }

    #[test]
    fn auto_space_ratio_does_not_reduce_mixed_pack_density() {
        // 混排：若分页计入 auto_space 而 Flutter 不渲染，会少装。
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text(
            "Hello世界Hello世界中文English混排测试文本内容足够长触发多行断行XYZ".into(),
            TextBlockStyle::default(),
        );
        let ir = b.finish();

        let mut with_space = test_config();
        with_space.page_width = 320;
        with_space.page_height = 400;
        with_space.auto_space_ratio = 0.25;
        with_space.calibration = Some(TypesetCalibration {
            cjk_width: 16.0,
            ascii_width: 9.6,
            digit_width: 9.6,
            punct_width: 16.0,
            measured_line_height_px: 24.0,
            effective_line_width_ratio: 1.0,
            ..TypesetCalibration::default()
        });

        let mut no_space = with_space.clone();
        no_space.auto_space_ratio = 0.0;

        let pages_with = paginate_chapter_ir(&ir, with_space).page_count();
        let pages_without = paginate_chapter_ir(&ir, no_space).page_count();
        assert_eq!(
            pages_with, pages_without,
            "auto_space_ratio must not change pack density until Flutter renders it"
        );
    }

    #[test]
    fn heading_fallback_font_size_affects_pagination() {
        let mut heading_style = TextBlockStyle {
            is_heading: true,
            heading_level: 1,
            ..TextBlockStyle::default()
        };
        heading_style.font_size = None;

        let mut normal_builder = BlockJoinedPlainBuilder::new();
        normal_builder.push_text("标题内容".repeat(80), TextBlockStyle::default());
        let normal_ir = normal_builder.finish();

        let mut heading_builder = BlockJoinedPlainBuilder::new();
        heading_builder.push_text("标题内容".repeat(80), heading_style);
        let heading_ir = heading_builder.finish();

        let mut config = test_config();
        config.font_size = 16;
        config.page_width = 180;
        config.page_height = 180;

        let normal = paginate_chapter_ir(&normal_ir, config.clone());
        let heading = paginate_chapter_ir(&heading_ir, config);

        assert!(
            heading.page_count() >= normal.page_count(),
            "heading fallback font size must not produce fewer pages"
        );
    }

    #[test]
    fn explicit_font_size_uses_device_pixels_for_line_height() {
        use crate::domain::TypesetCalibration;

        let style = TextBlockStyle {
            font_size: Some(20.0),
            margin_bottom_em: Some(0.0),
            ..TextBlockStyle::default()
        };
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("第一段".into(), style.clone());
        b.push_text("第二段".into(), style);
        let ir = b.finish();
        let config = TypesetConfig {
            page_width: 1000,
            page_height: 150,
            // 全局基准字号 45，calibration line_height=225px → 字号 20 时行高 100px
            font_size: 45,
            line_spacing: 1.5,
            first_line_indent: 0,
            paragraph_spacing: 0.0,
            calibration: Some(TypesetCalibration {
                dpr: 2.5,
                cjk_width: 50.0,
                ascii_width: 30.0,
                digit_width: 30.0,
                punct_width: 50.0,
                latin_ext_width: 35.0,
                other_width: 40.0,
                effective_line_width_ratio: DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO,
                // 225px * (20/45) = 100px 行高 → 两段各 1 行 → 2 页
                measured_line_height_px: 225.0,
            }),
            ..TypesetConfig::default()
        };

        let result = paginate_chapter_ir(&ir, config);

        assert_eq!(
            result.page_count(),
            2,
            "20px font * 225/45 calib ratio = 100px/line, 2 blocks 2 lines won't fit 150px"
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
    fn variable_width_layout_splits_long_cjk() {
        use crate::domain::TypesetCalibration;
        let config = TypesetConfig {
            page_width: 965,
            page_height: 2100,
            font_size: 47,
            line_spacing: 1.8,
            first_line_indent: 2,
            calibration: Some(TypesetCalibration {
                dpr: 2.6,
                cjk_width: 46.8,
                ascii_width: 28.0,
                digit_width: 28.0,
                punct_width: 46.8,
                latin_ext_width: 32.0,
                other_width: 36.0,
                effective_line_width_ratio: 1.0,
                ..TypesetCalibration::default()
            }),
            ..TypesetConfig::default()
        };
        let style = TextBlockStyle::default();
        let text = "中".repeat(27);
        let segments = layout_slice_text_segments(&text, false, &config, &style);
        assert!(
            segments.len() >= 2,
            "27 CJK chars must split on full page width, got {} segs",
            segments.len()
        );
    }

    #[test]
    fn visual_line_segments_split_long_cjk_with_calibration() {
        use crate::domain::TypesetCalibration;
        let config = TypesetConfig {
            page_width: 965,
            page_height: 2100,
            font_size: 18,
            line_spacing: 1.8,
            first_line_indent: 2,
            calibration: Some(TypesetCalibration {
                dpr: 2.6,
                cjk_width: 47.0,
                ascii_width: 28.0,
                digit_width: 28.0,
                punct_width: 47.0,
                latin_ext_width: 32.0,
                other_width: 36.0,
                ..TypesetCalibration::default()
            }),
            ..TypesetConfig::default()
        };
        let style = TextBlockStyle::default();
        let text = "中".repeat(23);
        let segments = layout_slice_text_segments(&text, false, &config, &style);
        assert!(
            segments.len() >= 2,
            "23 CJK chars should split into >=2 visual lines, got {}",
            segments.len()
        );
    }

    #[test]
    fn ensure_vertical_space_splits_when_budget_exhausted() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("你".repeat(60), TextBlockStyle::default());
        let ir = b.finish();
        let config = TypesetConfig {
            page_width: 200,
            page_height: 72,
            font_size: 16,
            line_spacing: 1.5,
            first_line_indent: 0,
            paragraph_spacing: 0.0,
            ..TypesetConfig::default()
        };
        let result = paginate_chapter_ir(&ir, config);
        assert!(
            result.page_count() >= 2,
            "expected multi-page split when line budget exhausted, got {}",
            result.page_count()
        );
    }

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
    fn paginate_from_line_breaks_uses_indices_for_exact_pages() {
        // Phase 6: 验证 `paginate_from_line_breaks` 使用预计算索引分页时
        // 产生的 PageDescriptor 与预期行边界一致。
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("测".repeat(300), TextBlockStyle::default());
        let mut ir = b.finish();

        // 模拟 24 行文本，每行 12 个字符，均匀断行
        let indices: Vec<u32> = (1..=24).map(|i| i * 12).collect();
        ir.line_break_indices = Some(indices.clone());

        let config = test_config(); // page_height=200, font=16, line_spacing=1.5
        let metrics = BlockLayoutMetrics::from_config(&config);
        let lines_per_page = (metrics.page_height_px / metrics.line_height_px).floor() as usize;

        let result = paginate_chapter_ir(&ir, config);

        assert!(!result.descriptors.is_empty(), "should produce pages");

        // 验证每页边界连续（上一页的 end == 下一页的 start）
        for i in 1..result.descriptors.len() {
            let prev = &result.descriptors[i - 1];
            let curr = &result.descriptors[i];
            let prev_end = prev.plain.plain_start + prev.plain.plain_len;
            assert_eq!(
                prev_end,
                curr.plain.plain_start,
                "page {} boundary discontinuity: prev end={} != curr start={}",
                i,
                prev_end,
                curr.plain.plain_start,
            );
        }

        // 验证最后一页覆盖到文本末尾
        let last = result.descriptors.last().unwrap();
        let total_chars: u32 = 24 * 12; // 24 lines × 12 chars
        let last_end = last.plain.plain_start + last.plain.plain_len;
        assert_eq!(
            last_end,
            total_chars,
            "last page should cover full text: end={}",
            last_end,
        );

        // 单块 IR：每页块范围必须覆盖 block 0（不能是空 0..0）
        for (i, p) in result.descriptors.iter().enumerate() {
            assert!(
                p.first_block_index < p.last_block_index,
                "page {i} must have non-empty block range, got {}..{}",
                p.first_block_index,
                p.last_block_index,
            );
            assert_eq!(p.first_block_index, 0);
            assert_eq!(p.last_block_index, 1);
        }

        // 验证每页行数不超过 lines_per_page（段距为 0 时与高度装箱等价）
        for (i, p) in result.descriptors.iter().enumerate() {
            let p_start = p.plain.plain_start;
            let p_end = p_start + p.plain.plain_len;
            let page_lines = indices
                .iter()
                .filter(|&&c| c > p_start && c <= p_end)
                .count();
            assert!(
                page_lines <= lines_per_page,
                "page {i} has {page_lines} lines (max {lines_per_page})",
            );
        }
    }

    #[test]
    fn paginate_from_line_breaks_maps_multi_block_ranges() {
        // 根因回归：多段落时不得写死 first=0/last=1，否则后续页 page_blocks 为空。
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..8 {
            b.push_text(format!("段落{i}内容足够长一些"), TextBlockStyle::default());
        }
        let mut ir = b.finish();
        assert!(ir.blocks.len() >= 8);

        // 每块约一行：用各块 end 作为行断点（外加块间 \n 跳过由引擎处理）
        let mut indices = Vec::new();
        for block in &ir.blocks {
            indices.push(block.plain_start() + block.plain_len());
        }
        // 确保覆盖到 plain 末尾
        let plain_len = ir.plain_text.chars().count() as u32;
        if indices.last().copied() != Some(plain_len) {
            indices.push(plain_len);
        }
        ir.line_break_indices = Some(indices);

        let mut config = test_config();
        config.paragraph_spacing = 1.0; // 段距参与装箱
        let result = paginate_chapter_ir(&ir, config);

        assert!(result.page_count() >= 1);
        // 全章覆盖的块上界必须到达最后一块
        let max_last = result
            .descriptors
            .iter()
            .map(|d| d.last_block_index)
            .max()
            .unwrap_or(0);
        assert_eq!(
            max_last,
            ir.blocks.len() as u32,
            "line-break pages must cover all blocks, max_last={max_last}"
        );

        // 任意页的 plain 范围与块范围必须相交（否则渲染空页）
        for (i, d) in result.descriptors.iter().enumerate() {
            assert!(
                d.last_block_index > d.first_block_index,
                "page {i} empty block range {}..{}",
                d.first_block_index,
                d.last_block_index
            );
            let (expect_first, expect_last) = block_range_covering_plain(
                &ir.blocks,
                d.plain.plain_start,
                d.plain_end_exclusive(),
            );
            assert_eq!(
                d.first_block_index, expect_first,
                "page {i} first_block mismatch"
            );
            assert_eq!(
                d.last_block_index, expect_last,
                "page {i} last_block mismatch"
            );
        }
    }

    #[test]
    fn chunked_large_chapter_produces_valid_descriptors() {
        // Large chapter (>200 blocks) — should chunk and merge
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..(CHUNK_BLOCK_COUNT + 50) {
            b.push_text(
                format!("Block {i}: some text to paginate."),
                TextBlockStyle::default(),
            );
        }
        let ir = b.finish();
        assert!(ir.block_count() > CHUNK_BLOCK_COUNT);

        let result = paginate_chapter_ir_chunked(&ir, test_config());
        assert!(
            result.page_count() > 1,
            "expected {} pages, got {}",
            result.page_count(),
            result.page_count()
        );

        // Verify monotonic plain ranges across all descriptors
        let mut prev_end = 0u32;
        for d in &result.descriptors {
            assert!(
                d.plain.plain_start >= prev_end.saturating_sub(1),
                "descriptor page={} plain_start={} < prev_end={}",
                d.page_index,
                d.plain.plain_start,
                prev_end
            );
            prev_end = d.plain_end_exclusive();
        }

        // Verify page_index is sequential
        for (i, d) in result.descriptors.iter().enumerate() {
            assert_eq!(
                d.page_index as usize, i,
                "page_index mismatch at descriptor {}",
                i
            );
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

    #[test]
    fn chunked_zero_blocks_produces_one_empty_page() {
        let ir = ChapterContentIr::new(vec![], String::new());
        assert_eq!(ir.block_count(), 0);
        let result = paginate_chapter_ir_chunked(&ir, test_config());
        assert_eq!(
            result.page_count(),
            1,
            "0-block chapter should produce 1 placeholder page"
        );
    }

    #[test]
    fn chunked_boundary_guard_keeps_image_in_current_chunk() {
        // 构造 >200 blocks 的 IR，在 chunk 边界附近插入图片
        // 验证图片不会被孤零零地推到下一个 chunk 开头
        let mut b = BlockJoinedPlainBuilder::new();
        // 前 197 个文本块
        for i in 0..197 {
            b.push_text(format!("Text block {i}."), TextBlockStyle::default());
        }
        // 在边界附近插入图片块（块索引 197，恰好在 200 块切割点附近）
        b.push_image("test_image.png".into(), None);
        // 后续文本块使总 block 数 > CHUNK_BLOCK_COUNT
        for i in 0..50 {
            b.push_text(format!("After image block {i}."), TextBlockStyle::default());
        }
        let ir = b.finish();
        assert!(ir.block_count() > CHUNK_BLOCK_COUNT);

        let result = paginate_chapter_ir_chunked(&ir, test_config());
        // 验证分页结果有效
        assert!(result.page_count() > 1);

        // 验证 plain range 单调递增
        let mut prev_end = 0u32;
        for d in &result.descriptors {
            assert!(
                d.plain.plain_start >= prev_end.saturating_sub(1),
                "descriptor page={} plain_start={} < prev_end={}",
                d.page_index,
                d.plain.plain_start,
                prev_end
            );
            prev_end = d.plain_end_exclusive();
        }
    }

    // ── Layer B: ratio / line_height ──

    #[test]
    fn b1_full_line_width_equals_page_width_ignores_ratio() {
        let mut config = test_config();
        config.page_width = 1000;
        config.calibration = Some(TypesetCalibration {
            effective_line_width_ratio: 0.90,
            ..TypesetCalibration::default()
        });
        let (full_w, _) = block_layout_metrics_for_test(&config);
        assert!(
            (full_w - 1000.0).abs() < 0.1,
            "full_line_w should equal page_width even when ratio=0.90, got {full_w}"
        );
    }

    #[test]
    fn b2_measured_line_height_affects_page_count() {
        let mut config_default = test_config();
        config_default.calibration = None;
        let result_default = paginate_chapter_ir(&long_text_ir(80), config_default);

        let mut config_large = test_config();
        config_large.calibration = Some(TypesetCalibration {
            measured_line_height_px: 48.0,
            ..TypesetCalibration::default()
        });
        let result_large = paginate_chapter_ir(&long_text_ir(80), config_large);

        // Larger line height → more pages (fewer lines fit)
        assert!(
            result_large.page_count() >= result_default.page_count(),
            "larger line_height should produce >= pages ({} >= {})",
            result_large.page_count(),
            result_default.page_count()
        );
    }

    #[test]
    fn b3_narrower_cjk_width_more_chars_per_page() {
        let ir = long_text_ir(100);

        let mut config_wide_glyph = test_config();
        config_wide_glyph.calibration = Some(TypesetCalibration {
            cjk_width: 20.0,
            ascii_width: 12.0,
            digit_width: 12.0,
            punct_width: 20.0,
            effective_line_width_ratio: 1.0,
            ..TypesetCalibration::default()
        });
        let result_wide_glyph = paginate_chapter_ir(&ir, config_wide_glyph);

        let mut config_narrow_glyph = test_config();
        config_narrow_glyph.calibration = Some(TypesetCalibration {
            cjk_width: 14.0,
            ascii_width: 8.0,
            digit_width: 8.0,
            punct_width: 14.0,
            effective_line_width_ratio: 1.0,
            ..TypesetCalibration::default()
        });
        let result_narrow_glyph = paginate_chapter_ir(&ir, config_narrow_glyph);

        assert!(
            result_narrow_glyph.page_count() <= result_wide_glyph.page_count(),
            "narrower cjk pages={} should be <= wider cjk pages={}",
            result_narrow_glyph.page_count(),
            result_wide_glyph.page_count()
        );
    }

    #[test]
    fn b4_ratio_does_not_change_page_count() {
        let mut config_a = test_config();
        config_a.calibration = Some(TypesetCalibration {
            effective_line_width_ratio: 0.90,
            cjk_width: 16.0,
            ascii_width: 9.6,
            digit_width: 9.6,
            punct_width: 16.0,
            ..TypesetCalibration::default()
        });

        let mut config_b = test_config();
        config_b.calibration = Some(TypesetCalibration {
            effective_line_width_ratio: 1.0,
            cjk_width: 16.0,
            ascii_width: 9.6,
            digit_width: 9.6,
            punct_width: 16.0,
            ..TypesetCalibration::default()
        });

        let ir = long_text_ir(100);
        let result_a = paginate_chapter_ir(&ir, config_a);
        let result_b = paginate_chapter_ir(&ir, config_b);

        assert_eq!(
            result_a.page_count(),
            result_b.page_count(),
            "ratio must not affect packing page count after full-width break"
        );
    }

    // ── 属性测试（Property-based） ──

    /// I1: 任意配置下，所有非尾页的 plain_start < plain_end。
    fn assert_pages_non_empty(descriptors: &[BlockPageDescriptor]) {
        for d in descriptors {
            assert!(
                d.plain.plain_start < d.plain_end_exclusive() || d.is_last_page,
                "page={}: plain_start={} >= plain_end={}",
                d.page_index,
                d.plain.plain_start,
                d.plain_end_exclusive()
            );
        }
    }

    /// I2: plain 范围单调不重叠。允许 1 字符间隙（换行符 / \uFFFC 跨页边界导致）。
    fn assert_plain_ranges_contiguous(descriptors: &[BlockPageDescriptor], ir_plain_len: usize) {
        let mut prev_end = 0u32;
        for d in descriptors {
            assert!(
                d.plain.plain_start >= prev_end.saturating_sub(1),
                "page={}: plain_start={} < prev_end={} (gap > 1)",
                d.page_index,
                d.plain.plain_start,
                prev_end
            );
            prev_end = d.plain_end_exclusive();
        }
        assert_eq!(
            prev_end as usize, ir_plain_len,
            "plain_end={} != ir_plain_len={}",
            prev_end, ir_plain_len
        );
    }

    /// I3: 所有块的 block 索引在 IR 块数范围内。
    fn assert_block_indices_valid(descriptors: &[BlockPageDescriptor], ir_block_count: usize) {
        for d in descriptors {
            assert!(
                (d.first_block_index as usize) < ir_block_count,
                "page={}: first_block={} >= ir_block_count={}",
                d.page_index,
                d.first_block_index,
                ir_block_count
            );
            assert!(
                (d.last_block_index as usize) <= ir_block_count,
                "page={}: last_block={} > ir_block_count={}",
                d.page_index,
                d.last_block_index,
                ir_block_count
            );
            if !d.is_last_page || d.last_block_index > d.first_block_index {
                assert!(
                    d.first_block_index < d.last_block_index,
                    "page={}: first_block={} >= last_block={}",
                    d.page_index,
                    d.first_block_index,
                    d.last_block_index
                );
            }
        }
    }

    /// I4: page_index 从 0 开始连续递增。
    fn assert_page_indices_sequential(descriptors: &[BlockPageDescriptor]) {
        for (i, d) in descriptors.iter().enumerate() {
            assert_eq!(d.page_index as usize, i, "page_index gap at descriptor {i}");
        }
    }

    /// 综合属性测试：构造多块 IR → 分页 → 验证四条不变量。
    fn run_property_checks(ir: &ChapterContentIr, config: &TypesetConfig) {
        let ir_plain_len = ir.plain_text.chars().count();
        let ir_block_count = ir.block_count();
        let result = paginate_chapter_ir(ir, config.clone());
        assert!(result.page_count() > 0, "must produce at least 1 page");

        assert_pages_non_empty(&result.descriptors);
        assert_plain_ranges_contiguous(&result.descriptors, ir_plain_len);
        assert_block_indices_valid(&result.descriptors, ir_block_count);
        assert_page_indices_sequential(&result.descriptors);
    }

    #[test]
    fn prop_single_text_block() {
        let ir = long_text_ir(50);
        run_property_checks(&ir, &test_config());
    }

    #[test]
    fn prop_many_small_text_blocks() {
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..20 {
            b.push_text(format!("Block {i}: short text."), TextBlockStyle::default());
        }
        let ir = b.finish();
        run_property_checks(&ir, &test_config());
    }

    #[test]
    fn prop_image_only_chapter() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_image("cover.jpg".into(), Some("Cover".into()));
        b.push_image("illustration.png".into(), None);
        let ir = b.finish();
        run_property_checks(&ir, &test_config());
    }

    #[test]
    fn prop_mixed_text_and_images() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Before image.".into(), TextBlockStyle::default());
        b.push_image("img1.jpg".into(), Some("Image 1".into()));
        b.push_text("Between images.".into(), TextBlockStyle::default());
        b.push_image("img2.png".into(), None);
        b.push_text("After images.".into(), TextBlockStyle::default());
        let ir = b.finish();
        run_property_checks(&ir, &test_config());
    }

    #[test]
    fn prop_varied_block_styles() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text(
            "Heading".into(),
            TextBlockStyle {
                is_heading: true,
                heading_level: 1,
                font_size: Some(24.0),
                ..TextBlockStyle::default()
            },
        );
        for i in 0..10 {
            b.push_text(
                format!("Paragraph {i}: some longer text that should wrap across lines."),
                TextBlockStyle {
                    text_indent_em: Some(2.0),
                    margin_bottom_em: Some(1.0),
                    ..TextBlockStyle::default()
                },
            );
        }
        let ir = b.finish();
        run_property_checks(&ir, &test_config());
    }

    #[test]
    fn prop_empty_chapter() {
        let ir = ChapterContentIr::new(vec![], String::new());
        let result = paginate_chapter_ir(&ir, test_config());
        assert_eq!(result.page_count(), 1);
    }

    #[test]
    fn prop_chunked_preserves_contiguity() {
        // 构造 >200 块以命中 chunked 路径，验证合并后不变量保持
        let mut b = BlockJoinedPlainBuilder::new();
        for i in 0..CHUNK_BLOCK_COUNT + 10 {
            b.push_text(format!("Block {i}: text."), TextBlockStyle::default());
        }
        let ir = b.finish();
        assert!(ir.block_count() > CHUNK_BLOCK_COUNT);
        run_property_checks(&ir, &test_config());
    }
}
