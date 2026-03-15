//! 文本排版处理
//! 包含中英文混排优化、标点避首避尾、段落处理

use super::line_break::smart_break_line;
use crate::ffi::{ApiResult, TypesetConfig};
use flutter_rust_bridge::frb;
use once_cell::sync::Lazy;
use rayon::prelude::*;
use regex::Regex;

static TAG_PATTERN: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"<[^>]*>").expect("Invalid regex pattern"));

/// 排版处理主函数
#[frb(sync)]
pub fn typeset_content(
    content: String,
    language: String,
    config: TypesetConfig,
) -> ApiResult<String> {
    log::debug!("开始并行排版处理，语言：{}", language);

    // 按段落处理
    let paragraphs: Vec<&str> = content.split("\n\n").collect();

    // 并行处理每个段落
    let processed: Vec<String> = paragraphs
        .par_iter()
        .map(|paragraph| {
            if paragraph.trim().is_empty() {
                return String::new();
            }

            // 判断是否为标题
            if is_heading(paragraph) {
                let mut h = format_heading(paragraph);
                h.push('\n');
                return h;
            }

            // 处理普通段落
            typeset_paragraph(paragraph, &language, &config)
        })
        .collect();

    let mut result = String::new();
    let total = processed.len();
    let spacing = config.paragraph_spacing as i32;

    for (i, para) in processed.into_iter().enumerate() {
        if para.is_empty() {
            continue;
        }

        result.push_str(&para);

        // 添加段落间距
        if i < total - 1 {
            for _ in 0..spacing {
                result.push('\n');
            }
        }
    }

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
fn typeset_paragraph(paragraph: &str, language: &str, config: &TypesetConfig) -> String {
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
    let max_chars_per_line = (config.page_width as f32 / config.font_size as f32) as usize;
    let lines = smart_break_line(&optimized, max_chars_per_line.max(10));

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
fn optimize_punctuation(text: &str, language: &str) -> String {
    let mut result = text.to_string();

    // 中文标点避首
    if language == "zh" || language == "mix" || language == "auto" {
        // 替换行首标点
        let avoid_start = [
            "，", "。", "、", "；", "：", "？", "！", "…", "—", "）", "】", "》", "」", "』",
        ];
        for p in avoid_start.iter() {
            result = result.replace(&format!("\n{}", p), &format!("{}{}", " ", p));
        }

        // 替换行尾标点（某些标点不应在行尾）
        let avoid_end = ["（", "【", "《", "「", "『"];
        for p in avoid_end.iter() {
            result = result.replace(&format!("{}\n", p), &format!("{}{}", p, " "));
        }
    }

    // 英文标点优化
    if language == "en" || language == "mix" || language == "auto" {
        // 修复省略号
        result = result.replace("...", "…");
        result = result.replace(". . .", "…");

        // 修复破折号
        result = result.replace("--", "—");
        result = result.replace(" -- ", " — ");
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
fn add_space_between_cjk_and_latin(text: &str) -> String {
    let mut result = String::new();
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

/// 判断是否为 CJK 字符
fn is_cjk_char(c: char) -> bool {
    let cp = c as u32;
    (0x4E00..=0x9FFF).contains(&cp)
        || (0x3400..=0x4DBF).contains(&cp)
        || (0xF900..=0xFAFF).contains(&cp)
        || (0x3000..=0x303F).contains(&cp)
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

/// 中英文混排优化
pub fn optimize_mixed_text(text: &str) -> String {
    // 添加中英文之间的空格
    let result = add_space_between_cjk_and_latin(text);

    // 移除多余空格
    remove_extra_spaces(&result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_html_tags() {
        let html = "<p>Hello <b>World</b></p>";
        let result = strip_html_tags(html);
        assert_eq!(result, "Hello World");
    }

    #[test]
    fn test_optimize_mixed_text() {
        let text = "这是 Chinese 文本";
        let result = optimize_mixed_text(text);
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
}
