//! 富文本解析
//! 解析 HTML 内容为富文本段落列表，支持内联 CSS 样式提取和图片占位

use crate::domain::{AppError, RichParagraph, RichTextSpan, RichTextSpanData, SpanStyle};
use crate::text::css;
use html5ever::Attribute;
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use std::cell::RefCell;
use std::collections::HashMap;

/// 解析 HTML 内容为富文本段落列表（自动提取内联 CSS 和图片占位）
pub fn parse_html_to_rich_text(html_content: &str) -> Result<Vec<RichParagraph>, AppError> {
    tracing::debug!(
        "[parse_html_to_rich_text] HTML input: {} bytes",
        html_content.len()
    );

    // 1. 提取并解析内联 CSS
    let css_text = css::extract_inline_css(html_content);
    let css_rules = if !css_text.is_empty() {
        css::parse_css(&css_text)
    } else {
        Vec::new()
    };
    let style_map = css::build_style_map(&css_rules);
    tracing::debug!(
        "[parse_html_to_rich_text] CSS: extracted {} rules from <style>",
        css_rules.len()
    );

    // 2. 解析 HTML
    let dom = parse_document(RcDom::default(), Default::default())
        .from_utf8()
        .read_from(&mut html_content.as_bytes())
        .map_err(|e| AppError::epub_parse_error(format!("HTML parse failed: {}", e)))?;

    let mut paragraphs = Vec::new();

    traverse_dom(
        &dom.document,
        &mut paragraphs,
        None,
        &ComputedStyle::root(),
        &style_map,
    );

    tracing::debug!(
        "[parse_html_to_rich_text] parse result: {} paragraphs",
        paragraphs.len()
    );
    for (i, p) in paragraphs.iter().enumerate().take(5) {
        if p.is_image {
            tracing::debug!(
                "[parse_html_to_rich_text]   paragraph[{i}]: IMAGE alt={:?} src={:?} size={}",
                p.image_alt,
                p.image_src,
                p.image_data.len()
            );
        } else {
            let text = p.full_text();
            tracing::debug!(
                "[parse_html_to_rich_text]   paragraph[{i}]: spans={}, heading={}, align={:?}, text={:?}",
                p.spans.len(),
                p.is_heading,
                p.text_align,
                &text.chars().take(60).collect::<String>()
            );
        }
    }

    Ok(paragraphs)
}

#[derive(Debug, Clone, Default)]
/// 计算后的样式表
///
/// 存储解析后的字体大小、颜色、字体系列、对齐方式、行高、字重、字体样式、文本修饰等 CSS 属性
struct ComputedStyle {
    font_size: Option<f32>,
    color: Option<String>,
    font_family: Option<String>,
    text_align: Option<String>,
    line_height: Option<f32>,
    font_weight: Option<i32>,
    font_style: Option<String>,
    text_decoration: Option<String>,
}

impl ComputedStyle {
    fn root() -> Self {
        Self {
            font_size: Some(16.0),
            ..Default::default()
        }
    }

    fn derive(
        &self,
        tag: &str,
        classes: &[String],
        style_map: &HashMap<String, Vec<css::CssRule>>,
    ) -> Self {
        let mut s = self.clone();

        for class in classes {
            if let Some(rules) = style_map.get(&format!(".{class}")) {
                s.apply_rules(rules);
            }
            if let Some(rules) = style_map.get(&format!("{tag}.{class}")) {
                s.apply_rules(rules);
            }
        }
        if let Some(rules) = style_map.get(tag) {
            s.apply_rules(rules);
        }

        s
    }

    fn apply_rules(&mut self, rules: &[css::CssRule]) {
        for rule in rules {
            for (name, value) in &rule.declarations {
                self.apply_declaration(name, value);
            }
        }
    }

