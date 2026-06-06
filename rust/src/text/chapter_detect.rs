//! 章节标题自动检测
//! 识别中文和英文小说的章节标题

use crate::storage::models::Chapter;
use crate::text::constants::{CHAPTER_PATTERN_DIGIT, CHAPTER_PATTERN_EN, CHAPTER_PATTERN_ZH};
use regex::Regex;

/// 从文本中提取章节信息
///
/// # 参数
/// * `content` - 文本内容
/// * `max_chapters` - 最大章节数
/// * `book_id` - 所属书籍 ID，填入每个章节的 book_id 字段
pub fn extract_chapters(content: &str, max_chapters: i32, book_id: &str) -> Vec<Chapter> {
    // 尝试多种章节模式，按优先级排序（中文 -> 英文 -> 数字）
    let patterns: [&Regex; 3] = [
        &*CHAPTER_PATTERN_ZH,
        &*CHAPTER_PATTERN_EN,
        &*CHAPTER_PATTERN_DIGIT,
    ];

    for pattern in &patterns {
        let chapters = extract_chapters_with_pattern(content, pattern, max_chapters, book_id);
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
    book_id: &str,
) -> Vec<Chapter> {
    let mut chapters: Vec<Chapter> = Vec::new();
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
                // last.content_length = (start - last.start_index as i64);
            }

            let chapter_index = extract_chapter_number(&title)
                .map(|n| n - 1)
                .unwrap_or(chapters.len() as i32);

            chapters.push(Chapter::new(book_id, &title, chapter_index as i64,  0, start as i64, content_len as i64)
            //   {
            //     id: uuid::Uuid::new_v4().to_string(),
            //     book_id: book_id.to_string(),
            //     title,
            //     start_index: start as i64,
            //     end_index: content_len as i64,
            //     // content_length: (content_len - start) as i64,
            //     chapter_index:chapter_index as i64,
            //     word_count: 0,
            //     cached_at: chrono::Utc::now(),
            //     level: 0,
            // }
          );
        }
    }

    chapters
}

// 从章节标题中提取章节序号
///
/// 支持识别中文数字、阿拉伯数字、罗马数字等多种序号格式。
///
/// # 参数
///
/// * `title` - 章节标题文本（如"第一章"、"Chapter 3"等）
///
/// # 返回值
///
/// * `Some(i32)` - 提取到的章节序号（从1开始）
/// * `None` - 无法提取序号
///
/// # @internal
/// - 被 `extract_chapters_with_pattern` 调用，用于设置 chapter_index
pub fn extract_chapter_number(title: &str) -> Option<i32> {
    // 尝试中文数字
    if let Some(cap) = CHAPTER_PATTERN_ZH.captures(title) {
        if let Some(num_str) = cap.get(1) {
            return Some(chinese_number_to_int(num_str.as_str()));
        }
    }

    // 尝试阿拉伯数字
    if let Some(cap) = CHAPTER_PATTERN_DIGIT.captures(title) {
        if let Some(num_str) = cap.get(1) {
            return num_str.as_str().parse().ok();
        }
    }

    // 尝试罗马数字
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
/// 将中文数字字符串转换为整数，支持以下格式：
/// - 基本数字：零〇、一二三四五六七八九、壹贰叁肆伍陆柒捌玖
/// - 单位：十拾、百佰、千千、万万
/// - 特殊组合：一百零一、二十一、一千零一等
///
/// # 参数
///
/// * `num_str` - 中文数字字符串
///
/// # 返回值
///
/// 转换后的整数值（从1开始，用于章节索引）
///
/// # 示例
///
/// ```
/// chinese_number_to_int("一") -> 1
/// chinese_number_to_int("十") -> 10
/// chinese_number_to_int("二十一") -> 21
/// chinese_number_to_int("一百") -> 100
/// chinese_number_to_int("第一百零三") -> 103
/// ```
///
/// # @internal
/// - 被 `extract_chapter_number` 调用
/// - 仅在当前模块内部使用
fn chinese_number_to_int(num_str: &str) -> i32 {
    let num_str = num_str.trim();

    // 处理纯阿拉伯数字
    if let Ok(n) = num_str.parse::<i32>() {
        return n;
    }

    // 使用累积算法：维护当前值和最终结果
    let mut result: i32 = 0;
    let mut current: i32 = 0;

    // 数字映射辅助函数
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
        // 尝试读取数字
        if let Some(digit) = digit_value(c) {
            current = current.max(digit);
        }
        // 尝试读取单位
        else if let Some(unit) = unit_value(c) {
            if current > 0 {
                result += current * unit;
            } else {
                result += unit;
            }
            current = 0;
        }
    }

    result + current
}

/// 罗马数字转整数
///
/// 将罗马数字字符串转换为整数。
///
/// # 参数
///
/// * `roman` - 罗马数字字符串（如"I"、"X"、"XXI"）
///
/// # 返回值
///
/// 转换后的整数值
///
/// # 示例
///
/// ```
/// roman_to_int("I") -> 1
/// roman_to_int("X") -> 10
/// roman_to_int("XXI") -> 21
/// roman_to_int("IV") -> 4
/// roman_to_int("IX") -> 9
/// ```
///
/// # @internal
/// - 被 `extract_chapter_number` 调用
/// - 仅在当前模块内部使用
fn roman_to_int(roman: &str) -> i32 {
    let mut result = 0;
    let mut prev_value = 0;

    // 从右向左遍历，处理减法（如 IV=4, IX=9）
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

        // 如果当前值小于前一个值，说明是减法（如 IV, IX）
        if value < prev_value {
            result -= value;
        } else {
            result += value;
        }
        prev_value = value;
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

        let chapters = extract_chapters(content, 100, "test_book");
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第一章 开始");
        assert_eq!(chapters[0].book_id, "test_book");
    }

    #[test]
    fn test_extract_chapters_en() {
        let content = r#"
Chapter 1: The Beginning
This is chapter 1.

Chapter 2: The Journey
This is chapter 2.
"#;

        let chapters = extract_chapters(content, 100, "test_book");
        assert_eq!(chapters.len(), 2);
        assert!(chapters[0].title.starts_with("Chapter 1"));
        assert_eq!(chapters[0].book_id, "test_book");
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
