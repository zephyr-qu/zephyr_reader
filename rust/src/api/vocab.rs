//! 生词管理 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::vocab::{Vocab, VocabStats, VocabStatus};
use crate::domain::vocab::vocab_repo::VocabRepository;
use crate::infra::manager::storage_pool;
/// 创建生词记录
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
    let vocab = Vocab::new(&word, &pinyin, &translation, context_sentence, book_id, chapter_index.map(|v| v as i64), char_offset, word_list);
    let pool = storage_pool()?;
    VocabRepository::save(&pool, &vocab).await
}

/// 根据状态筛选生词
#[frb]
pub async fn list_vocabulary_by_status(
    book_id: Option<String>,
    status: Option<VocabStatus>,
    word_list: Option<String>,
) -> Result<Vec<Vocab>, AppError> {
    let pool = storage_pool()?;
    VocabRepository::find_by_status(&pool, book_id.as_deref(), status, word_list.as_deref()).await
  }
/// 搜索生词
#[frb]
pub async fn search_vocabulary_words(query: String) -> Result<Vec<Vocab>, AppError> {
    tracing::debug!("[vocab] search_vocabulary_words: query={}", query);
    let pool = storage_pool()?;
    VocabRepository::search(&pool, &query).await
  }
/// 更新生词状态
#[frb]
pub async fn update_vocabulary_status(id: String, status: VocabStatus) -> Result<(), AppError> {
    tracing::debug!("[vocab] update_vocabulary_status: id={}, status={:?}", id, status);
    let pool = storage_pool()?;
    VocabRepository::update_by_status(&pool, &id, status).await
  }
/// 删除生词
#[frb]
pub async fn delete_vocabulary(id: String) -> Result<(), AppError> {
    tracing::info!("[vocab] delete_vocabulary: id={}", id);
    let pool = storage_pool()?;
    VocabRepository::delete_by_id(&pool, &id).await
  }
/// 获取生词统计信息
#[frb]
pub async fn get_vocabulary_stats() -> Result<VocabStats, AppError> {
    tracing::debug!("[vocab] get_vocabulary_stats");
    let pool = storage_pool()?;
    VocabRepository::count(&pool).await
  }
/// 获取所有内置词库名称列表
#[frb]
pub fn list_word_lists() -> Vec<String> {
    vec![
        "CET-4".to_string(),
        "CET-6".to_string(),
        "IELTS".to_string(),
        "TOEFL".to_string(),
    ]
}
