//! 文本排版处理
//! 包含中英文混排优化、标点避首避尾、段落处理

use super::constants::{MIN_CHARS_PER_LINE, TAG_PATTERN, is_cjk_char};
use super::line_break::smart_break_line;
use crate::domain::{AppError, TypesetConfig};

/// 排版处理主函数
pub fn typeset_content(
    content: String,
    language: String,
    config: TypesetConfig,
) -> Result<String, AppError> {
    let start_time = std::time::Instant::now();
    let content_len = content.len();
    tracing::debug!("typesetting start, chars: {}", content_len);

    let mut result = String::with_capacity(content_len * 2);
    let spacing = config.paragraph_spacing as usize;
    let max_chars_per_line = (config.page_width as f32 / config.font_size as f32) as usize;
    let min_chars = max_chars_per_line.max(MIN_CHARS_PER_LINE);
    let mut para_count = 0;

    // 直接按空行分割段落
    let paragraphs: Vec<&str> = content.split("\n\n").collect();

    for (i, paragraph) in paragraphs.iter().enumerate() {
        let paragraph = paragraph.trim_matches('\n');
        if paragraph.is_empty() {
            continue;
        }

        para_count += 1;

        // 添加段落间距（第一个段落不需要）
        if i > 0 {
            for _ in 0..spacing {
                result.push('\n');
            }
        }

        // 处理段落内容
        if is_heading(paragraph) {
            result.push_str(&format_heading(paragraph));
            result.push('\n');
        } else {
            result.push_str(&typeset_paragraph(paragraph, &language, &config, min_chars));
        }
    }

    let elapsed = start_time.elapsed();
    tracing::debug!(
        "typesetting done: paragraphs={}, output_chars={}, elapsed={:?}",
        para_count,
        result.len(),
        elapsed
    );

    Ok(result)
}

/// 判断是否为标题
fn is_heading(text: &str) -> bool {
    let text = text.trim();

    //  Markdown 标题
    if text.starts_with('#') {
        return true;
    }

    //  HTML 标题标签
    if text.starts_with("<h") {
        return true;
    }

    // 短文本且居中（可能是标题）
    if text.chars().count() < 50 && !text.starts_with(' ') {
        // 检查是否包含章节关键词
        let keywords = [
            "第", "章", "回", "卷", "节", "篇", "部", "集", "Chapter", "Part", "Book", "Prologue",
            "Epilogue",
        ];
        for keyword in keywords {
            if text.contains(keyword) {
                return true;
            }
        }
    }

    false
}

/// 格式化标题
fn format_heading(text: &str) -> String {
    let text = text.trim();

    // 移除 Markdown 标记
    let text = text.trim_start_matches(|c: char| c == '#' || c.is_whitespace());

    // 移除 HTML 标签
    let text = strip_html_tags(text);

    format!("【{}】", text.trim())
}

/// 移除 HTML 标签（改进版）
fn strip_html_tags(text: &str) -> String {
    // 使用正则表达式移除 HTML 标签
    TAG_PATTERN.replace_all(text, "").to_string()
}

/// 处理单个段落
fn typeset_paragraph(
    paragraph: &str,
    language: &str,
    config: &TypesetConfig,
    max_chars_per_line: usize,
) -> String {
    // 首行缩进
    let indent = if config.first_line_indent > 0 {
        "  ".repeat(config.first_line_indent as usize)
    } else {
        String::new()
    };

    // 标点符号优化
    let optimized = optimize_punctuation(paragraph, language);

    // 空格优化
    let optimized = optimize_spaces(&optimized, language);

    // 断行处理
    let lines = smart_break_line(&optimized, max_chars_per_line);

    // 组装结果
    let mut result = indent.clone();
    for (i, line) in lines.iter().enumerate() {
        if i > 0 {
            result.push('\n');
            result.push_str(&indent);
        }
        result.push_str(line);
    }

    result
}

