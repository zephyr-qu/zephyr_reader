//! 内容管线核心类型定义
//!
//! 扁平 IR 类型，直接供 Flutter 消费。
//! - `ReaderChapterIr` 是唯一对外暴露的章级 IR。
//! - `ReaderIrBlock` 合并 Text/Image 为一个枚举变体。
//! - `ReaderInlineRun` 替代旧 `RichTextSpan` + `RichTextSpanData`。
//! - `plain_start`/`plain_len` 直接挂在 block 上，无中间 `BlockPlainRange`。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

// ==================== 常量 ====================

/// 每个 Image block 在章级 plain 中占 1 个 UTF-16 code unit 的 OBJECT REPLACEMENT 字符。
pub const IMAGE_PLAIN_PLACEHOLDER: char = '\u{FFFC}';

/// 图片块在 plain 中的字符长度（恒为 1）。
pub const IMAGE_PLAIN_CHAR_LEN: u32 = 1;

// ==================== 行内样式 ====================

/// 行内 span 样式。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
pub enum ReaderInlineStyle {
    Plain,
    Bold,
    Italic,
}

// ==================== 行内运行 ====================

/// 扁平的行内运行（替代旧 RichTextSpan + RichTextSpanData）。
///
/// Link 通过 `url` 字段非空表达（不再作为 enum variant）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ReaderInlineRun {
    pub text: String,
    pub style: ReaderInlineStyle,
    /// 链接 URL，非空时表此 run 为链接。
    pub url: Option<String>,
}

// ==================== 块类型 ====================

/// IR 块类型枚举。
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
pub enum ReaderIrBlockKind {
    Text,
    Image,
}

// ==================== 块级样式 ====================

/// 块级样式字段（从 ReaderIrBlock 抽出，减少 FRB 构造参数）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct BlockStyle {
    pub is_heading: bool,
    pub heading_level: u8,
    pub text_indent_em: Option<f32>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub text_align: Option<String>,
    pub font_size: Option<f32>,
}

impl BlockStyle {
    /// 空样式（适用于 Image 块）。
    pub fn empty() -> Self {
        Self {
            is_heading: false,
            heading_level: 0,
            text_indent_em: None,
            margin_top_em: None,
            margin_bottom_em: None,
            text_align: None,
            font_size: None,
        }
    }
}

// ==================== IR 块 ====================

/// 扁平的 IR 块（替代旧 ContentBlock / TextBlock / ImageBlock）。
///
/// - Text 块：`kind = Text`，runs 含内联样式，image_* 字段为空。
/// - Image 块：`kind = Image`，`plain_len == 1`，plain 中对应一个 `\u{FFFC}`。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ReaderIrBlock {
    pub kind: ReaderIrBlockKind,

    // ===== plain 坐标（直接挂 block，无 BlockPlainRange） =====
    pub plain_start: u32,
    pub plain_len: u32,

    // ===== 文本字段（Text 块使用） =====
    /// 块级纯文本（runs 文本拼接后）。
    pub text: String,
    /// 行内运行列表。
    pub runs: Vec<ReaderInlineRun>,

    // ===== 样式字段 ======
    pub style: BlockStyle,

    // ===== 图片字段（Image 块使用） =====
    pub image_asset_id: Option<String>,
    pub image_alt: Option<String>,
    pub image_intrinsic_width: Option<u32>,
    pub image_intrinsic_height: Option<u32>,
}
impl ReaderIrBlock {
    /// 构造文本块
    #[allow(clippy::too_many_arguments)]
    #[frb(ignore)]
    pub fn text(
        plain_start: u32,
        text: String,
        runs: Vec<ReaderInlineRun>,
        style: BlockStyle,
    ) -> Self {
        let plain_len = text.encode_utf16().count() as u32;
        Self {
            kind: ReaderIrBlockKind::Text,
            plain_start,
            plain_len,
            text,
            runs,
            style,
            image_asset_id: None,
            image_alt: None,
            image_intrinsic_width: None,
            image_intrinsic_height: None,
        }
    }

    /// 构造图片块
    #[frb(ignore)]
    pub fn image(
        plain_start: u32,
        asset_id: String,
        alt: Option<String>,
        intrinsic_width: Option<u32>,
        intrinsic_height: Option<u32>,
    ) -> Self {
        Self {
            kind: ReaderIrBlockKind::Image,
            plain_start,
            plain_len: IMAGE_PLAIN_CHAR_LEN,
            text: String::new(),
            runs: Vec::new(),
            style: BlockStyle::empty(),
            image_asset_id: Some(asset_id),
            image_alt: alt,
            image_intrinsic_width: intrinsic_width,
            image_intrinsic_height: intrinsic_height,
        }
    }
}

// ==================== 章节 IR ====================

/// 章节 IR（替代旧 ChapterContentIr）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct ReaderChapterIr {
    pub blocks: Vec<ReaderIrBlock>,
    pub plain_text: String,
}

impl ReaderChapterIr {
    #[frb(ignore)]
    pub fn new(blocks: Vec<ReaderIrBlock>, plain_text: String) -> Self {
        Self { blocks, plain_text }
    }

    /// 图片块数量
    #[frb(ignore)]
    pub fn image_block_count(&self) -> usize {
        self.blocks
            .iter()
            .filter(|b| b.kind == ReaderIrBlockKind::Image)
            .count()
    }

    /// plain 中图片占位符数量
    #[frb(ignore)]
    pub fn image_placeholder_count(&self) -> usize {
        self.plain_text
            .chars()
            .filter(|&c| c == IMAGE_PLAIN_PLACEHOLDER)
            .count()
    }
}
