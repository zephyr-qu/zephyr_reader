//! 生词管理 API
//!
//! 提供生词的 CRUD 操作、状态管理、搜索和统计功能。
use flutter_rust_bridge::frb;

use super::async_storage;
pub use crate::storage::models::{Vocab, VocabStats};
use crate::storage::repos::VocabRepository;
use crate::{domain::AppError, storage::models::VocabStatus};

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
    async_storage!(|pool| VocabRepository::delete_by_id(pool, &id))
}

/// 获取生词统计信息
///
/// # 返回
/// 生词统计汇总数据
#[frb]
pub async fn get_vocabulary_stats() -> Result<VocabStats, AppError> {
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

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::test_utils::init_test_storage;

//     #[tokio::test]
//     async fn test_add_and_find_vocab_word() {
//         init_test_storage().await;
//         let entry = add_vocabulary_word(
//             "abandon".into(), "fàng qì".into(), "放弃".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         assert_eq!(entry.word, "abandon");
//         assert_eq!(entry.status, "learning");
//         let words = find_vocabulary_words(None, None, None).await.unwrap();
//         assert_eq!(words.len(), 1);
//         assert_eq!(words[0].word, "abandon");
//     }

//     #[tokio::test]
//     async fn test_add_vocab_word_with_book_and_word_list() {
//         init_test_storage().await;
//         let entry = add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             Some("Hello, world!".into()), Some("book1".into()),
//             Some(1), Some(100), Some("CET-4".into()),
//         ).await.unwrap();
//         assert_eq!(entry.book_id.unwrap(), "book1");
//         assert_eq!(entry.word_list.unwrap(), "CET-4");
//         assert_eq!(entry.chapter_index.unwrap(), 1);
//         assert_eq!(entry.char_offset.unwrap(), 100);
//     }

//     #[tokio::test]
//     async fn test_find_vocab_words_filter_by_status() {
//         init_test_storage().await;
//         let entry = add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         update_vocabulary_status(entry.id.clone(), "known".into()).await.unwrap();
//         let learning = find_vocabulary_words(None, Some("learning".into()), None).await.unwrap();
//         assert!(learning.is_empty());
//         let known = find_vocabulary_words(None, Some("known".into()), None).await.unwrap();
//         assert_eq!(known.len(), 1);
//     }

//     #[tokio::test]
//     async fn test_find_vocab_words_filter_by_word_list() {
//         init_test_storage().await;
//         add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             None, None, None, None, Some("CET-4".into()),
//         ).await.unwrap();
//         add_vocabulary_word(
//             "world".into(), "".into(), "世界".into(),
//             None, None, None, None, Some("CET-6".into()),
//         ).await.unwrap();
//         let cet4 = find_vocabulary_words(None, None, Some("CET-4".into())).await.unwrap();
//         assert_eq!(cet4.len(), 1);
//         assert_eq!(cet4[0].word, "hello");
//         let cet6 = find_vocabulary_words(None, None, Some("CET-6".into())).await.unwrap();
//         assert_eq!(cet6.len(), 1);
//         assert_eq!(cet6[0].word, "world");
//     }

//     #[tokio::test]
//     async fn test_search_vocabulary() {
//         init_test_storage().await;
//         add_vocabulary_word(
//             "abandon".into(), "fàng qì".into(), "放弃".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         add_vocabulary_word(
//             "absorb".into(), "xī shōu".into(), "吸收".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         let results = search_vocabulary("abandon".into()).await.unwrap();
//         assert_eq!(results.len(), 1);
//         let no_results = search_vocabulary("zzzzz".into()).await.unwrap();
//         assert!(no_results.is_empty());
//     }

//     #[tokio::test]
//     async fn test_update_vocabulary_status() {
//         init_test_storage().await;
//         let entry = add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         update_vocabulary_status(entry.id.clone(), "mastered".into()).await.unwrap();
//         let words = find_vocabulary_words(None, None, None).await.unwrap();
//         assert_eq!(words[0].status, "mastered");
//     }

//     #[tokio::test]
//     async fn test_delete_vocabulary_word() {
//         init_test_storage().await;
//         let entry = add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         delete_vocabulary_word(entry.id.clone()).await.unwrap();
//         let words = find_vocabulary_words(None, None, None).await.unwrap();
//         assert!(words.is_empty());
//     }

//     #[tokio::test]
//     async fn test_find_vocabulary_stats() {
//         init_test_storage().await;
//         add_vocabulary_word(
//             "hello".into(), "".into(), "你好".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         add_vocabulary_word(
//             "world".into(), "".into(), "世界".into(),
//             None, None, None, None, None,
//         ).await.unwrap();
//         let stats = find_vocabulary_stats().await.unwrap();
//         assert_eq!(stats.total_words, 2);
//         assert_eq!(stats.learning_count, 2);
//     }
// }