/// 优化标点符号（避首避尾）
///
/// 单次遍历 O(n)，预分配容量避免重新分配。
fn optimize_punctuation(text: &str, language: &str) -> String {
    let is_zh_or_mix = matches!(language, "zh" | "mix" | "auto");
    let is_en_or_mix = matches!(language, "en" | "mix" | "auto");

    if !is_zh_or_mix && !is_en_or_mix {
        return text.to_string();
    }

    let mut result = String::with_capacity(text.len() + 32);
    let chars: Vec<char> = text.chars().collect();
    let mut modified = false;
    let mut i = 0;

    while i < chars.len() {
        let c = chars[i];
        if c == '\n' && i + 1 < chars.len() {
            let next = chars[i + 1];
            if is_zh_or_mix && crate::text::constants::is_start_avoid_punctuation(next) {
                result.push('\n');
                result.push(' ');
                i += 1;
                modified = true;
                continue;
            }
        }
        if is_zh_or_mix
            && crate::text::constants::is_end_avoid_punctuation(c)
            && i + 1 < chars.len()
            && chars[i + 1] == '\n'
        {
            result.push(c);
            result.push(' ');
            i += 1;
            modified = true;
            continue;
        }
        if i + 2 < chars.len() && is_en_or_mix {
            if c == '.' && chars[i + 1] == '.' && chars[i + 2] == '.' {
                result.push('…');
                i += 3;
                modified = true;
                continue;
            }
            if c == '-' && chars[i + 1] == '-' {
                result.push('—');
                i += 2;
                modified = true;
                continue;
            }
        }
        result.push(c);
        i += 1;
    }

    if !modified {
        return text.to_string();
    }
    result
}

/// 优化空格
fn optimize_spaces(text: &str, language: &str) -> String {
    let mut result = text.to_string();

    // 中英文混排时添加空格
    if language == "mix" || language == "auto" {
        // 中文和英文之间添加空格
        result = add_space_between_cjk_and_latin(&result);
    }

    // 移除多余空格
    result = remove_extra_spaces(&result);

    result
}

/// 在中文字符和拉丁字符之间添加空格
///
/// 预分配 `text.len() * 2` 容量，避免频繁重新分配。
fn add_space_between_cjk_and_latin(text: &str) -> String {
    // 预分配容量（最坏情况下每个字符间都需要空格）
    let mut result = String::with_capacity(text.len() * 2);
    let mut prev_char: Option<char> = None;

    for c in text.chars() {
        if let Some(prev) = prev_char {
            let prev_is_cjk = is_cjk_char(prev);
            let curr_is_latin = c.is_ascii_alphabetic() || c.is_ascii_digit();
            let prev_is_latin = prev.is_ascii_alphabetic() || prev.is_ascii_digit();
            let curr_is_cjk = is_cjk_char(c);

            // 中文和英文/数字之间添加空格
            if (prev_is_cjk && curr_is_latin) || (prev_is_latin && curr_is_cjk) {
                result.push(' ');
            }
        }

        result.push(c);
        prev_char = Some(c);
    }

    result
}

/// 移除多余空格
fn remove_extra_spaces(text: &str) -> String {
    let mut result = String::new();
    let mut prev_space = false;

    for c in text.chars() {
        if c.is_whitespace() {
            if !prev_space {
                result.push(' ');
                prev_space = true;
            }
        } else {
            result.push(c);
            prev_space = false;
        }
    }

    result.trim().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::TypesetConfig;

    #[test]
    fn test_strip_html_tags() {
        let html = "<p>Hello <b>World</b></p>";
        let result = strip_html_tags(html);
        assert_eq!(result, "Hello World");
    }

    #[test]
    fn test_optimize_mixed_text() {
        let text = "这是 Chinese 文本";
        let result = add_space_between_cjk_and_latin(text);
        let result = remove_extra_spaces(&result);
        assert!(result.contains("Chinese"));
    }

    #[test]
    fn test_format_heading() {
        let text = "# 第一章 开始";
        let result = format_heading(text);
        assert!(result.contains("第一章 开始"));
    }

    #[test]
    fn test_is_heading() {
        assert!(is_heading("# Chapter 1"));
        assert!(is_heading("第一章 开始"));
        assert!(!is_heading("这是普通段落"));
    }

    #[test]
    fn test_typeset_content_basic() {
        let content = "这是第一段。\n\n这是第二段。";
        let config = TypesetConfig::default();
        let result = typeset_content(content.to_string(), "zh".to_string(), config);
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("这是第一段"));
        assert!(output.contains("这是第二段"));
    }

    #[test]
    fn test_typeset_content_empty() {
        let content = "";
        let config = TypesetConfig::default();
        let result = typeset_content(content.to_string(), "zh".to_string(), config);
        assert!(result.is_ok());
        assert!(result.unwrap().is_empty());
    }

    #[test]
    fn test_typeset_content_with_heading() {
        let content = "# 第一章 开始\n\n这是正文内容。";
        let config = TypesetConfig::default();
        let result = typeset_content(content.to_string(), "zh".to_string(), config);
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("【第一章 开始】"));
    }
}
