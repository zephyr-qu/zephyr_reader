// ============================================================
// 文件作用：EPUB 解析中间产物 RichParagraph 类型定义
//
// 公有类型/函数：
//   - RichParagraph — 富文本段落 struct + full_text / image_placeholder
// ============================================================

//! EPUB 富文本段落类型定义
//! 表示 HTML 中一个 `<p>` 或 `<div>` 块级元素的解析结果

use crate::pipeline::ReaderInlineRun;

/// EPUB 解析中间产物：富文本段落
///
/// 表示 HTML 中一个 `<p>` 或 `<div>` 块级元素的解析结果。
/// 含内联 span、CSS 样式和图片占位信息。
/// 最终被折叠为 `ReaderIrBlock`。
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, Default)]
pub struct RichParagraph {
    pub spans: Vec<ReaderInlineRun>,
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
        self.spans.iter().map(|s| s.text.as_str()).collect()
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
