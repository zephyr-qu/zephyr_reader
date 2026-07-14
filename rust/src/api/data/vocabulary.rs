//! 生词管理 API
//!
//! 提供生词的 CRUD 操作、状态管理、搜索和统计功能。
use flutter_rust_bridge::frb;

use super::async_storage;
pub use crate::storage::models::{Vocab, VocabStats};
use crate::storage::repos::VocabRepository;
use crate::{domain::AppError, storage::models::VocabStatus};

// ============================================================
// 文件作用：生词管理 API — 生词 CRUD、状态管理、搜索、统计。
//
// 公有函数：
//   - create_vocabulary_word() — 创建生词记录
//   - list_vocabulary_by_status() — 按状态筛选生词
//   - search_vocabulary_words() — 搜索生词
//   - update_vocabulary_status() — 更新生词状态
//   - delete_vocabulary() — 删除生词
//   - get_vocabulary_stats() — 生词统计
//   - list_word_lists() — 内置词库名称列表
// ============================================================

/// 创建生词记录（自动生成 UUID）
///
/// # 参数
/// * `word` - 单词
/// * `pinyin` - 拼音
/// * `translation` - 释义
/// * `context_sentence` - 上下文句子（可选）
/// * `book_id` - 所属书籍 ID（可选）
/// * `chapter_index` - 章节索引（可选）
/// * `char_offset` - 字符偏移（可选）
/// * `word_list` - 单词本名称（可选）
///
/// # 返回
/// 创建完成的生词对象
#[allow(clippy::too_many_arguments)]
#[frb]
pub async fn create_vocabulary_word(
    word: String,
    pinyin: String,
    translation: String,
    context_sentence: Option<String>,
    book_id: Option<String>,
    chapter_index: Option<i32>,
    char_offset: Option<i64>,
    word_list: Option<String>,
) -> Result<Vocab, AppError> {
    tracing::info!("[vocab] create_vocabulary_word: word={}", word);
    let vocab = Vocab::new(
        &word,
        &pinyin,
        &translation,
        context_sentence.as_deref(),
        book_id.as_deref(),
        chapter_index.map(|v| v as i64),
        char_offset,
        word_list.as_deref(),
    );
    async_storage!(|pool| VocabRepository::save(pool, &vocab))
}

/// 新增或更新生词记录(upsert)

/// 根据状态筛选获取生词列表
///
/// # 参数
/// * `book_id` - 书籍 ID(可选)
/// * `status` - 生词状态(可选)
/// * `word_list` - 单词本名称(可选)
///
/// # 返回
/// 符合条件的生词列表
#[frb]
pub async fn list_vocabulary_by_status(
    book_id: Option<String>,
    status: Option<VocabStatus>,
    word_list: Option<String>,
) -> Result<Vec<Vocab>, AppError> {
    async_storage!(|pool| VocabRepository::find_by_status(
        pool,
        book_id.as_deref(),
        status,
        word_list.as_deref()
    ))
}

/// 搜索生词
///
/// # 参数
/// * `query` - 搜索关键词(支持英文单词或中文释义)
///
/// # 返回
/// 匹配关键词的生词列表
#[frb]
pub async fn search_vocabulary_words(query: String) -> Result<Vec<Vocab>, AppError> {
    tracing::debug!("[vocab] search_vocabulary_words: query={}", query);
    async_storage!(|pool| VocabRepository::search(pool, &query))
}

/// 更新生词状态
///
/// # 参数
/// * `id` - 生词 ID
/// * `status` - 新的状态值
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_vocabulary_status(id: String, status: VocabStatus) -> Result<(), AppError> {
    tracing::debug!("[vocab] update_vocabulary_status: id={}, status={:?}", id, status);
    async_storage!(|pool| VocabRepository::update_by_status(pool, &id, status))
}

/// 删除生词
///
/// # 参数
/// * `id` - 生词 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_vocabulary(id: String) -> Result<(), AppError> {
    tracing::info!("[vocab] delete_vocabulary: id={}", id);
    async_storage!(|pool| VocabRepository::delete_by_id(pool, &id))
}

/// 获取生词统计信息
///
/// # 返回
/// 生词统计汇总数据
#[frb]
pub async fn get_vocabulary_stats() -> Result<VocabStats, AppError> {
    tracing::debug!("[vocab] get_vocabulary_stats");
    async_storage!(|pool| VocabRepository::count(pool))
}

/// 获取所有内置词库名称列表。
///
/// # 返回
/// 词库名称的字符串向量，例如 `["CET-4", "CET-6", "IELTS", "TOEFL"]`。
#[frb]
pub fn list_word_lists() -> Vec<String> {
    vec![
        "CET-4".to_string(),
        "CET-6".to_string(),
        "IELTS".to_string(),
        "TOEFL".to_string(),
    ]
}

