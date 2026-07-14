// ============================================================
// 文件作用：富文本解析，将 HTML 解析为富文本段落列表
//
// 公有类型/函数：
//   - parse_html_to_rich_text() — HTML → RichParagraph 列表
//
// 私有类型：
//   - ComputedStyle — CSS 计算后样式
//
// 私有函数：
//   - traverse_dom() — DOM 树遍历
//   - collect_text_spans() / collect_plain_text() — 文本收集
//   - walk_paragraph_children() / walk_inline_subtree() — DOM 递归
//   - extract_inline_css_style() / apply_inline_style() — 内联样式处理
//   - get_class_name() / get_attribute() — HTML 属性提取
// ============================================================

//! 富文本解析
//! 解析 HTML 内容为富文本段落列表，支持内联 CSS 样式提取和图片占位

use crate::domain::{AppError, RichParagraph, RichTextSpan, RichTextSpanData, SpanStyle};
use crate::parser::epub::css;
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use html5ever::Attribute;
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
        .map_err(|e| AppError::EpubParseError {
            reason: format!("HTML parse failed: {}", e),
        })?;

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

/// CSS 属性白名单 — ADR-015 精简后仅保留影响块级布局的属性。
/// `font-family`/`line-height`/`color`/`text-decoration` 已在解析层丢弃。
#[derive(Debug, Clone, Default)]
struct ComputedStyle {
    font_size: Option<f32>,
    text_align: Option<String>,
    font_weight: Option<i32>,
    font_style: Option<String>,
    text_indent_em: Option<f32>,
    margin_top_em: Option<f32>,
    margin_bottom_em: Option<f32>,
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
            "text-align" => {
                let v = value.trim().to_lowercase();
                if matches!(v.as_str(), "left" | "center" | "right" | "justify") {
                    self.text_align = Some(v);
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
            "text-indent" => {
                let parent_px = self.font_size.unwrap_or(16.0);
                if let Some(em) = css::resolve_length_to_em(value, parent_px) {
                    self.text_indent_em = Some(em);
                }
            }
            "margin-top" => {
                let parent_px = self.font_size.unwrap_or(16.0);
                if let Some(em) = css::resolve_length_to_em(value, parent_px) {
                    self.margin_top_em = Some(em);
                }
            }
            "margin-bottom" => {
                let parent_px = self.font_size.unwrap_or(16.0);
                if let Some(em) = css::resolve_length_to_em(value, parent_px) {
                    self.margin_bottom_em = Some(em);
                }
            }
            _ => {
                tracing::trace!(
                    target: "epub.css.whitelist",
                    "dropped unsupported CSS: {}={}",
                    name,
                    value,
                );
            }
        }
    }
}

/// 构建段落对象的辅助函数，填充不随标签变动的固定字段。
fn build_paragraph(
    spans: Vec<RichTextSpan>,
    indent: u8,
    is_heading: bool,
    heading_level: u8,
    class_name: Option<String>,
    text_align: Option<String>,
    margin_top_em: Option<f32>,
    margin_bottom_em: Option<f32>,
    text_indent_em: Option<f32>,
    font_size: Option<f32>,
) -> RichParagraph {
    RichParagraph {
        spans,
        indent,
        is_heading,
        heading_level,
        class_name,
        text_align,
        margin_top_em,
        margin_bottom_em,
        text_indent_em,
        font_size,
        ..Default::default()
    }
}

/// 块级容器（如 `<p>`）内联内容：文本段与 `<img>` 按 DOM 顺序拆成多个 [`RichParagraph`]。
fn walk_paragraph_children(
    handle: &Handle,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>,
    parent_style: &ComputedStyle,
    style_map: &HashMap<String, Vec<css::CssRule>>,
) {
    let mut spans: Vec<RichTextSpan> = Vec::new();

    for child in handle.children.borrow().iter() {
        if try_emit_image_paragraph(
            child,
            &mut spans,
            paragraphs,
            inherited_class.clone(),
            parent_style,
        ) {
            continue;
        }
        if let NodeData::Element { ref name, .. } = child.data {
            match name.local.as_ref() {
                "br" => {
                    spans.push(RichTextSpan::Styled(
                        SpanStyle::Plain,
                        RichTextSpanData {
                            text: "\n".to_string(),
                        },
                    ));
                }
                "p" | "div" | "section" | "article" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6"
                | "ul" | "ol" | "li" | "blockquote" | "table" | "pre" => {
                    flush_text_paragraph(
                        &mut spans,
                        paragraphs,
                        inherited_class.clone(),
                        parent_style,
                    );
                    traverse_dom(
                        child,
                        paragraphs,
                        inherited_class.clone(),
                        parent_style,
                        style_map,
                    );
                }
                _ => {
                    walk_inline_subtree(
                        child,
                        &mut spans,
                        paragraphs,
                        inherited_class.clone(),
                        parent_style,
                        style_map,
                    );
                }
            }
        } else if let NodeData::Text { .. } = child.data {
            walk_inline_subtree(
                child,
                &mut spans,
                paragraphs,
                inherited_class.clone(),
                parent_style,
                style_map,
            );
        }
    }

    flush_text_paragraph(&mut spans, paragraphs, inherited_class, parent_style);
}

