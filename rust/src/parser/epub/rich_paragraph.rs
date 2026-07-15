//! 富文本段落（EPUB HTML → IR 中间类型）
//!
//! 仅在 EPUB 解析过程中使用，不跨 FFI。
//! 由 `rich_text.rs::parse_html_to_rich_text()` 产出，
//! 由 `content_ir.rs::chapter_ir_from_rich_paragraphs()` 消费并转换为 `ChapterContentIr`。

use crate::pipeline::RichTextSpan;

/// EPUB 解析中间产物：富文本段落
///
/// 表示 HTML 中一个 `<p>` 或 `<div>` 块级元素的解析结果。
/// 含内联 span、CSS 样式和图片占位信息。
/// 最终被折叠为 `ContentBlock`。
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, Default)]
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
    /// 连接所有 span 的文本内容
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text()).collect()
    }

    /// 构造图片占位段落
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