    fn apply_declaration(&mut self, name: &str, value: &str) {
        let parent_px = self.font_size.unwrap_or(16.0);
        match name {
            "font-size" => {
                if let Some(px) = css::resolve_font_size(value, parent_px) {
                    self.font_size = Some(px);
                }
            }
            "color" => {
                if let Some(c) = css::resolve_color(value) {
                    self.color = Some(c);
                }
            }
            "font-family" => {
                let clean = value
                    .trim_matches(|c: char| c == '\'' || c == '"' || c == ' ')
                    .to_string();
                if !clean.is_empty() && clean != "serif" && clean != "sans-serif" {
                    self.font_family = Some(clean);
                }
            }
            "text-align" => {
                let v = value.trim().to_lowercase();
                if matches!(v.as_str(), "left" | "center" | "right" | "justify") {
                    self.text_align = Some(v);
                }
            }
            "line-height" => {
                if let Some(lh) = css::resolve_float(value, parent_px) {
                    self.line_height = Some(lh);
                }
            }
            "font-weight" => {
                let v = value.trim();
                if let Ok(n) = v.parse::<i32>() {
                    self.font_weight = Some(n);
                } else if v == "bold" {
                    self.font_weight = Some(700);
                } else if v == "normal" {
                    self.font_weight = Some(400);
                }
            }
            "font-style" => {
                let v = value.trim().to_lowercase();
                if v == "italic" || v == "normal" {
                    self.font_style = Some(v);
                }
            }
            "text-decoration" => {
                let v = value.trim().to_lowercase();
                if v.contains("underline") || v.contains("line-through") {
                    self.text_decoration = Some(v);
                }
            }
            _ => {}
        }
    }
}

/// 遍历 DOM 树
fn traverse_dom(
    handle: &Handle,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>,
    style: &ComputedStyle,
    style_map: &HashMap<String, Vec<css::CssRule>>,
) {
    let node = handle;

    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = node.data
    {
        let current_class = get_class_name(attrs);
        let classes: Vec<String> = current_class
            .split_whitespace()
            .map(|s| s.to_string())
            .collect();

        let effective_class = if !current_class.is_empty() {
            Some(current_class.clone())
        } else {
            inherited_class.clone()
        };

        let el_style = style.derive(name.local.as_ref(), &classes, style_map);
        let inline_style = extract_inline_css_style(attrs);
        let merged_style = apply_inline_style(&el_style, &inline_style);

        match name.local.as_ref() {
            "img" => {
                let src = get_attribute(attrs, "src").unwrap_or_default();
                let alt = get_attribute(attrs, "alt").unwrap_or_default();
                paragraphs.push(RichParagraph::image_placeholder(src, alt));
            }

            "div" | "section" | "article" => {
                for child in node.children.borrow().iter() {
                    traverse_dom(child, paragraphs, effective_class.clone(), &merged_style, style_map);
                }
            }

            "p" => {
                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans, &merged_style, style_map);
                if !spans.is_empty() {
                    paragraphs.push(RichParagraph {
                        spans,
                        indent: 2,
                        is_heading: false,
                        heading_level: 0,
                        class_name: if current_class.is_empty() {
                            inherited_class
                        } else {
                            Some(current_class)
                        },
                        text_align: merged_style.text_align.clone(),
                        line_height: merged_style.line_height,
                        is_image: false,
                        image_src: None,
                        image_data: Vec::new(),
                        image_alt: None,
                    });
                }
            }

            "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
                let level = name.local.as_ref()[1..].parse::<u8>().unwrap_or(1);

                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans, &merged_style, style_map);

                // Build heading font size from level if not overridden by CSS
                let heading_font_size = match merged_style.font_size {
                    Some(fs) => Some(fs),
                    None => {
                        let base: f32 = match level {
                            1 => 24.0,
                            2 => 20.0,
                            3 => 18.0,
                            4 => 16.0,
                            5 => 14.0,
                            _ => 13.0,
                        };
                        Some(base)
                    }
                };
                for span in &mut spans {
                    if span.font_size().is_none() {
                        span.set_font_size(heading_font_size);
                    }
                }

                if !spans.is_empty() {
                    paragraphs.push(RichParagraph {
                        spans,
                        indent: 0,
                        is_heading: true,
                        heading_level: level,
                        class_name: if current_class.is_empty() {
                            inherited_class
                        } else {
                            Some(current_class)
                        },
                        text_align: merged_style.text_align.clone().or(Some("left".to_string())),
                        line_height: merged_style.line_height,
                        is_image: false,
                        image_src: None,
                        image_data: Vec::new(),
                        image_alt: None,
                    });
                }

            }

            "li" => {
                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans, &merged_style, style_map);

                if !spans.is_empty() {
                    spans.insert(
                        0,
                        RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
                            text: "• ".to_string(),
                            font_size: None,
                            color: None,
                        }),
                    );

                    paragraphs.push(RichParagraph {
                        spans,
                        indent: 0,
                        is_heading: false,
                        heading_level: 0,
                        class_name: if current_class.is_empty() {
                            inherited_class
                        } else {
                            Some(current_class)
                        },
                        text_align: merged_style.text_align.clone(),
                        line_height: merged_style.line_height,
                        is_image: false,
                        image_src: None,
                        image_data: Vec::new(),
                        image_alt: None,
                    });
                }

            }

            _ => {
                for child in node.children.borrow().iter() {
                    traverse_dom(
                        child,
                        paragraphs,
                        effective_class.clone(),
                        &merged_style,
                        style_map,
                    );
                }
            }
        }
    } else {
        for child in node.children.borrow().iter() {
            traverse_dom(child, paragraphs, inherited_class.clone(), style, style_map);
        }
    }
}

