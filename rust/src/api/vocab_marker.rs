//! 生词标记 FFI API
//!
//! 提供在文本中扫描内置词库（CET-6、IELTS、TOEFL）生词的功能。
//! 用于在阅读器中高亮标记已知词汇表中的单词。

use crate::{
    domain::AppError,
    vocab_marker::{self as engine},
};
use flutter_rust_bridge::frb;
#[frb]
pub struct VocabMatch {
    /// 匹配到的单词
    pub word: String,
    /// 在文本中的起始位置（字符偏移）
    pub start: i64,
    /// 在文本中的结束位置（字符偏移）
    pub end: i64,
}

/// 在文本中扫描生词
///
/// 使用所有内置词库（CET-6、IELTS、TOEFL）扫描文本，返回匹配的单词及其位置。
/// # 返回值
/// 返回所有匹配的单词及其在文本中的位置
#[frb(sync)]
pub fn scan_for_vocabulary(text: &str) -> Result<Vec<VocabMatch>, AppError> {
    Ok(engine::scan_for_vocabulary(text)
        .into_iter()
        .map(|m| VocabMatch {
            word: m.word,
            start: m.start as i64,
            end: m.end as i64,
        })
        .collect())
}

/// 获取所有内置词汇表中的单词（扁平列表）
///
/// 用于 Dart 端一次性初始化生词集合
#[frb(sync)]
pub fn get_all_vocabulary_words() -> Result<Vec<String>, AppError> {
    Ok(engine::wordlists::all_words())
}

/// 获取所有 CET-6 词汇
#[frb(sync)]
pub fn get_cet6_words() -> Result<Vec<String>, AppError> {
    Ok(engine::wordlists::cet6_words())
}

/// 获取所有 IELTS 词汇
#[frb(sync)]
pub fn get_ielts_words() -> Result<Vec<String>, AppError> {
    Ok(engine::wordlists::ielts_words())
}

/// 获取所有 TOEFL 词汇
#[frb(sync)]
pub fn get_toefl_words() -> Result<Vec<String>, AppError> {
    Ok(engine::wordlists::toefl_words())
}
