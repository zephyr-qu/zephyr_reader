//! 中英文断行规则
//! 基于 Unicode Line Breaking Algorithm 实现

use std::sync::LazyLock;

use hyphenation::{Hyphenator, Load};

use unicode_segmentation::UnicodeSegmentation;

use super::constants::is_cjk_char;

// 加载英文连字符字典（优雅降级：加载失败时返回 None）
static ENGLISH_DICTIONARY: LazyLock<Option<hyphenation::Standard>> = LazyLock::new(|| {
    match hyphenation::Standard::from_embedded(hyphenation::Language::EnglishUS) {
        Ok(dict) => Some(dict),
        Err(e) => {
            tracing::warn!("Failed to load English hyphenation dictionary: {}", e);
            None
        }
    }
});

/// 智能断行（改进版：支持 Unicode 断行规则和中英文混排）
pub fn smart_break_line(text: &str, max_width: usize) -> Vec<String> {
    if text.is_empty() {
        return Vec::new();
    }

    let mut lines = Vec::new();

    // 重新实现：更精细的按字符/单词宽度断行
    let is_cjk = is_mostly_cjk(text);

    if is_cjk {
        // CJK 模式：按字符断行，但尽量不拆分连续的英文单词
        let words = text.split_word_bounds().peekable();
        let mut line = String::new();
        let mut line_width = 0;

        for word in words {
            let word_width = word.chars().count();

            if line_width + word_width > max_width {
                // 如果单词本身就比行宽，强行拆分（通常是超长连续字符）
                if word_width > max_width && line.is_empty() {
                    // 安全地拆分单词，如果索引越界则使用整个单词
                    let split_pos = word
                        .char_indices()
                        .nth(max_width)
                        .map(|(i, _)| i)
                        .unwrap_or(word.len());
                    let (head, tail) = word.split_at(split_pos);
                    lines.push(head.to_string());
                    // 将剩余部分放回迭代器（此处简化为直接推入新行）
                    line = tail.to_string();
                    line_width = tail.chars().count();
                } else {
                    lines.push(line);
                    line = word.to_string();
                    line_width = word_width;
                }
            } else {
                line.push_str(word);
                line_width += word_width;
            }
        }
        if !line.is_empty() {
            lines.push(line);
        }
    } else {
        // 英文模式：按单词断行
        return break_english_line(text, max_width);
    }

    lines
}

/// 按单词断行（英文专用，支持连字符）
fn break_english_line(text: &str, max_width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    let mut current_line = String::new();
    let mut current_width = 0;

    for word in text.split_whitespace() {
        let word_width = word.chars().count();
        let needed = if current_line.is_empty() {
            word_width
        } else {
            word_width + 1
        }; // +1 for space

        if current_width + needed > max_width {
            if !current_line.is_empty() {
                // 尝试连字符断词
                let remaining = max_width - current_width - 1; // -1 for hyphen
                if remaining >= 3 {
                    if let Some(ref dict) = *ENGLISH_DICTIONARY {
                        let hyphenated = dict.hyphenate(word);
                        let breaks: &[usize] = &hyphenated.breaks;
                        if let Some(&pos) = breaks.iter().rev().find(|&&p| p <= remaining && p > 0)
                        {
                            let (head, tail) = word.split_at(pos);
                            current_line.push(' ');
                            current_line.push_str(head);
                            current_line.push('-');
                            lines.push(current_line);
                            current_line = tail.to_string();
                            current_width = tail.chars().count();
                            continue;
                        }
                    }
                }
                lines.push(current_line);
            }
            current_line = word.to_string();
            current_width = word_width;
        } else {
            if !current_line.is_empty() {
                current_line.push(' ');
            }
            current_line.push_str(word);
            current_width += needed;
        }
    }

    if !current_line.is_empty() {
        lines.push(current_line);
    }
    lines
}

/// 检测文本中的 CJK 字符比例
pub fn is_mostly_cjk(text: &str) -> bool {
    let total = text.chars().count().max(1);
    let cjk_count = text.chars().filter(|c| is_cjk_char(*c)).count();

    cjk_count as f32 / total as f32 > 0.5
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_smart_break_line() {
        let text = "这是一段测试文本";
        let lines = smart_break_line(text, 5);
        assert!(lines.len() > 1);
    }

    #[test]
    fn test_break_english_line() {
        let text = "This is a long English text";
        let lines = break_english_line(text, 10);
        assert!(lines.len() >= 1);
        // 验证每行不超过最大宽度
        for line in &lines {
            assert!(
                line.chars().count() <= 10,
                "line width exceeds limit: {}",
                line
            );
        }
    }
}