/// 收集文本片段（保留样式 + 内联 CSS）
fn collect_text_spans(
    handle: &Handle,
    spans: &mut Vec<RichTextSpan>,
    parent_style: &ComputedStyle,
    style_map: &HashMap<String, Vec<css::CssRule>>,
) {
    let node = handle;

    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = node.data
    {
        let current_class = get_class_name(attrs);
        let classes: Vec<String> = current_class
            .split_whitespace()
            .map(|s| s.to_string())
            .collect();
        let el_style = parent_style.derive(name.local.as_ref(), &classes, style_map);
        let inline_style = extract_inline_css_style(attrs);
        let merged_style = apply_inline_style(&el_style, &inline_style);

        match name.local.as_ref() {
            "b" | "strong" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(SpanStyle::Bold, RichTextSpanData {
                        text: inner_text.trim().to_string(),
                        font_size: merged_style.font_size,
                        color: merged_style.color.clone(),
                    }));
                }
            }

            "i" | "em" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(SpanStyle::Italic, RichTextSpanData {
                        text: inner_text.trim().to_string(),
                        font_size: merged_style.font_size,
                        color: merged_style.color.clone(),
                    }));
                }
            }

            "u" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(SpanStyle::Underline, RichTextSpanData {
                        text: inner_text.trim().to_string(),
                        font_size: merged_style.font_size,
                        color: merged_style.color.clone(),
                    }));
                }
            }

            "s" | "strike" | "del" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(SpanStyle::Strikethrough, RichTextSpanData {
                        text: inner_text.trim().to_string(),
                        font_size: merged_style.font_size,
                        color: merged_style.color.clone(),
                    }));
                }
            }

            "code" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(SpanStyle::Code, RichTextSpanData {
                        text: inner_text.trim().to_string(),
                        font_size: merged_style.font_size,
                        color: merged_style.color.clone(),
                    }));
                }
            }

            "a" => {
                let href = get_attribute(attrs, "href").unwrap_or_default();
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Link {
                        data: RichTextSpanData {
                            text: inner_text.trim().to_string(),
                            font_size: merged_style.font_size,
                            color: merged_style.color.clone(),
                        },
                        url: href,
                    });
                }
            }

            "br" => {
                spans.push(RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
                    text: "\n".to_string(),
                    font_size: None,
                    color: None,
                }));
            }

            "span" => {
                for child in node.children.borrow().iter() {
                    collect_text_spans(child, spans, &merged_style, style_map);
                }
            }

            "img" => {}

            "ul" | "ol" | "blockquote" | "pre" | "table" => {}
            "div" | "section" | "article" | "p" | "li" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
                for child in node.children.borrow().iter() {
                    collect_text_spans(child, spans, &merged_style, style_map);
                }
            }

            _ => {
                for child in node.children.borrow().iter() {
                    collect_text_spans(child, spans, &merged_style, style_map);
                }
            }
        }
    } else if let NodeData::Text { ref contents } = node.data {
        let text = contents.borrow().to_string();
        if !text.trim().is_empty() {
            spans.push(RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
                text,
                font_size: parent_style.font_size,
                color: parent_style.color.clone(),
            }));
        }
    }
}

