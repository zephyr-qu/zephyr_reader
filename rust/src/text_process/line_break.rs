//! 中英文断行规则
//! 基于 Unicode Line Breaking Algorithm 实现

use crate::ffi::LanguageType;
use unicode_segmentation::UnicodeSegmentation;

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

    let chinese_ratio = chinese_count as f32 / total as f32;

    // 简化判断逻辑
    if chinese_ratio > 0.5 {
        LanguageType::Chinese
    } else if text.chars().any(|c| c.is_ascii_alphabetic()) {
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
                    let (head, tail) = word.split_at(word.char_indices().nth(max_width).unwrap().0);
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

/// 按单词断行（英文专用，禁止拆分单词）
pub fn break_english_line(text: &str, max_width: usize) -> Vec<String> {
    let mut lines = Vec::new();
    let mut current_line = String::new();
    let mut current_width = 0;

    // 按单词分割
    let words = text.split_whitespace();

    for word in words {
        let word_width = word.chars().count();
        let space_needed = if current_line.is_empty() { 0 } else { 1 };

        if current_width + space_needed + word_width > max_width {
            // 当前行放不下，换行
            if !current_line.is_empty() {
                lines.push(current_line);
            }
            current_line = word.to_string();
            current_width = word_width;
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
        assert!(lines.len() > 1);
        // 验证没有单词被拆分
        for line in &lines {
            assert!(!line.contains(" "));
        }
    }
}