/// `<p>` 内任意深度行内子树（含 `<span><img/></span>`）。
fn walk_inline_subtree(
    handle: &Handle,
    spans: &mut Vec<RichTextSpan>,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>,
    parent_style: &ComputedStyle,
    style_map: &HashMap<String, Vec<css::CssRule>>,
) {
    if try_emit_image_paragraph(
        handle,
        spans,
        paragraphs,
        inherited_class.clone(),
        parent_style,
    ) {
        return;
    }

    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = handle.data
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
            "br" => {
                spans.push(RichTextSpan::Styled(
                    SpanStyle::Plain,
                    RichTextSpanData {
                        text: "\n".to_string(),
                    },
                ));
            }
            "b" | "strong" | "i" | "em" | "u" | "s" | "strike" | "del" | "code" | "a" | "span" => {
                collect_text_spans(handle, spans, parent_style, style_map);
            }
            "p" | "div" | "section" | "article" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6"
            | "ul" | "ol" | "li" | "blockquote" | "table" | "pre" => {
                flush_text_paragraph(spans, paragraphs, inherited_class.clone(), parent_style);
                traverse_dom(handle, paragraphs, inherited_class, parent_style, style_map);
            }
            _ => {
                for child in handle.children.borrow().iter() {
                    walk_inline_subtree(
                        child,
                        spans,
                        paragraphs,
                        inherited_class.clone(),
                        &merged_style,
                        style_map,
                    );
                }
            }
        }
    } else if let NodeData::Text { ref contents } = handle.data {
        let text = contents.borrow().to_string();
        if !text.is_empty() {
            push_styled_text_span(spans, text, parent_style);
        }
    }
}

/// 将 CSS 计算样式映射为行内 [SpanStyle]（`<span style="font-weight:bold">` 等）。
fn span_style_from_computed(style: &ComputedStyle) -> SpanStyle {
    if style.font_weight.unwrap_or(400) >= 700 {
        return SpanStyle::Bold;
    }
    if style.font_style.as_deref() == Some("italic") {
        return SpanStyle::Italic;
    }
    SpanStyle::Plain
}

fn push_styled_text_span(spans: &mut Vec<RichTextSpan>, text: String, style: &ComputedStyle) {
    if text.is_empty() {
        return;
    }
    spans.push(RichTextSpan::Styled(
        span_style_from_computed(style),
        RichTextSpanData { text },
    ));
}

fn paragraph_indent_chars(style: &ComputedStyle) -> u8 {
    if let Some(em) = style.text_indent_em {
        return em.round().clamp(0.0, 12.0) as u8;
    }
    2
}

fn flush_text_paragraph(
    spans: &mut Vec<RichTextSpan>,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>,
    parent_style: &ComputedStyle,
) {
    if spans.is_empty() {
        return;
    }
    paragraphs.push(build_paragraph(
        std::mem::take(spans),
        paragraph_indent_chars(parent_style),
        false,
        0,
        inherited_class,
        parent_style.text_align.clone(),
        parent_style.margin_top_em,
        parent_style.margin_bottom_em,
        parent_style.text_indent_em,
        parent_style.font_size,
    ));
}

