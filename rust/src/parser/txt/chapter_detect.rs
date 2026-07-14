// ============================================================
// 文件作用：章节标题自动检测，识别中英文小说的章节标题
//
// 原路径：src/text/chapter_detect.rs
// 迁移至：src/parser/txt/chapter_detect.rs
//
// 公有类型/函数：
//   - extract_chapters() — 从文本中提取章节列表
//
// 私有函数：
//   - extract_chapters_with_pattern() — 使用单个正则提取章节
// ============================================================

//! 章节标题自动检测
//! 识别中文和英文小说的章节标题

use std::sync::LazyLock;

use regex::Regex;

use crate::storage::models::Chapter;

// ==================== 排版常量 ====================

/// 排版：最小行宽（字符数）
/// 防止行宽过小导致文本过度换行
pub const MIN_CHARS_PER_LINE: usize = 10;

// ==================== 共享正则表达式 ====================

/// HTML 标签匹配正则表达式
/// 用于移除 HTML 标签
pub static TAG_PATTERN: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<[^>]*>").expect("TAG_PATTERN 正则表达式编译失败"));

/// 中文章节匹配模式
/// 识别中文小说的章节标题（如"第一章"、"第壹回"等）
pub static CHAPTER_PATTERN_ZH: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?m)^(?:第\s*)?([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟 0-9]+)\s*[章回卷节部篇集]\s*(.+)?$|^(?:楔子|序[言引]?|前言|引子|尾声|完结|番外|后记|自序|代序|跋|附录|\S+版自序)\s*(.+)?$"
    ).expect("CHAPTER_PATTERN_ZH 正则表达式编译失败")
});

/// 中文枚举章节：行首「一、标题」「二．标题」（无「章回」字样）
pub static CHAPTER_PATTERN_ZH_ENUM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?m)^([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8})\s*[、.．:：]\s*(\S.+)$",
    )
    .expect("CHAPTER_PATTERN_ZH_ENUM 正则表达式编译失败")
});

/// 英文章节匹配模式
/// 识别英文小说的章节标题（如"Chapter 1"、"Part I"等）
pub static CHAPTER_PATTERN_EN: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?mi)^(?:Chapter\s+\d+|[IVX]+\.[\s.]|[IVX]+\s+[A-Z]|\bPart\s+\d+|Book\s+\d+|Prologue|Epilogue|Preface|Introduction|Conclusion)\s*:?\s*(.*)$"
    ).expect("CHAPTER_PATTERN_EN 正则表达式编译失败")
});

/// 数字章节匹配模式
/// 识别纯数字章节（如"1. Title"、"2、标题"等）
pub static CHAPTER_PATTERN_DIGIT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?m)^(\d+)[\s.、:：](.+)$").expect("CHAPTER_PATTERN_DIGIT 正则表达式编译失败")
});

/// 行首禁断标点（CJK + 英文）
/// 这些标点不应出现在一行开头
pub const START_AVOID_PUNCTUATION: &[char] = &[
    '，', '。', '、', '；', '：', '？', '！', '…', '—', '）', '】', '》', '」', '』', '!', ',',
    '.', '?', ':',
];

/// 行尾禁断标点（CJK 开括号）
/// 这些开括号不应出现在一行结尾
pub const END_AVOID_PUNCTUATION: &[char] = &['（', '【', '《', '「', '『'];

/// 判断是否为行首禁断标点
pub fn is_start_avoid_punctuation(c: char) -> bool {
    START_AVOID_PUNCTUATION.contains(&c)
}

/// 判断是否为行尾禁断标点
pub fn is_end_avoid_punctuation(c: char) -> bool {
    END_AVOID_PUNCTUATION.contains(&c)
}

/// 判断是否为 CJK 字符
pub fn is_cjk_char(c: char) -> bool {
    let cp = c as u32;
    (0x4E00..=0x9FFF).contains(&cp)
        || (0x3400..=0x4DBF).contains(&cp)
        || (0xF900..=0xFAFF).contains(&cp)
        || (0x3000..=0x303F).contains(&cp)
}

/// 判断是否为 CJK 标点符号
///
/// 包括全角逗号、句号、引号、括号等 CJK 专属标点。
/// 不包含中日韩统一表意文字（ideographs）。
pub fn is_cjk_punctuation(c: char) -> bool {
    let cp = c as u32;
    // CJK Symbols and Punctuation (U+3000–303F):  、。！＂＃＄％＆＇（）＊＋，－．／：；＜＝＞？＠［＼］＾＿｀｛｜｝～
    (0x3000..=0x303F).contains(&cp)
    // CJK Compatibility Forms (U+FE30–FE4F): ︰︱︲︳︴︵︶︷︸︹︺︻︼︽︾︿﹀﹁﹂﹃﹄﹅﹆﹇﹈
    || (0xFE30..=0xFE4F).contains(&cp)
    // Vertical Forms (U+FE10–FE1F)
    || (0xFE10..=0xFE1F).contains(&cp)
    // Fullwidth ASCII variants (U+FF00–FFEF), excluding fullwidth Latin letters (U+FF21–FF3A, U+FF41–FF5A)
    || (0xFF00..=0xFFEF).contains(&cp)
        && !(0xFF21..=0xFF3A).contains(&cp)
        && !(0xFF41..=0xFF5A).contains(&cp)
    // Common CJK punctuation outside these blocks
    || matches!(c, '·' | '～' | '×' | '÷')
}

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
