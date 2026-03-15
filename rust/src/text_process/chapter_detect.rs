//! 章节标题自动检测
//! 识别中文和英文小说的章节标题

use crate::ffi::ChapterInfo;
use once_cell::sync::Lazy;
use regex::Regex;

static CHAPTER_PATTERN_ZH: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?m)^(?:第\s*)?([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟 0-9]+)\s*[章回卷节部篇集]\s*(.+)?|(?:楔子 | 序 [言引]|前言 | 引子 | 尾声 | 完结 | 番外 | 后记)\s*(.+)?$"
    ).expect("Invalid chapter pattern regex")
});

static CHAPTER_PATTERN_EN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?mi)^(?:Chapter\s+\d+|[IVX]+\.[\s.]|[IVX]+\s+[A-Z]|\bPart\s+\d+|Book\s+\d+|Prologue|Epilogue|Preface|Introduction|Conclusion)\s*:?\s*(.*)$"
    ).expect("Invalid English chapter pattern regex")
});

static CHAPTER_PATTERN_DIGIT: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r"(?m)^(\d+)[\s.、:：](.+)$").expect("Invalid digit chapter pattern regex")
});

/// 从文本中提取章节信息
pub fn extract_chapters(content: &str, max_chapters: i32) -> Vec<ChapterInfo> {
    let mut chapters: Vec<ChapterInfo> = Vec::new();

    // 尝试中文章节匹配
    for cap in CHAPTER_PATTERN_ZH.captures_iter(content) {
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

            let chapter_id = chapters.len() as i32;
            chapters.push(ChapterInfo {
                chapter_id,
                title,
                start_index: start,
                end_index: content.len() as i64,
                content_length: content.len() as i64 - start,
                index: chapter_id,
            });
        }
    }

    // 如果中文匹配失败，尝试英文匹配
    if chapters.is_empty() {
        for cap in CHAPTER_PATTERN_EN.captures_iter(content) {
            if chapters.len() >= max_chapters as usize {
                break;
            }

            if let Some(m) = cap.get(0) {
                let start = m.start() as i64;
                let title = m.as_str().trim().to_string();

                if let Some(last) = chapters.last_mut() {
                    last.end_index = start;
                    last.content_length = start - last.start_index;
                }

                let chapter_id = chapters.len() as i32;
                chapters.push(ChapterInfo {
                    chapter_id,
                    title,
                    start_index: start,
                    end_index: content.len() as i64,
                    content_length: content.len() as i64 - start,
                    index: chapter_id,
                });
            }
        }
    }

    // 如果仍然没有匹配，尝试数字章节匹配
    if chapters.is_empty() {
        for cap in CHAPTER_PATTERN_DIGIT.captures_iter(content) {
            if chapters.len() >= max_chapters as usize {
                break;
            }

            if let Some(m) = cap.get(0) {
                let start = m.start() as i64;
                let title = m.as_str().trim().to_string();

                if let Some(last) = chapters.last_mut() {
                    last.end_index = start;
                    last.content_length = start - last.start_index;
                }

                let chapter_id = chapters.len() as i32;
                chapters.push(ChapterInfo {
                    chapter_id,
                    title,
                    start_index: start,
                    end_index: content.len() as i64,
                    content_length: content.len() as i64 - start,
                    index: chapter_id,
                });
            }
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
fn chinese_number_to_int(num_str: &str) -> i32 {
    let num_str = num_str.trim();

    // 处理阿拉伯数字
    if let Ok(n) = num_str.parse::<i32>() {
        return n;
    }

    // 简单处理中文数字
    let mut result = 0;
    let mut temp = 0;

    for c in num_str.chars() {
        match c {
            '零' | '〇' => {}
            '一' | '壹' => temp = temp.max(1),
            '二' | '两' | '贰' => temp = temp.max(2),
            '三' | '叁' => temp = temp.max(3),
            '四' | '肆' => temp = temp.max(4),
            '五' | '伍' => temp = temp.max(5),
            '六' | '陆' => temp = temp.max(6),
            '七' | '柒' => temp = temp.max(7),
            '八' | '捌' => temp = temp.max(8),
            '九' | '玖' => temp = temp.max(9),
            '十' | '拾' => {
                result += (temp.max(1)) * 10;
                temp = 0;
            }
            '百' | '佰' => {
                result += (temp.max(1)) * 100;
                temp = 0;
            }
            '千' | '仟' => {
                result += (temp.max(1)) * 1000;
                temp = 0;
            }
            '万' | '萬' => {
                result = (result + temp) * 10000;
                temp = 0;
            }
            _ => {}
        }
    }

    result + temp
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
