//! 文本处理模块常量
//! 定义排版相关的魔法数字常量和共享正则表达式模式

use std::sync::LazyLock;

use regex::Regex;

// ==================== 排版常量 ====================

/// PDF 文本估算：每页默认字符数
/// 用于在无法精确计算时估算 PDF 文本内容量
pub const PDF_CHARS_PER_PAGE: usize = 500;

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
