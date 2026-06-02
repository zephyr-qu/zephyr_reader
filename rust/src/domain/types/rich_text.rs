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
#[derive(Debug, Clone, Serialize, Deserialize)]
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
            spans: vec![RichTextSpan::Plain {
                text,
                font_size: None,
                color: None,
            }],
            indent,
            is_heading: false,
            heading_level: 0,
            class_name: None,
            text_align: None,
            line_height: None,
            is_image: false,
            image_src: None,
            image_data: Vec::new(),
            image_alt: None,
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
            spans: vec![RichTextSpan::Bold {
                text,
                font_size: None,
                color: None,
            }],
            indent: 0,
            is_heading: true,
            heading_level: level,
            class_name: None,
            text_align: None,
            line_height: None,
            is_image: false,
            image_src: None,
            image_data: Vec::new(),
            image_alt: None,
        }
    }

    /// 创建图片段落（含图片数据）
    pub fn image(data: Vec<u8>, alt: String) -> Self {
        Self {
            spans: Vec::new(),
            indent: 0,
            is_heading: false,
            heading_level: 0,
            class_name: None,
            text_align: None,
            line_height: None,
            is_image: true,
            image_src: None,
            image_data: data,
            image_alt: Some(alt),
        }
    }

    /// 创建图片占位符段落（仅有路径）
    pub fn image_placeholder(src: String, alt: String) -> Self {
        Self {
            spans: Vec::new(),
            indent: 0,
            is_heading: false,
            heading_level: 0,
            class_name: None,
            text_align: None,
            line_height: None,
            is_image: true,
            image_src: Some(src),
            image_data: Vec::new(),
            image_alt: Some(alt),
        }
    }

    /// 获取段落的完整纯文本
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text()).collect()
    }
}

// ==================== 富文本段 ====================

/// 富文本段
/// 表示段落中的一个连续文本片段，带有格式
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub enum RichTextSpan {
    /// 普通文本
    Plain {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 粗体
    Bold {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 斜体
    Italic {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 粗斜体
    BoldItalic {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 下划线
    Underline {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 删除线
    Strikethrough {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 代码
    Code {
        text: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
    /// 链接
    Link {
        text: String,
        url: String,
        font_size: Option<f32>,
        color: Option<String>,
    },
}

impl RichTextSpan {
    /// 获取文本内容
    pub fn text(&self) -> &str {
        match self {
            Self::Plain { text, .. } => text,
            Self::Bold { text, .. } => text,
            Self::Italic { text, .. } => text,
            Self::BoldItalic { text, .. } => text,
            Self::Underline { text, .. } => text,
            Self::Strikethrough { text, .. } => text,
            Self::Code { text, .. } => text,
            Self::Link { text, .. } => text,
        }
    }

    /// 判断是否为普通文本
    pub fn is_plain(&self) -> bool {
        matches!(self, Self::Plain { .. })
    }

    /// 应用 CSS 样式（字体大小、颜色）
    pub fn with_css(self, font_size: Option<f32>, color: Option<String>) -> Self {
        match self {
            Self::Plain { text, .. } => Self::Plain {
                text,
                font_size,
                color,
            },
            Self::Bold { text, .. } => Self::Bold {
                text,
                font_size,
                color,
            },
            Self::Italic { text, .. } => Self::Italic {
                text,
                font_size,
                color,
            },
            Self::BoldItalic { text, .. } => Self::BoldItalic {
                text,
                font_size,
                color,
            },
            Self::Underline { text, .. } => Self::Underline {
                text,
                font_size,
                color,
            },
            Self::Strikethrough { text, .. } => Self::Strikethrough {
                text,
                font_size,
                color,
            },
            Self::Code { text, .. } => Self::Code {
                text,
                font_size,
                color,
            },
            Self::Link { text, url, .. } => Self::Link {
                text,
                url,
                font_size,
                color,
            },
        }
    }

    /// 获取字体大小
    pub fn font_size(&self) -> Option<f32> {
        match self {
            Self::Plain { font_size, .. } => *font_size,
            Self::Bold { font_size, .. } => *font_size,
            Self::Italic { font_size, .. } => *font_size,
            Self::BoldItalic { font_size, .. } => *font_size,
            Self::Underline { font_size, .. } => *font_size,
            Self::Strikethrough { font_size, .. } => *font_size,
            Self::Code { font_size, .. } => *font_size,
            Self::Link { font_size, .. } => *font_size,
        }
    }

    /// 设置字体大小
    pub fn set_font_size(&mut self, fs: Option<f32>) {
        match self {
            Self::Plain { font_size, .. } => *font_size = fs,
            Self::Bold { font_size, .. } => *font_size = fs,
            Self::Italic { font_size, .. } => *font_size = fs,
            Self::BoldItalic { font_size, .. } => *font_size = fs,
            Self::Underline { font_size, .. } => *font_size = fs,
            Self::Strikethrough { font_size, .. } => *font_size = fs,
            Self::Code { font_size, .. } => *font_size = fs,
            Self::Link { font_size, .. } => *font_size = fs,
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
