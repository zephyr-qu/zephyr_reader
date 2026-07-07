//! 章节内容 IR（Intermediate Representation）
//!
//! Phase 2 块分页输入。EPUB/TXT 解析归一为 [`ContentBlock`] 流；
//! plain 投影规则见 ADR-008（图片 = `\uFFFC`）。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use super::rich_text::RichTextSpan;

/// ADR-008：每个 [`ContentBlock::Image`] 在章级 plain 中占 1 个 OBJECT REPLACEMENT 字符。
pub const IMAGE_PLAIN_PLACEHOLDER: char = '\u{FFFC}';

/// 图片块在 plain 中的字符长度（恒为 1）。
pub const IMAGE_PLAIN_CHAR_LEN: u32 = 1;

/// 块级 plain 坐标：Unicode 标量字符索引（与 glossary「charOffset」语义一致）。
///
/// `plain_start` 为章内从 0 起的字符下标；`plain_len` 为该块占用的字符数。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
#[frb(non_opaque)]
pub struct BlockPlainRange {
    pub plain_start: u32,
    pub plain_len: u32,
}

impl BlockPlainRange {
    pub const fn new(plain_start: u32, plain_len: u32) -> Self {
        Self {
            plain_start,
            plain_len,
        }
    }

    pub const fn end_exclusive(&self) -> u32 {
        self.plain_start.saturating_add(self.plain_len)
    }
}

/// 文本块级样式（ADR-010；行内 span 后续扩展）。
#[derive(
    Debug, Clone, PartialEq, Serialize, Deserialize, Default, bincode::Encode, bincode::Decode,
)]
#[frb(non_opaque)]
pub struct TextBlockStyle {
    pub is_heading: bool,
    pub heading_level: u8,
    /// 首行缩进（em）。`None` → 使用 [`TypesetConfig::first_line_indent`] / 用户设置。
    pub text_indent_em: Option<f32>,
    /// 块上边距（em）。
    pub margin_top_em: Option<f32>,
    /// 块下边距（em）。
    pub margin_bottom_em: Option<f32>,
    /// CSS `font-family` 提示（首族名）。
    pub font_family: Option<String>,
    /// CSS `line-height` 倍数。
    pub line_height: Option<f32>,
    /// CSS `text-align`：`left` | `center` | `right` | `justify`。
    pub text_align: Option<String>,
    /// CSS `font-size`（px）；`None` → 使用 [`TypesetConfig::font_size`]。
    pub font_size: Option<f32>,
}

/// 文本内容块。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct TextBlock {
    pub plain: BlockPlainRange,
    /// 块内 UTF-8 文本（与 plain 投影一致；不含 `\uFFFC`）。
    pub text: String,
    pub style: TextBlockStyle,
    /// 行内格式段（ADR-010）。空 → 渲染时按 [text] plain 处理（TXT 路径）。
    pub spans: Vec<RichTextSpan>,
}

impl TextBlock {
    /// 无行内样式（TXT / plain fallback）。
    pub fn new(plain_start: u32, text: String, style: TextBlockStyle) -> Self {
        let plain_len = text.chars().count() as u32;
        Self {
            plain: BlockPlainRange::new(plain_start, plain_len),
            text,
            style,
            spans: Vec::new(),
        }
    }

    /// EPUB 富文本段（[spans] 拼接须等于 [text]）。
    pub fn with_spans(plain_start: u32, spans: Vec<RichTextSpan>, style: TextBlockStyle) -> Self {
        let text: String = spans.iter().map(|s| s.text()).collect();
        let plain_len = text.chars().count() as u32;
        Self {
            plain: BlockPlainRange::new(plain_start, plain_len),
            text,
            style,
            spans,
        }
    }
}

/// 图片内容块（字节懒加载；分页/layout 用 asset_id）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ImageBlock {
    pub plain: BlockPlainRange,
    /// EPUB manifest / 章内资源唯一 id（非 file path）。
    pub asset_id: String,
    pub alt: Option<String>,
    /// 原图像素宽（可选；分页 contain 缩放用）。
    pub intrinsic_width: Option<u32>,
    /// 原图像素高（可选）。
    pub intrinsic_height: Option<u32>,
}