fn try_emit_image_paragraph(
    handle: &Handle,
    spans: &mut Vec<RichTextSpan>,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>,
    parent_style: &ComputedStyle,
) -> bool {
    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = handle.data
    {
        if name.local.as_ref() != "img" {
            return false;
        }
        flush_text_paragraph(spans, paragraphs, inherited_class, parent_style);
        let src = get_attribute(attrs, "src").unwrap_or_default();
        let alt = get_attribute(attrs, "alt").unwrap_or_default();
        paragraphs.push(RichParagraph::image_placeholder(src, alt));
        return true;
    }
    false
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
                    traverse_dom(
                        child,
                        paragraphs,
                        effective_class.clone(),
                        &merged_style,
                        style_map,
                    );
                }
            }

            "p" => {
                walk_paragraph_children(
                    handle,
                    paragraphs,
                    if current_class.is_empty() {
                        inherited_class
                    } else {
                        Some(current_class)
                    },
                    &merged_style,
                    style_map,
                );
            }

            "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
                let level = name.local.as_ref()[1..].parse::<u8>().unwrap_or(1);

                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans, &merged_style, style_map);

                // Build heading font size from level if not overridden by CSS
                if !spans.is_empty() {
                    paragraphs.push(build_paragraph(
                        spans,
                        0,
                        true,
                        level,
                        if current_class.is_empty() {
                            inherited_class
                        } else {
                            Some(current_class)
                        },
                        merged_style.text_align.clone().or(Some("left".to_string())),
                        merged_style.margin_top_em,
                        merged_style.margin_bottom_em,
                        Some(0.0),
                        merged_style.font_size,
                    ));
                }
            }

            "li" => {
                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans, &merged_style, style_map);

                if !spans.is_empty() {
                    spans.insert(
                        0,
                        RichTextSpan::Styled(
                            SpanStyle::Plain,
                            RichTextSpanData {
                                text: "• ".to_string(),
                            },
                        ),
                    );

                    paragraphs.push(build_paragraph(
                        spans,
                        0,
                        false,
                        0,
                        if current_class.is_empty() {
                            inherited_class
                        } else {
                            Some(current_class)
                        },
                        merged_style.text_align.clone(),
                        merged_style.margin_top_em,
                        merged_style.margin_bottom_em,
                        merged_style.text_indent_em,
                        merged_style.font_size,
                    ));
                }
            }

            _ => {
                tracing::trace!(
                    target: "epub.malformed",
                    "traverse_dom: unknown block tag <{}> — content traversed as inline",
                    name.local.as_ref(),
                );
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
                    spans.push(RichTextSpan::Styled(
                        SpanStyle::Bold,
                        RichTextSpanData {
                            text: inner_text.trim().to_string(),
                        },
                    ));
                }
            }

            "i" | "em" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(
                        SpanStyle::Italic,
                        RichTextSpanData {
                            text: inner_text.trim().to_string(),
                        },
                    ));
                }
            }

            "u" | "s" | "strike" | "del" | "code" => {
                // 降级为 Plain：Underline/Strikethrough/Code 在移动端阅读中极少使用
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Styled(
                        SpanStyle::Plain,
                        RichTextSpanData {
                            text: inner_text.trim().to_string(),
                        },
                    ));
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
                        },
                        url: href,
                    });
                }
            }

            "br" => {
                spans.push(RichTextSpan::Styled(
                    SpanStyle::Plain,
                    RichTextSpanData {
                        text: "\n".to_string(),
                    },
                ));
            }

            "span" => {
                for child in node.children.borrow().iter() {
                    collect_text_spans(child, spans, &merged_style, style_map);
                }
            }

            "img" => {
                tracing::trace!(
                    target: "epub.malformed",
                    "collect_text_spans: img discarded in inline context (known <span><img> gap)",
                );
            }

            "ul" | "ol" | "blockquote" | "pre" | "table" => {
                tracing::trace!(
                    target: "epub.malformed",
                    "collect_text_spans: {} silently skipped in inline context",
                    name.local.as_ref(),
                );
            }
            "div" | "section" | "article" | "p" | "li" | "h1" | "h2" | "h3" | "h4" | "h5"
            | "h6" => {
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
        if !text.is_empty() {
            push_styled_text_span(spans, text, parent_style);
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
    fn test_parse_html_img_inside_paragraph() {
        let html = "<p>before<img src=\"inline.jpg\" alt=\"inline\"/>after</p>";
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(
            result.len(),
            3,
            "expected text + image + text, got {result:?}"
        );
        assert!(!result[0].is_image);
        assert!(result[0].full_text().contains("before"));
        assert!(result[1].is_image);
        assert_eq!(result[1].image_src.as_deref(), Some("inline.jpg"));
        assert!(!result[2].is_image);
        assert!(result[2].full_text().contains("after"));
    }

    #[test]
    fn test_parse_html_img_inside_span_in_paragraph() {
        let html = "<p>see <span><img src=\"nested.jpg\" alt=\"n\"/></span> end</p>";
        let result = parse_html_to_rich_text(html).unwrap();
        assert!(
            result
                .iter()
                .any(|p| p.is_image && p.image_src.as_deref() == Some("nested.jpg")),
            "nested img should produce image paragraph: {result:?}"
        );
    }

    #[test]
    fn test_parse_html_css_font_weight_on_span() {
        let html = r#"<p><span style="font-weight: bold">bold</span> plain</p>"#;
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(result.len(), 1);
        assert!(result[0]
            .spans
            .iter()
            .any(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _))));
    }

    #[test]
    fn test_parse_html_css_font_style_italic_on_span() {
        let html = r#"<p><span style="font-style: italic">em</span></p>"#;
        let result = parse_html_to_rich_text(html).unwrap();
        assert_eq!(result.len(), 1);
        assert!(result[0]
            .spans
            .iter()
            .any(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Italic, _))));
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

    #[test]
    fn test_malformed_html_unclosed_tag_still_parses() {
        // 未闭合的 <p> — html5ever 应该容错解析，不返回错误。
        let html = "<p>unclosed paragraph";
        let result = parse_html_to_rich_text(html);
        assert!(
            result.is_ok(),
            "html5ever should tolerate unclosed tags: {result:?}"
        );
    }

    #[test]
    fn test_malformed_html_invalid_nesting_still_parses() {
        // 非法嵌套 — html5ever 自动修复
        let html = "<p>text <b>bold <i>both</b> only bold</i> end</p>";
        let result = parse_html_to_rich_text(html);
        assert!(
            result.is_ok(),
            "html5ever should auto-repair invalid nesting: {result:?}"
        );
    }
}
