// ============================================================
// 文件作用：富文本样式计算，包含 CSS 计算后样式（ComputedStyle）
//           和内联 CSS 解析、HTML 属性提取等辅助函数。
//
// 公有类型/函数：
//   - ComputedStyle — CSS 计算后样式 struct + root/derive/apply_declaration
//   - span_style_from_computed() — CSS → ReaderInlineStyle
//   - push_styled_text_span() — 添加带样式的文本 span
//   - paragraph_indent_chars() — text-indent → 首行缩进字符数
//   - extract_inline_css_style() — style="..." 属性解析
//   - apply_inline_style() — 内联样式合并到基础样式
//   - get_class_name() / get_attribute() — HTML 属性提取
// ============================================================

//! 富文本样式计算
//! 解析和计算 CSS 样式，供 rich_parser 使用

use crate::parser::epub::css;
use crate::pipeline::{ReaderInlineRun, ReaderInlineStyle};
use html5ever::Attribute;
use std::cell::RefCell;
use std::collections::HashMap;

/// CSS 属性白名单 — ADR-015 精简后仅保留影响块级布局的属性。
/// `font-family`/`line-height`/`color`/`text-decoration` 已在解析层丢弃。
#[derive(Debug, Clone, Default)]
pub struct ComputedStyle {
    pub font_size: Option<f32>,
    pub text_align: Option<String>,
    pub font_weight: Option<i32>,
    pub font_style: Option<String>,
    pub text_indent_em: Option<f32>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
}

impl ComputedStyle {
    pub fn root() -> Self {
        Self {
            font_size: Some(16.0),
            ..Default::default()
        }
    }

    pub fn derive(
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

/// 将 CSS 计算样式映射为行内 SpanStyle（`<span style="font-weight:bold">` 等）。
pub fn span_style_from_computed(style: &ComputedStyle) -> ReaderInlineStyle {
    if style.font_weight.unwrap_or(400) >= 700 {
        return ReaderInlineStyle::Bold;
    }
    if style.font_style.as_deref() == Some("italic") {
        return ReaderInlineStyle::Italic;
    }
    ReaderInlineStyle::Plain
}

pub fn push_styled_text_span(
    spans: &mut Vec<ReaderInlineRun>,
    text: String,
    style: &ComputedStyle,
) {
    if text.is_empty() {
        return;
    }
    spans.push(ReaderInlineRun {
        text,
        style: span_style_from_computed(style),
        url: None,
    });
}

pub fn paragraph_indent_chars(style: &ComputedStyle) -> u8 {
    if let Some(em) = style.text_indent_em {
        return em.round().clamp(0.0, 12.0) as u8;
    }
    2
}

/// 从 HTML 元素属性中提取内联 CSS 样式
///
/// 解析 `style` 属性中的声明（如 `"color: red; font-size: 16px"`），
/// 返回属性名到属性值的映射表
pub fn extract_inline_css_style(attrs: &RefCell<Vec<Attribute>>) -> HashMap<String, String> {
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
pub fn apply_inline_style(base: &ComputedStyle, inline: &HashMap<String, String>) -> ComputedStyle {
    let mut s = base.clone();
    for (name, value) in inline {
        s.apply_declaration(name, value);
    }
    s
}

/// 获取 class 属性
pub fn get_class_name(attrs: &RefCell<Vec<Attribute>>) -> String {
    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == "class" {
            return attr.value.as_ref().to_string();
        }
    }
    String::new()
}

/// 获取指定属性
pub fn get_attribute(attrs: &RefCell<Vec<Attribute>>, name: &str) -> Option<String> {
    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == name {
            return Some(attr.value.as_ref().to_string());
        }
    }
    None
}