/// 收集纯文本（不含样式）
fn collect_plain_text(handle: &Handle, text: &mut String) {
    let node = handle;
    if let NodeData::Text { ref contents } = node.data {
        text.push_str(&contents.borrow());
    } else {
        for child in node.children.borrow().iter() {
            collect_plain_text(child, text);
        }
    }
}

/// 从 HTML 元素属性中提取内联 CSS 样式
///
/// 解析 `style` 属性中的声明（如 `"color: red; font-size: 16px"`），
/// 返回属性名到属性值的映射表
fn extract_inline_css_style(attrs: &RefCell<Vec<Attribute>>) -> HashMap<String, String> {
    let mut result = HashMap::new();
    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == "style" {
            for part in attr.value.as_ref().split(';') {
                let part = part.trim();
                if let Some(eq) = part.find(':') {
                    let name = part[..eq].trim().to_lowercase();
                    let value = part[eq + 1..].trim().to_string();
                    if !name.is_empty() {
                        result.insert(name, value);
                    }
                }
            }
        }
    }
    result
}

/// 将内联样式应用到基础样式上，返回新的计算后样式
///
/// 遍历内联样式声明并逐一调用 `apply_declaration` 合并到基础样式
fn apply_inline_style(base: &ComputedStyle, inline: &HashMap<String, String>) -> ComputedStyle {
    let mut s = base.clone();
    for (name, value) in inline {
        s.apply_declaration(name, value);
    }
    s
}

/// 获取 class 属性
fn get_class_name(attrs: &RefCell<Vec<Attribute>>) -> String {
    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == "class" {
            return attr.value.as_ref().to_string();
        }
    }
    String::new()
}

/// 获取指定属性
fn get_attribute(attrs: &RefCell<Vec<Attribute>>, name: &str) -> Option<String> {
    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == name {
            return Some(attr.value.as_ref().to_string());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_html_empty() {
        let result = parse_html_to_rich_text("");
        assert!(result.is_ok());
        let paragraphs = result.unwrap();
        assert!(paragraphs.is_empty());
    }

    #[test]
    fn test_parse_html_simple_paragraph() {
        let html = "<p>Hello World</p>";
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(result.len(), 1);
        assert!(!result[0].is_image);
        assert!(!result[0].spans.is_empty());
    }

    #[test]
    fn test_parse_html_with_img() {
        let html = "<p>text</p><img src=\"test.jpg\" alt=\"test\"/>";
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(result.len(), 2);
        assert!(result[1].is_image);
        assert_eq!(result[1].image_src.as_deref(), Some("test.jpg"));
    }

    #[test]
    fn test_parse_html_mixed_cjk_latin() {
        let html = "<p>中文 English 混合 text</p>";
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(result.len(), 1);
        let text = result[0].full_text();
        assert!(text.contains("中文"));
        assert!(text.contains("English"));
    }
}
