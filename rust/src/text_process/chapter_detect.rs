//! 章节标题自动检测
//! 识别中文和英文小说的章节标题
//!
//! 使用 `rayon` 并行库优化大文本的预处理和匹配后处理。
use crate::ffi::ChapterInfo;
use once_cell::sync::Lazy;
use regex::Regex;
/// 中文章节匹配模式
/// 识别中文小说的章节标题（如"第一章"、"第壹回"等）
pub static CHAPTER_PATTERN_ZH: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?m)^(?:第\s*)?([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟 0-9]+)\s*[章回卷节部篇集]\s*(.+)?|(?:楔子 | 序 [言引]|前言 | 引子 | 尾声 | 完结 | 番外 | 后记)\s*(.+)?$"
    ).expect("CHAPTER_PATTERN_ZH 正则表达式编译失败")
});

/// 英文章节匹配模式
/// 识别英文小说的章节标题（如"Chapter 1"、"Part I"等）
pub static CHAPTER_PATTERN_EN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?mi)^(?:Chapter\s+\d+|[IVX]+\.[\s.]|[IVX]+\s+[A-Z]|\bPart\s+\d+|Book\s+\d+|Prologue|Epilogue|Preface|Introduction|Conclusion)\s*:?\s*(.*)$"
    ).expect("CHAPTER_PATTERN_EN 正则表达式编译失败")
});

/// 数字章节匹配模式
/// 识别纯数字章节（如"1. Title"、"2、标题"等）
pub static CHAPTER_PATTERN_DIGIT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?m)^(\d+)[\s.、:：](.+)$").expect("CHAPTER_PATTERN_DIGIT 正则表达式编译失败")
});
/// 从文本中提取章节信息
pub fn extract_chapters(content: &str, max_chapters: i32) -> Vec<ChapterInfo> {
    // 尝试多种章节模式，按优先级排序（中文 -> 英文 -> 数字）
    let patterns: [&Regex; 3] = [
        &*CHAPTER_PATTERN_ZH,
        &*CHAPTER_PATTERN_EN,
        &*CHAPTER_PATTERN_DIGIT,
    ];

    for pattern in &patterns {
        let chapters = extract_chapters_with_pattern(content, pattern, max_chapters);
        if !chapters.is_empty() {
            return chapters;
        }
    }

    Vec::new()
}

/// 使用单个正则模式提取章节
fn extract_chapters_with_pattern(
    content: &str,
    pattern: &Regex,
    max_chapters: i32,
) -> Vec<ChapterInfo> {
    let mut chapters: Vec<ChapterInfo> = Vec::new();
    let content_len = content.len() as i64;

    for cap in pattern.captures_iter(content) {
        if chapters.len() >= max_chapters as usize {
            break;
        }

        if let Some(m) = cap.get(0) {
            let start = m.start() as i64;
            let title = m.as_str().trim().to_string();

            // 更新上一章的结束位置
            if let Some(last) = chapters.last_mut() {
                last.end_index = start;
                last.content_length = start - last.start_index;
            }

            chapters.push(ChapterInfo {
                chapter_id: uuid::Uuid::new_v4().to_string(),
                title,
                start_index: start,
                end_index: content_len,
                content_length: content_len - start,
                index: chapters.len() as i32,
                level: 0,
            });
        }
    }

    chapters
}

/// 检测单个文本是否为章节标题
pub fn is_chapter_title(text: &str) -> bool {
    let text = text.trim();

    CHAPTER_PATTERN_ZH.is_match(text)
        || CHAPTER_PATTERN_EN.is_match(text)
        || CHAPTER_PATTERN_DIGIT.is_match(text)
}