impl ImageBlock {
    pub fn new(plain_start: u32, asset_id: String, alt: Option<String>) -> Self {
        Self {
            plain: BlockPlainRange::new(plain_start, IMAGE_PLAIN_CHAR_LEN),
            asset_id,
            alt,
            intrinsic_width: None,
            intrinsic_height: None,
        }
    }

    pub fn with_intrinsic_size(mut self, width: Option<u32>, height: Option<u32>) -> Self {
        self.intrinsic_width = width;
        self.intrinsic_height = height;
        self
    }

    /// ADR-008 不变量：`plain_len == 1`。
    pub fn validate_plain(&self) -> bool {
        self.plain.plain_len == IMAGE_PLAIN_CHAR_LEN
    }
}

/// 章节 IR 块（Text | Image）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub enum ContentBlock {
    Text(TextBlock),
    Image(ImageBlock),
}

impl ContentBlock {
    pub fn plain_range(&self) -> BlockPlainRange {
        match self {
            Self::Text(b) => b.plain,
            Self::Image(b) => b.plain,
        }
    }

    pub fn plain_start(&self) -> u32 {
        self.plain_range().plain_start
    }

    pub fn plain_len(&self) -> u32 {
        self.plain_range().plain_len
    }

    pub fn is_image(&self) -> bool {
        matches!(self, Self::Image(_))
    }
}

/// 一章的 IR 产物：块流 + 完整 plain 投影。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ChapterContentIr {
    pub blocks: Vec<ContentBlock>,
    /// 章级 plain（Text 块拼接 + 每 Image 一个 `\uFFFC`）。
    pub plain_text: String,
    /// 预计算的行断点字符索引（绝对位置，在 plain_text 中）。
    /// `Some` 时 Rust 跳过自身断行，直接用此列表分页。
    pub line_break_indices: Option<Vec<u32>>,
}

impl ChapterContentIr {
    pub fn new(blocks: Vec<ContentBlock>, plain_text: String) -> Self {
        Self {
            blocks,
            plain_text,
            line_break_indices: None,
        }
    }

    pub fn with_line_breaks(
        blocks: Vec<ContentBlock>,
        plain_text: String,
        line_break_indices: Vec<u32>,
    ) -> Self {
        Self {
            blocks,
            plain_text,
            line_break_indices: Some(line_break_indices),
        }
    }

    pub fn block_count(&self) -> usize {
        self.blocks.len()
    }

    pub fn image_block_count(&self) -> usize {
        self.blocks.iter().filter(|b| b.is_image()).count()
    }

    /// plain 中 `\uFFFC` 个数应等于 Image 块数（ADR-008）。
    pub fn image_placeholder_count(&self) -> usize {
        self.plain_text
            .chars()
            .filter(|&c| c == IMAGE_PLAIN_PLACEHOLDER)
            .count()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_block_plain_len_matches_char_count() {
        let block = TextBlock::new(0, "你好 world".to_string(), TextBlockStyle::default());
        assert_eq!(block.plain.plain_len, 8);
        assert_eq!(block.plain.plain_start, 0);
    }

    #[test]
    fn image_block_enforces_fffc_plain_len() {
        let block = ImageBlock::new(10, "img_cover".into(), Some("cover".into()));
        assert!(block.validate_plain());
        assert_eq!(block.plain.plain_start, 10);
        assert_eq!(block.plain.plain_len, 1);
    }

    #[test]
    fn chapter_ir_placeholder_count_matches_images() {
        let ir = ChapterContentIr::new(
            vec![
                ContentBlock::Text(TextBlock::new(
                    0,
                    "before".into(),
                    TextBlockStyle::default(),
                )),
                ContentBlock::Image(ImageBlock::new(6, "a1".into(), None)),
                ContentBlock::Image(ImageBlock::new(7, "a2".into(), None)),
            ],
            format!("before{IMAGE_PLAIN_PLACEHOLDER}{IMAGE_PLAIN_PLACEHOLDER}"),
        );
        assert_eq!(ir.image_block_count(), 2);
        assert_eq!(ir.image_placeholder_count(), 2);
    }

    #[test]
    fn content_block_plain_range_accessor() {
        let block = ContentBlock::Image(ImageBlock::new(3, "x".into(), None));
        assert_eq!(block.plain_start(), 3);
        assert_eq!(block.plain_len(), 1);
    }
}
