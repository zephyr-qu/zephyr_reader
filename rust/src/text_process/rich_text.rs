//! HTML 解析模块
//! 解析 HTML 内容并提取富文本结构

use crate::ffi::{ParserError, RichParagraph, RichTextSpan};
use html5ever::parse_document;
use html5ever::tendril::TendrilSink;
use html5ever::Attribute;
use markup5ever_rcdom::{Handle, NodeData, RcDom};
use std::cell::RefCell;

/// 解析 HTML 内容为富文本段落列表
pub fn parse_html_to_rich_text(html_content: &str) -> Result<Vec<RichParagraph>, ParserError> {
    // 解析 HTML
    let dom = parse_document(RcDom::default(), Default::default())
        .from_utf8()
        .read_from(&mut html_content.as_bytes())
        .map_err(|e| ParserError::EpubParseError(format!("HTML 解析失败: {}", e)))?;

    let mut paragraphs = Vec::new();

    // ✅ 优化：移除无用的 in_block 和 heading_depth 参数
    traverse_dom(&dom.document, &mut paragraphs, None);

    Ok(paragraphs)
}

/// 遍历 DOM 树
fn traverse_dom(
    handle: &Handle,
    paragraphs: &mut Vec<RichParagraph>,
    inherited_class: Option<String>, // 用于继承父级的 class
) {
    let node = handle;

    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = node.data
    {
        let current_class = get_class_name(attrs);

        // 决定当前节点的有效 class：如果当前节点有 class 则使用，否则继承父级
        let effective_class = if !current_class.is_empty() {
            Some(current_class.clone())
        } else {
            inherited_class.clone()
        };

        match name.local.as_ref() {
            // 块级元素 - 创建新段落
            "p" | "div" | "section" | "article" => {
                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans);

                if !spans.is_empty() {
                    paragraphs.push(RichParagraph {
                        spans,
                        indent: 2,
                        is_heading: false,
                        heading_level: 0,
                        class_name: if current_class.is_empty() {
                            inherited_class // 如果当前没 class，尝试继承
                        } else {
                            Some(current_class)
                        },
                    });
                }

                // 递归处理子节点：块级元素内部通常重新开始，或者根据需求决定是否继承
                // 这里选择重置为 None，因为 p/div 内部通常是一个新的上下文
                for child in node.children.borrow().iter() {
                    traverse_dom(child, paragraphs, None);
                }
            }

            // 标题元素
            "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
                let level = name.local.as_ref()[1..].parse::<u8>().unwrap_or(1);

                let mut text = String::new();
                collect_plain_text(handle, &mut text);

                if !text.trim().is_empty() {
                    paragraphs.push(RichParagraph::heading(text.trim().to_string(), level));
                }

                // 递归处理子节点
                for child in node.children.borrow().iter() {
                    traverse_dom(child, paragraphs, None);
                }
            }

            // 列表项
            "li" => {
                let mut spans = Vec::new();
                collect_text_spans(handle, &mut spans);

                if !spans.is_empty() {
                    // 添加列表标记
                    spans.insert(
                        0,
                        RichTextSpan::Plain {
                            text: "• ".to_string(),
                        },
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
                    });
                }

                // li 内部可能还有嵌套列表或其他结构，继续递归
                for child in node.children.borrow().iter() {
                    traverse_dom(child, paragraphs, effective_class.clone());
                }
            }

            // 其他元素（如 span, b, i 等内联元素，或 ul, ol 等容器）
            _ => {
                for child in node.children.borrow().iter() {
                    // 传递有效的 class 给子节点，以便内联元素能获取到上下文样式
                    traverse_dom(child, paragraphs, effective_class.clone());
                }
            }
        }
    } else {
        // 非元素节点（如文本节点、注释），递归处理子节点（虽然文本节点通常没有子节点）
        for child in node.children.borrow().iter() {
            traverse_dom(child, paragraphs, inherited_class.clone());
        }
    }
}

