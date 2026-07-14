// ============================================================
// 文件作用：富文本结构定义
//
// 公有类型/函数：
//   - struct RichParagraph — 富文本段落（spans + 段落属性）
//   - enum SpanStyle — 文本样式（Plain / Bold / Italic）
//   - struct RichTextSpanData — 富文本段的文本数据
//   - enum RichTextSpan — 富文本段（Styled | Link）
// ============================================================

use serde::{Deserialize, Serialize};

// ==================== 富文本段落 ====================

/// 富文本段落
/// 包含多个文本段（spans）和段落属性
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
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
    /// CSS 块上边距（em）
    pub margin_top_em: Option<f32>,
    /// CSS 块下边距（em）
    pub margin_bottom_em: Option<f32>,
    /// CSS text-indent（em）；`None` 表示未指定
    pub text_indent_em: Option<f32>,
    /// CSS font-size（px）；`None` 表示未指定，回退到 TypesetConfig。
    pub font_size: Option<f32>,
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
            spans: vec![RichTextSpan::Styled(
                SpanStyle::Plain,
                RichTextSpanData { text },
            )],
            indent,
            ..Default::default()
        }
    }

    /// 创建标题段落
    pub fn heading(text: String, level: u8) -> Self {
        Self {
            spans: vec![RichTextSpan::Styled(
                SpanStyle::Bold,
                RichTextSpanData { text },
            )],
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
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode,
)]
pub enum SpanStyle {
    /// 普通文本
    Plain,
    /// 粗体
    Bold,
    /// 斜体
    Italic,
}

// ==================== 富文本段数据 ====================

/// 富文本段的公共数据
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
pub struct RichTextSpanData {
    /// 文本内容
    pub text: String,
}

// ==================== 富文本段 ====================

/// 富文本段
/// 表示段落中的一个连续文本片段，带有格式
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
pub enum RichTextSpan {
    /// 带样式的文本段
    Styled(SpanStyle, RichTextSpanData),
    /// 链接
    Link { data: RichTextSpanData, url: String },
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
}

// ==================== 富文本章节内容 ====================