/// 提取章节序号
pub fn extract_chapter_number(title: &str) -> Option<i32> {
    // 中文数字转阿拉伯数字
    if let Some(cap) = CHAPTER_PATTERN_ZH.captures(title) {
        if let Some(num_str) = cap.get(1) {
            return Some(chinese_number_to_int(num_str.as_str()));
        }
    }

    // 阿拉伯数字
    if let Some(cap) = CHAPTER_PATTERN_DIGIT.captures(title) {
        if let Some(num_str) = cap.get(1) {
            return num_str.as_str().parse().ok();
        }
    }

    // 罗马数字
    if let Some(cap) = CHAPTER_PATTERN_EN.captures(title) {
        if let Some(m) = cap.get(0) {
            let roman = m.as_str().trim_matches(|c: char| !c.is_alphabetic());
            if !roman.is_empty() {
                return Some(roman_to_int(roman));
            }
        }
    }

    None
}

/// 中文数字转整数
///
/// 支持中文数字（包括"零"的处理）转换为整数。
/// 例如："一百零一" -> 101, "二十五" -> 25, "一千零一" -> 1001
fn chinese_number_to_int(num_str: &str) -> i32 {
    let num_str = num_str.trim();

    // 处理阿拉伯数字
    if let Ok(n) = num_str.parse::<i32>() {
        return n;
    }

    // 使用更清晰的算法：维护当前累积值和最终结果
    let mut result: i32 = 0;
    let mut current: i32 = 0;

    // 数字映射
    fn digit_value(c: char) -> Option<i32> {
        match c {
            '零' | '〇' => Some(0),
            '一' | '壹' => Some(1),
            '二' | '两' | '贰' => Some(2),
            '三' | '叁' => Some(3),
            '四' | '肆' => Some(4),
            '五' | '伍' => Some(5),
            '六' | '陆' => Some(6),
            '七' | '柒' => Some(7),
            '八' | '捌' => Some(8),
            '九' | '玖' => Some(9),
            _ => None,
        }
    }

    // 单位映射
    fn unit_value(c: char) -> Option<i32> {
        match c {
            '十' | '拾' => Some(10),
            '百' | '佰' => Some(100),
            '千' | '仟' => Some(1000),
            '万' | '萬' => Some(10000),
            _ => None,
        }
    }

    for c in num_str.chars() {
        if let Some(digit) = digit_value(c) {
            // 数字字符：累加到当前值
            current += digit;
        } else if let Some(unit) = unit_value(c) {
            // 单位字符：当前值乘以单位，如果没有当前值则使用单位本身
            if current == 0 {
                current = unit;
            } else {
                current *= unit;
            }

            // 如果是"万"，需要累加到结果并重置当前值
            if unit >= 10000 {
                result += current;
                current = 0;
            }
        }
    }

    // 加上最后剩余的当前值
    result + current
}

/// 罗马数字转整数
fn roman_to_int(roman: &str) -> i32 {
    let roman = roman.to_uppercase();
    let mut result = 0;
    let mut prev = 0;

    for c in roman.chars().rev() {
        let value = match c {
            'I' => 1,
            'V' => 5,
            'X' => 10,
            'L' => 50,
            'C' => 100,
            'D' => 500,
            'M' => 1000,
            _ => 0,
        };

        if value < prev {
            result -= value;
        } else {
            result += value;
        }
        prev = value;
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_chapters_zh() {
        let content = r#"
第一章 开始
这是第一章的内容。

第二章 发展
这是第二章的内容。

第三章 结局
这是第三章的内容。
"#;

        let chapters = extract_chapters(content, 100);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第一章 开始");
    }

    #[test]
    fn test_extract_chapters_en() {
        let content = r#"
Chapter 1: The Beginning
This is chapter 1.

Chapter 2: The Journey
This is chapter 2.
"#;

        let chapters = extract_chapters(content, 100);
        assert_eq!(chapters.len(), 2);
        assert!(chapters[0].title.starts_with("Chapter 1"));
    }

    #[test]
    fn test_chinese_number() {
        assert_eq!(chinese_number_to_int("一"), 1);
        assert_eq!(chinese_number_to_int("十"), 10);
        assert_eq!(chinese_number_to_int("二十一"), 21);
        assert_eq!(chinese_number_to_int("一百"), 100);
    }

    #[test]
    fn test_roman_number() {
        assert_eq!(roman_to_int("I"), 1);
        assert_eq!(roman_to_int("X"), 10);
        assert_eq!(roman_to_int("XXI"), 21);
    }
}
