//! 内容管线核心类型定义
//!
//! IR 数据类型、分页类型、富文本类型集中在此文件，
//! 其余文件只保留纯函数。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

// ==================== plain 坐标 ====================

/// ADR-008：每个 [`ContentBlock::Image`] 在章级 plain 中占 1 个 OBJECT REPLACEMENT 字符。
pub const IMAGE_PLAIN_PLACEHOLDER: char = '\u{FFFC}';

/// 图片块在 plain 中的字符长度（恒为 1）。
pub const IMAGE_PLAIN_CHAR_LEN: u32 = 1;

/// 块级 plain 坐标：Unicode 标量字符索引（与 glossary「charOffset」语义一致）。
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

// ==================== 富文本 ====================

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
pub enum SpanStyle {
    Plain,
    Bold,
    Italic,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
pub struct RichTextSpanData {
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
pub enum RichTextSpan {
    Styled(SpanStyle, RichTextSpanData),
    Link { data: RichTextSpanData, url: String },
}

impl RichTextSpan {
    #[frb(ignore)]
    pub fn text(&self) -> &str {
        match self {
            RichTextSpan::Styled(_, data) => &data.text,
            RichTextSpan::Link { data, .. } => &data.text,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RichParagraph {
    pub spans: Vec<RichTextSpan>,
    pub indent: u8,
    pub is_heading: bool,
    pub heading_level: u8,
    pub class_name: Option<String>,
    pub text_align: Option<String>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub text_indent_em: Option<f32>,
    pub font_size: Option<f32>,
    pub is_image: bool,
    pub image_src: Option<String>,
    pub image_data: Vec<u8>,
    pub image_alt: Option<String>,
}

impl RichParagraph {
    #[frb(ignore)]
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text()).collect()
    }

    #[frb(ignore)]
    pub fn image_placeholder(src: String, alt: String) -> Self {
        Self {
            spans: Vec::new(),
            indent: 0,
            is_heading: false,
            heading_level: 0,
            class_name: None,
            text_align: None,
            margin_top_em: None,
            margin_bottom_em: None,
            text_indent_em: None,
            font_size: None,
            is_image: true,
            image_src: Some(src),
            image_data: Vec::new(),
            image_alt: Some(alt),
        }
    }
}

// ==================== 文本块 ====================

#[derive(
    Debug, Clone, PartialEq, Serialize, Deserialize, Default, bincode::Encode, bincode::Decode,
)]
#[frb(non_opaque)]
pub struct TextBlockStyle {
    pub is_heading: bool,
    pub heading_level: u8,
    pub text_indent_em: Option<f32>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub text_align: Option<String>,
    pub font_size: Option<f32>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct TextBlock {
    pub plain: BlockPlainRange,
    pub text: String,
    pub style: TextBlockStyle,
    pub spans: Vec<RichTextSpan>,
}

impl TextBlock {
    #[frb(ignore)]
    pub fn new(plain_start: u32, text: String, style: TextBlockStyle) -> Self {
        let plain_len = text.chars().count() as u32;
        Self {
            plain: BlockPlainRange::new(plain_start, plain_len),
            text,
            style,
            spans: Vec::new(),
        }
    }

    #[frb(ignore)]
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

// ==================== 图片块 ====================

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ImageBlock {
    pub plain: BlockPlainRange,
    pub asset_id: String,
    pub alt: Option<String>,
    pub intrinsic_width: Option<u32>,
    pub intrinsic_height: Option<u32>,
}

impl ImageBlock {
    #[frb(ignore)]
    pub fn new(plain_start: u32, asset_id: String, alt: Option<String>) -> Self {
        Self {
            plain: BlockPlainRange::new(plain_start, IMAGE_PLAIN_CHAR_LEN),
            asset_id,
            alt,
            intrinsic_width: None,
            intrinsic_height: None,
        }
    }

    #[frb(ignore)]
    pub fn validate_plain(&self) -> bool {
        self.plain.plain_len == IMAGE_PLAIN_CHAR_LEN
    }

    #[frb(ignore)]
    pub fn with_intrinsic_size(mut self, width: Option<u32>, height: Option<u32>) -> Self {
        self.intrinsic_width = width;
        self.intrinsic_height = height;
        self
    }
}

// ==================== 内容块枚举 ====================

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub enum ContentBlock {
    Text(TextBlock),
    Image(ImageBlock),
}

impl ContentBlock {
    #[frb(ignore)]
    pub fn plain_range(&self) -> BlockPlainRange {
        match self {
            ContentBlock::Text(t) => t.plain,
            ContentBlock::Image(img) => img.plain,
        }
    }
}

// ==================== 章节 IR ====================

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ChapterContentIr {
    pub blocks: Vec<ContentBlock>,
    pub plain_text: String,
    pub line_break_indices: Option<Vec<u32>>,
}

impl ChapterContentIr {
    #[frb(ignore)]
    pub fn new(blocks: Vec<ContentBlock>, plain_text: String) -> Self {
        Self {
            blocks,
            plain_text,
            line_break_indices: None,
        }
    }

    #[frb(ignore)]
    pub fn image_block_count(&self) -> usize {
        self.blocks
            .iter()
            .filter(|b| matches!(b, ContentBlock::Image(_)))
            .count()
    }

    #[frb(ignore)]
    pub fn image_placeholder_count(&self) -> usize {
        self.plain_text
            .chars()
            .filter(|&c| c == IMAGE_PLAIN_PLACEHOLDER)
            .count()
    }
}

// ==================== 分页/搜索类型 ====================

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct SearchResult {
    pub book_id: String,
    pub chapter_id: String,
    #[sqlx(try_from = "i64")]
    pub chapter_index: i32,
    pub chapter_title: String,
    pub snippet: String,
    pub position: i32,
    pub score: f32,
    pub char_offset: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb]
pub struct IndexStats {
    pub total_chunks: i64,
    pub indexed_books: i64,
    pub indexed_chapters: i64,
}
