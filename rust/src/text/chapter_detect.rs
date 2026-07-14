// ============================================================
// 文件作用：章节标题自动检测，识别中英文小说的章节标题
//
// 公有类型/函数：
//   - extract_chapters() — 从文本中提取章节列表
//
// 私有函数：
//   - extract_chapters_with_pattern() — 使用单个正则提取章节
// ============================================================

//! 章节标题自动检测
//! 识别中文和英文小说的章节标题

use crate::storage::models::Chapter;
use crate::text::constants::{
    CHAPTER_PATTERN_DIGIT, CHAPTER_PATTERN_EN, CHAPTER_PATTERN_ZH, CHAPTER_PATTERN_ZH_ENUM,
};
use regex::Regex;

/// 从文本中提取章节信息
///
/// # 参数
/// * `content` - 文本内容
/// * `max_chapters` - 最大章节数
/// * `book_id` - 所属书籍 ID，填入每个章节的 book_id 字段
pub fn extract_chapters(content: &str, max_chapters: i32, book_id: &str) -> Vec<Chapter> {
    // 中文「章回」→ 中文「一、」枚举 → 英文 → 数字
    let patterns: [&Regex; 4] = [
        &*CHAPTER_PATTERN_ZH,
        &*CHAPTER_PATTERN_ZH_ENUM,
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

            // Use sequential index (0, 1, 2, …) rather than text-derived
            // chapter numbers. Text-derived numbers can have gaps, duplicates,
            // or be misparsed (e.g. "Chapter 1" → Roman "C"=100), breaking
            // chapter lookups for progress, bookmarks, notes, and sessions.
            let chapter_index = chapters.len() as i32;

            chapters.push(Chapter::new(
                book_id,
                &title,
                chapter_index as i64,
                0,
                start,
                content_len,
            ));
        }
    }

    chapters
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_chapters_zh_enum() {
        let content = "一、开端\n内容甲\n\n二、发展\n内容乙\n\n三、结局\n内容丙\n";
        let chapters = extract_chapters(content, 100, "test_book");
        assert_eq!(chapters.len(), 3);
        assert!(chapters[0].title.starts_with("一、"));
        assert!(chapters[1].title.starts_with("二、"));
    }

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
}