/// 收集文本片段（保留样式）
fn collect_text_spans(handle: &Handle, spans: &mut Vec<RichTextSpan>) {
    let node = handle;

    if let NodeData::Element {
        ref name,
        ref attrs,
        ..
    } = node.data
    {
        // 获取样式信息
        let style_info = get_style_info(attrs);

        match name.local.as_ref() {
            // 粗体
            "b" | "strong" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    if style_info.italic {
                        spans.push(RichTextSpan::BoldItalic {
                            text: inner_text.trim().to_string(),
                        });
                    } else {
                        spans.push(RichTextSpan::Bold {
                            text: inner_text.trim().to_string(),
                        });
                    }
                }
            }

            // 斜体
            "i" | "em" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    if style_info.bold {
                        spans.push(RichTextSpan::BoldItalic {
                            text: inner_text.trim().to_string(),
                        });
                    } else {
                        spans.push(RichTextSpan::Italic {
                            text: inner_text.trim().to_string(),
                        });
                    }
                }
            }

            // 下划线
            "u" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Underline {
                        text: inner_text.trim().to_string(),
                    });
                }
            }

            // 删除线
            "s" | "strike" | "del" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Strikethrough {
                        text: inner_text.trim().to_string(),
                    });
                }
            }

            // 行内代码
            "code" => {
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Code {
                        text: inner_text.trim().to_string(),
                    });
                }
            }

            // 超链接
            "a" => {
                let href = get_attribute(attrs, "href").unwrap_or_default();
                let mut inner_text = String::new();
                collect_plain_text(handle, &mut inner_text);

                if !inner_text.trim().is_empty() {
                    spans.push(RichTextSpan::Link {
                        text: inner_text.trim().to_string(),
                        url: href,
                    });
                }
            }

            // 换行
            "br" => {
                spans.push(RichTextSpan::Plain {
                    text: "\n".to_string(),
                });
            }

            // 其他元素 - 递归处理
            _ => {
                for child in node.children.borrow().iter() {
                    collect_text_spans(child, spans);
                }
            }
        }
    } else if let NodeData::Text { ref contents } = node.data {
        let text = contents.borrow().to_string();
        if !text.trim().is_empty() {
            spans.push(RichTextSpan::Plain { text });
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

/// 样式信息
struct StyleInfo {
    bold: bool,
    italic: bool,
}

/// 获取样式信息
fn get_style_info(attrs: &RefCell<Vec<Attribute>>) -> StyleInfo {
    let mut bold = false;
    let mut italic = false;

    for attr in attrs.borrow().iter() {
        if attr.name.local.as_ref() == "style" {
            let style = attr.value.as_ref();
            bold = style.contains("font-weight:bold") || style.contains("font-weight: bold");
            italic = style.contains("font-style:italic") || style.contains("font-style: italic");
        }
    }

    StyleInfo { bold, italic }
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

/// 从 HTML 创建富文本段落（简化版，用于快速测试）
pub fn parse_simple_html(html: &str) -> Vec<RichParagraph> {
    // 简单的 HTML 标签处理（不依赖完整 DOM 解析）
    let mut paragraphs = Vec::new();

    // 按段落分割
    let blocks: Vec<&str> = html.split(['\n', '\r']).collect();

    for block in blocks {
        let block = block.trim();
        if block.is_empty() {
            continue;
        }

        let spans = parse_html_spans(block);
        if !spans.is_empty() {
            paragraphs.push(RichParagraph {
                spans,
                indent: 2,
                is_heading: false,
                heading_level: 0,
                class_name: None,
            });
        }
    }

    paragraphs
}

/// 解析 HTML 片段为文本片段
fn parse_html_spans(html: &str) -> Vec<RichTextSpan> {
    let mut spans = Vec::new();
    let mut remaining = html;

    while !remaining.is_empty() {
        // 查找下一个标签
        if let Some(tag_start) = remaining.find('<') {
            // 添加标签前的纯文本
            if tag_start > 0 {
                let text = &remaining[..tag_start];
                if !text.trim().is_empty() {
                    spans.push(RichTextSpan::Plain {
                        text: text.to_string(),
                    });
                }
            }

            // 解析标签
            if let Some(tag_end) = remaining.find('>') {
                let tag = &remaining[tag_start + 1..tag_end];
                remaining = &remaining[tag_end + 1..];

                // 处理标签
                if let Some(span) = parse_tag(tag, remaining) {
                    spans.push(span);
                }
            } else {
                // 没有闭合标签，剩余部分作为纯文本
                spans.push(RichTextSpan::Plain {
                    text: remaining.to_string(),
                });
                break;
            }
        } else {
            // 没有标签，剩余部分作为纯文本
            if !remaining.trim().is_empty() {
                spans.push(RichTextSpan::Plain {
                    text: remaining.to_string(),
                });
            }
            break;
        }
    }

    spans
}

/// 解析单个标签
fn parse_tag(tag: &str, remaining: &str) -> Option<RichTextSpan> {
    let tag_lower = tag.to_lowercase();

    // 跳过闭合标签和特殊标签
    if tag_lower.starts_with('/') || tag_lower.starts_with('!') {
        return None;
    }

    // 提取标签名
    let tag_name = tag_lower.split_whitespace().next().unwrap_or("");

    // 根据标签类型创建文本片段
    match tag_name {
        "b" | "strong" => {
            if let Some(end) = remaining.find("</b>").max(remaining.find("</strong>")) {
                let text = &remaining[..end];
                return Some(RichTextSpan::Bold {
                    text: text.to_string(),
                });
            }
        }
        "i" | "em" => {
            if let Some(end) = remaining.find("</i>").max(remaining.find("</em>")) {
                let text = &remaining[..end];
                return Some(RichTextSpan::Italic {
                    text: text.to_string(),
                });
            }
        }
        "u" => {
            if let Some(end) = remaining.find("</u>") {
                let text = &remaining[..end];
                return Some(RichTextSpan::Underline {
                    text: text.to_string(),
                });
            }
        }
        "code" => {
            if let Some(end) = remaining.find("</code>") {
                let text = &remaining[..end];
                return Some(RichTextSpan::Code {
                    text: text.to_string(),
                });
            }
        }
        "a" => {
            // 提取 href
            let url = extract_attr_value(tag, "href").unwrap_or_default();
            if let Some(end) = remaining.find("</a>") {
                let text = &remaining[..end];
                return Some(RichTextSpan::Link {
                    text: text.to_string(),
                    url,
                });
            }
        }
        _ => {}
    }

    None
}

/// 提取属性值
fn extract_attr_value(tag: &str, attr_name: &str) -> Option<String> {
    let pattern = format!("{}=", attr_name);
    if let Some(pos) = tag.to_lowercase().find(&pattern.to_lowercase()) {
        let rest = &tag[pos + pattern.len()..];
        let rest = rest.trim_start();

        // ✅ 优化：使用 strip_prefix 替代手动切片和 starts_with 检查
        if let Some(stripped) = rest.strip_prefix('"') {
            if let Some(end) = stripped.find('"') {
                return Some(stripped[..end].to_string());
            }
        } else if let Some(stripped) = rest.strip_prefix('\'') {
            if let Some(end) = stripped.find('\'') {
                return Some(stripped[..end].to_string());
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_html() {
        let html = "<b>粗体</b>普通<i>斜体</i>";
        let paragraphs = parse_simple_html(html);

        assert_eq!(paragraphs.len(), 1);
        // 简化版解析器会将每个标签块分开，所以 spans 数量可能多于预期
        assert!(!paragraphs[0].spans.is_empty());
    }

    #[test]
    fn test_parse_html_spans() {
        let spans = parse_html_spans("<b>test</b> plain");
        assert!(!spans.is_empty());
    }
}
