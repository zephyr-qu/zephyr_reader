//! 富文本结构模块 (Rich Text)
//!
//! 包含富文本段落、文本段、章节内容等结构体。
//! 用于表示带有格式（粗体、斜体、链接等）的文本内容。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use super::typeset::TypesetConfig;

// ==================== 富文本段落 ====================

/// 富文本段落
/// 包含多个文本段（spans）和段落属性
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[frb(non_opaque)]
pub struct RichParagraph {
    /// 文本段列表
    pub spans: Vec<RichTextSpan>,
    /// 缩进字符数
    pub indent: u8,
    /// 是否为标题
    pub is_heading: bool,
    /// 标题级别（1-6）
    pub heading_level: u8,
    /// CSS 类名
    pub class_name: Option<String>,
    /// 文本对齐方式
    pub text_align: Option<String>,
    /// 行高
    pub line_height: Option<f32>,
    /// 是否为图片
    pub is_image: bool,
    /// 图片源路径
    pub image_src: Option<String>,
    /// 图片数据
    pub image_data: Vec<u8>,
    /// 图片替代文本
    pub image_alt: Option<String>,
}

impl RichParagraph {
    /// 创建纯文本段落
    pub fn plain(text: String, indent: u8) -> Self {
        Self {
            spans: vec![RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
                text,
                font_size: None,
                color: None,
            })],
            indent,
            ..Default::default()
        }
    }

    /// 应用排版配置（首行缩进）
    pub fn apply_typeset(&mut self, config: &TypesetConfig) {
        if !self.is_heading && config.first_line_indent > 0 {
            self.indent = config.first_line_indent;
        }
    }

    /// 创建标题段落
    pub fn heading(text: String, level: u8) -> Self {
        Self {
            spans: vec![RichTextSpan::Styled(SpanStyle::Bold, RichTextSpanData {
                text,
                font_size: None,
                color: None,
            })],
            is_heading: true,
            heading_level: level,
            ..Default::default()
        }
    }

    /// 创建图片段落（含图片数据）
    pub fn image(data: Vec<u8>, alt: String) -> Self {
        Self {
            spans: Vec::new(),
            is_image: true,
            image_data: data,
            image_alt: Some(alt),
            ..Default::default()
        }
    }

    /// 创建图片占位符段落（仅有路径）
    pub fn image_placeholder(src: String, alt: String) -> Self {
        Self {
            is_image: true,
            image_src: Some(src),
            image_alt: Some(alt),
            ..Default::default()
        }
    }

    /// 获取段落的完整纯文本
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text()).collect()
    }
}

// ==================== 样式枚举 ====================

/// 文本样式
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum SpanStyle {
    /// 普通文本
    Plain,
    /// 粗体
    Bold,
    /// 斜体
    Italic,
    /// 粗斜体
    BoldItalic,
    /// 下划线
    Underline,
    /// 删除线
    Strikethrough,
    /// 代码
    Code,
}

// ==================== 富文本段数据 ====================

/// 富文本段的公共数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct RichTextSpanData {
    /// 文本内容
    pub text: String,
    /// 字体大小
    pub font_size: Option<f32>,
    /// 颜色
    pub color: Option<String>,
}

// ==================== 富文本段 ====================

/// 富文本段
/// 表示段落中的一个连续文本片段，带有格式
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub enum RichTextSpan {
    /// 带样式的文本段
    Styled(SpanStyle, RichTextSpanData),
    /// 链接
    Link {
        data: RichTextSpanData,
        url: String,
    },
}

impl RichTextSpan {
    /// 获取文本内容
    pub fn text(&self) -> &str {
        match self {
            Self::Styled(_, data) => &data.text,
            Self::Link { data, .. } => &data.text,
        }
    }

    /// 判断是否为普通文本
    pub fn is_plain(&self) -> bool {
        matches!(self, Self::Styled(SpanStyle::Plain, _))
    }

    /// 应用 CSS 样式（字体大小、颜色）
    pub fn with_css(self, font_size: Option<f32>, color: Option<String>) -> Self {
        match self {
            Self::Styled(style, data) => Self::Styled(style, RichTextSpanData {
                text: data.text,
                font_size,
                color,
            }),
            Self::Link { data, url } => Self::Link {
                data: RichTextSpanData { text: data.text, font_size, color },
                url,
            },
        }
    }

    /// 获取字体大小
    pub fn font_size(&self) -> Option<f32> {
        match self {
            Self::Styled(_, data) | Self::Link { data, .. } => data.font_size,
        }
    }

    /// 设置字体大小
    pub fn set_font_size(&mut self, fs: Option<f32>) {
        match self {
            Self::Styled(_, data) | Self::Link { data, .. } => data.font_size = fs,
        }
    }
}

// ==================== 富文本章节内容 ====================

/// 富文本章节内容
/// 包含章节的所有段落
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct RichChapterContent {
    /// 章节 ID
    pub chapter_id: String,
    /// 段落列表
    pub paragraphs: Vec<RichParagraph>,
    /// 总字符数
    pub total_characters: i64,
}

impl RichChapterContent {
    /// 将章节内容转换为纯文本
    pub fn to_plain_text(&self) -> String {
        self.paragraphs
            .iter()
            .map(|p| p.full_text())
            .collect::<Vec<_>>()
            .join("\n\n")
    }
}
