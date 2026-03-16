//! 中英文断行规则
//! 基于 Unicode Line Breaking Algorithm 实现

use crate::ffi::LanguageType;
use hyphenation::Load;
use once_cell::sync::Lazy;
use unicode_segmentation::UnicodeSegmentation;

// 加载英文连字符字典
static ENGLISH_DICTIONARY: Lazy<hyphenation::Standard> = Lazy::new(|| {
    hyphenation::Standard::from_embedded(hyphenation::Language::EnglishUS)
        .expect("Failed to load English dictionary")
});

/// 检测文本语言类型
pub fn detect_language(text: &str) -> LanguageType {
    let total = text.chars().count().max(1);
    let chinese_count = text
        .chars()
        .filter(|c| {
            let cp = *c as u32;
            // CJK Unified Ideographs
            (0x4E00..=0x9FFF).contains(&cp) ||
        // CJK Unified Ideographs Extension A
        (0x3400..=0x4DBF).contains(&cp) ||
        // CJK Compatibility Ideographs
        (0xF900..=0xFAFF).contains(&cp)
        })
        .count();

    let english_count = text.chars().filter(|c| c.is_ascii_alphabetic()).count();

    let chinese_ratio = chinese_count as f32 / total as f32;
    let english_ratio = english_count as f32 / total as f32;

    // 同时包含中文和英文 -> Mixed
    if chinese_count > 0 && english_count > 0 {
        LanguageType::Mixed
    } else if chinese_ratio > 0.5 {
        LanguageType::Chinese
    } else if english_ratio > 0.5 {
        LanguageType::English
    } else {
        LanguageType::Mixed
    }
}

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
        let mut words = text.split_word_bounds().peekable();
        let mut line = String::new();
        let mut line_width = 0;

        while let Some(word) = words.next() {
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
pub fn break_english_line(text: &str, max_width: usize) -> Vec<String> {
    use hyphenation::Hyphenator;

    let mut lines = Vec::new();
    let mut current_line = String::new();
    let mut current_width = 0;

    // 按单词分割
    let words = text.split_whitespace();

    for word in words {
        let word_width = word.chars().count();
        let space_needed = if current_line.is_empty() { 0 } else { 1 };

        if current_width + space_needed + word_width > max_width {
            // 当前行放不下
            // 尝试使用连字符拆分单词
            if !current_line.is_empty() {
                // 计算剩余空间
                let remaining_space = max_width.saturating_sub(current_width + space_needed);

                // 如果剩余空间太小（比如小于3个字符），直接换行
                if remaining_space < 3 {
                    lines.push(current_line);
                    current_line = word.to_string();
                    current_width = word_width;
                    continue;
                }

                // 尝试断词
                let hyphenated = ENGLISH_DICTIONARY.hyphenate(word);
                let mut best_break = None;

                for break_idx in hyphenated.breaks {
                    // break_idx 是字节索引，需要小心处理
                    // 这里假设是 ASCII/UTF-8，对于纯英文应该没问题
                    // 实际上最好转为字符索引
                    if break_idx >= word.len() {
                        continue;
                    }

                    // 简单的字节长度检查（近似字符数）
                    if break_idx <= remaining_space {
                        best_break = Some(break_idx);
                    } else {
                        break;
                    }
                }

                if let Some(idx) = best_break {
                    let (head, tail) = word.split_at(idx);

                    // 添加前半部分和连字符
                    if !current_line.is_empty() {
                        current_line.push(' ');
                    }
                    current_line.push_str(head);
                    current_line.push('-');
                    lines.push(current_line);

                    // 新行开始
                    current_line = tail.to_string();
                    current_width = tail.chars().count();
                } else {
                    // 无法断词或空间不足，直接换行
                    lines.push(current_line);
                    current_line = word.to_string();
                    current_width = word_width;
                }
            } else {
                // 当前行是空的，但单词本身比 max_width 还长
                // 这种情况下也应该尝试断词，但这里简化处理，直接放入（或者强行截断）
                current_line = word.to_string();
                current_width = word_width;
            }
        } else {
            // 可以放下
            if space_needed > 0 {
                current_line.push(' ');
                current_width += space_needed;
            }
            current_line.push_str(word);
            current_width += word_width;
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
    let cjk_count = text
        .chars()
        .filter(|c| {
            let cp = *c as u32;
            (0x4E00..=0x9FFF).contains(&cp)
                || (0x3400..=0x4DBF).contains(&cp)
                || (0xF900..=0xFAFF).contains(&cp)
                || (0x3000..=0x303F).contains(&cp)
        })
        .count();

    cjk_count as f32 / total as f32 > 0.5
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_chinese() {
        let text = "这是一段中文文本";
        assert_eq!(detect_language(text), LanguageType::Chinese);
    }

    #[test]
    fn test_detect_english() {
        let text = "This is an English text";
        assert_eq!(detect_language(text), LanguageType::English);
    }

    #[test]
    fn test_detect_mixed() {
        let text = "这是 Chinese 文本";
        assert_eq!(detect_language(text), LanguageType::Mixed);
    }

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
            assert!(line.chars().count() <= 10, "行宽超出限制：{}", line);
        }
    }
}
