//! 文本排版处理
//! 包含中英文混排优化、标点避首避尾、段落处理

use super::constants::{MIN_CHARS_PER_LINE, TAG_PATTERN};
use super::line_break::smart_break_line;
use crate::ffi::{ApiResult, TypesetConfig};
use flutter_rust_bridge::frb;
use hyphenation::{Hyphenator, Language, Standard};
use once_cell::sync::Lazy;

/// 排版处理主函数
#[frb(sync)]
pub fn typeset_content(
    content: String,
    language: String,
    config: TypesetConfig,
) -> ApiResult<String> {
    let start_time = std::time::Instant::now();
    let content_len = content.len();
    tracing::debug!("开始排版处理，字符数：{}", content_len);

    // 使用迭代器惰性处理，避免一次性收集所有字符到 Vec 中
    // 按段落处理，使用 char_indices() 和字符串切片代替 Vec 索引
    // 预分配 2 倍容量，因为排版通常会增加字符数（缩进、空格等）
    let mut result = String::with_capacity(content.len() * 2);
    let spacing = config.paragraph_spacing as i32;
    let mut first_para = true;
    let mut para_count = 0;

    // 使用惰性迭代器处理段落，避免收集到 Vec
    let mut paragraph_starts = content
        .char_indices()
        .filter(|&(_, c)| c == '\n')
        .map(|(i, _)| i)
        .peekable();

    let mut last_end = 0;

    loop {
        // 找到下一个段落起始位置（跳过连续的 \n）
        let paragraph_start = loop {
            if let Some(&start) = paragraph_starts.peek() {
                paragraph_starts.next(); // 消耗这个位置
                                         // 跳过连续的换行符（start 是 \n 的字节位置，+1 安全因为 \n 是单字节）
                if start + 1 < content.len() && content.as_bytes().get(start + 1) == Some(&b'\n') {
                    continue;
                }
                // 确保 start + 1 是有效的 UTF-8 边界
                let next_pos = (start + 1).min(content.len());
                // 如果不是有效边界，对齐到下一个字符
                let safe_next = content.floor_char_boundary(next_pos);
                break safe_next;
            } else {
                break content.len();
            }
        };

        // 提取当前段落（使用字符串切片，避免复制）
        if paragraph_start > last_end {
            let paragraph = &content[last_end..paragraph_start];

            // 处理段落
            if !paragraph.trim().is_empty() {
                para_count += 1;
                if !first_para {
                    for _ in 0..spacing {
                        result.push('\n');
                    }
                }
                first_para = false;

                // 判断是否为标题
                if is_heading(paragraph) {
                    result.push_str(&format_heading(paragraph));
                    result.push('\n');
                } else {
                    result.push_str(&typeset_paragraph(paragraph, &language, &config));
                }
            }
        }

        // 检查是否还有更多段落
        if paragraph_start >= content.len() {
            break;
        }

        last_end = paragraph_start;
    }

    // 处理最后一个段落（如果有的话）
    if last_end < content.len() {
        let paragraph = &content[last_end..];
        if !paragraph.trim().is_empty() {
            para_count += 1;
            if !first_para {
                for _ in 0..spacing {
                    result.push('\n');
                }
            }
            if is_heading(paragraph) {
                result.push_str(&format_heading(paragraph));
                result.push('\n');
            } else {
                result.push_str(&typeset_paragraph(paragraph, &language, &config));
            }
        }
    }

    let elapsed = start_time.elapsed();
    tracing::debug!(
        "排版处理完成：段落数={}, 输出字符数={}, 耗时：{:?}",
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
    let lines = smart_break_line(&optimized, max_chars_per_line.max(MIN_CHARS_PER_LINE));

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
/// 使用单次遍历 + 预分配容量，避免多次 `replace()` 导致的 O(n×m) 字符串复制。
fn optimize_punctuation(text: &str, language: &str) -> String {
    let is_zh_or_mix = matches!(language, "zh" | "mix" | "auto");
    let is_en_or_mix = matches!(language, "en" | "mix" | "auto");

    // 如果不需要任何优化，直接返回
    if !is_zh_or_mix && !is_en_or_mix {
        return text.to_string();
    }

    // 预分配容量（通常为原始长度的 1.2 倍，避免重新分配）
    let mut result = String::with_capacity((text.len() as f32 * 1.2) as usize);
    let mut modified = false;
    let mut remaining = text.to_string();

    // 中文标点避首替换
    if is_zh_or_mix {
        let avoid_start = [
            ("\n，", " ，"),
            ("\n。", " 。"),
            ("\n、", " 、"),
            ("\n；", " ；"),
            ("\n：", " ："),
            ("\n？", " ？"),
            ("\n！", " ！"),
            ("\n…", " …"),
            ("\n）", " )"),
            ("\n】", " 】"),
            ("\n》", " 》"),
            ("\n」", " 」"),
            ("\n』", " 』"),
        ];
        let avoid_end = [
            ("（\n", "（ "),
            ("【\n", "【 "),
            ("《\n", "《 "),
            ("「\n", "「 "),
            ("『\n", "『 "),
        ];

        for &(pattern, replacement) in avoid_start.iter().chain(avoid_end.iter()) {
            if remaining.contains(pattern) {
                remaining = remaining.replace(pattern, replacement);
                modified = true;
            }
        }
    }

    // 英文标点优化
    if is_en_or_mix {
        if remaining.contains("...") || remaining.contains(". . .") {
            remaining = remaining.replace("...", "…");
            remaining = remaining.replace(". . .", "…");
            modified = true;
        }
        if remaining.contains("--") {
            remaining = remaining.replace("--", "—");
            remaining = remaining.replace(" -- ", " — ");
            modified = true;
        }
    }

    if modified {
        result.push_str(&remaining);
    } else {
        result.push_str(text);
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

// ==================== 英文连字符支持 ====================

use hyphenation::Load;

/// 全局连字符处理器（懒加载）
static HYPHENATOR_EN: Lazy<Option<Standard>> =
    Lazy::new(|| match Standard::from_embedded(Language::EnglishUS) {
        Ok(h) => {
            tracing::info!("英文连字符数据加载成功");
            Some(h)
        }
        Err(e) => {
            tracing::warn!("英文连字符数据加载失败：{}", e);
            None
        }
    });

/// 对英文单词进行连字符处理
///
/// 在合适的位置插入软连字符（U+00AD），允许在行尾断词。
///
/// # 参数
///
/// * `word` - 英文单词
///
/// # 返回值
///
/// 返回带软连字符的单词
pub fn hyphenate_word(word: &str) -> String {
    // 只对足够长的单词进行连字符处理
    if word.len() < 5 {
        return word.to_string();
    }

    // 检查连字符处理器是否可用
    let Some(hyphenator) = HYPHENATOR_EN.as_ref() else {
        return word.to_string();
    };

    // 使用 hyphenation 库进行音节划分
    let hyphenated = hyphenator.hyphenate(word);

    // 使用更简洁的方式连接音节
    // hyphenated.breaks 是断点位置数组，如 [2, 5, 7] 表示在索引 2, 5, 7 处断开
    let mut result = String::with_capacity(word.len() + hyphenated.breaks.len());
    let mut prev_break = 0;

    for &breakpoint in &hyphenated.breaks {
        // 跳过无效断点
        if breakpoint <= prev_break || breakpoint > word.len() {
            continue;
        }

        // 添加音节
        result.push_str(&word[prev_break..breakpoint]);

        // 添加软连字符（最后一个断点后不需要）
        if breakpoint < word.len() {
            result.push('\u{00AD}');
        }

        prev_break = breakpoint;
    }

    // 添加剩余部分
    if prev_break < word.len() {
        result.push_str(&word[prev_break..]);
    }

    result
}

/// 对文本进行英文连字符处理
///
/// 识别文本中的英文单词并添加连字符，使行尾断词更加美观。
///
/// # 参数
///
/// * `text` - 输入文本
/// * `enable_hyphenation` - 是否启用连字符
///
/// # 返回值
///
/// 返回处理后的文本
#[frb(sync)]
pub fn apply_hyphenation(text: String, enable_hyphenation: bool) -> String {
    if !enable_hyphenation {
        return text;
    }

    let mut result = String::new();
    let mut current_word = String::new();
    let mut in_english_word = false;

    for c in text.chars() {
        if c.is_ascii_alphabetic() {
            current_word.push(c);
            in_english_word = true;
        } else {
            if in_english_word && !current_word.is_empty() {
                // 处理英文单词
                let hyphenated = hyphenate_word(&current_word);
                result.push_str(&hyphenated);
                current_word.clear();
            }
            result.push(c);
            in_english_word = false;
        }
    }

    // 处理最后一个单词
    if !current_word.is_empty() {
        let hyphenated = hyphenate_word(&current_word);
        result.push_str(&hyphenated);
    }

    result
}

/// 带连字符支持的排版处理
///
/// 在标准排版基础上，增加英文连字符处理，使英文文本在行尾断词更加美观。
///
/// # 参数
///
/// * `content` - 待排版的原始文本
/// * `language` - 语言类型（"auto"、"zh"、"en"、"mix"）
/// * `config` - 排版配置
/// * `enable_hyphenation` - 是否启用连字符
///
/// # 返回值
///
/// 返回排版后的文本
#[frb(sync)]
pub fn typeset_content_with_hyphenation(
    content: String,
    language: String,
    config: TypesetConfig,
    enable_hyphenation: bool,
) -> ApiResult<String> {
    // 首先进行标准排版
    let typeset_text = typeset_content(content, language, config)?;

    // 如果启用连字符，对英文部分进行处理
    if enable_hyphenation {
        Ok(apply_hyphenation(typeset_text, true))
    } else {
        Ok(typeset_text)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::TypesetConfig;

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
