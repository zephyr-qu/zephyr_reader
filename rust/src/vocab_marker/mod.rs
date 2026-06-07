//! 词汇标记模块
//!
//! 提供英文词汇的自动识别与匹配功能，从文本中扫描内置词汇表中的高频词。
//! 词汇表包括 CET6、IELTS、TOEFL 等考试词库。
/// 内置词汇表子模块（CET6、IELTS、TOEFL 词库）
pub mod wordlists;

use std::sync::LazyLock;

use regex::Regex;

/// A vocabulary word match found in text.
pub struct VocabularyMatch {
    pub word: String,
    pub start: usize,
    pub end: usize,
}

/// 英文词汇匹配正则表达式（识别连续字母组成的单词，包括缩写形式）
pub static VOCAB_MATCH: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[a-zA-Z]+(?:'[a-zA-Z]+)?").expect("static regex is valid"));


/// Scan text for vocabulary words from all built-in word lists (CET6, IELTS, TOEFL).
/// Returns all matches with their positions.
///
/// The regex matches English words including contractions (e.g. "don't", "it's").
/// Matching is case-insensitive.
pub fn scan_for_vocabulary(text: &str) -> Vec<VocabularyMatch> {
    VOCAB_MATCH.find_iter(text)
        .filter(|m| wordlists::contains(&text[m.start()..m.end()]))
        .map(|m| VocabularyMatch {
            word: text[m.start()..m.end()].to_string(),
            start: m.start(),
            end: m.end(),
        })
        .collect()
}
