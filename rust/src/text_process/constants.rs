//! 文本处理模块常量
//! 定义排版相关的魔法数字常量和共享正则表达式模式

use once_cell::sync::Lazy;
use regex::Regex;

// ==================== 排版常量 ====================

/// 搜索索引分块大小（字符数）
/// 用于将文档分割成小块进行索引
pub const SEARCH_CHUNK_SIZE: usize = 500;

/// PDF 文本估算：每页默认字符数
/// 用于在无法精确计算时估算 PDF 文本内容量
pub const PDF_CHARS_PER_PAGE: usize = 500;

/// EPUB 分页：每页最小字符数
/// 防止分页过小导致性能问题
pub const EPUB_MIN_CHARS_PER_PAGE: usize = 500;

/// 排版：最小行宽（字符数）
/// 防止行宽过小导致文本过度换行
pub const MIN_CHARS_PER_LINE: usize = 10;

/// 章节最小长度（字符数）
/// 防止章节内容过短导致处理异常
pub const MIN_CHAPTER_LENGTH: usize = 10;

/// EPUB 估算：读取章节数上限
/// 用于估算平均每页字符数时最多读取的章节数
pub const EPUB_ESTIMATE_SAMPLE_CHAPTERS: usize = 10;

/// EPUB 分页：每页最小行数
/// 防止每页行数过少导致显示异常
pub const EPUB_MIN_LINES_PER_PAGE: usize = 10;

// ==================== 共享正则表达式 ====================

/// HTML 标签匹配正则表达式
/// 用于移除 HTML 标签
pub static TAG_PATTERN: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"<[^>]*>").expect("TAG_PATTERN 正则表达式编译失败"));

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
