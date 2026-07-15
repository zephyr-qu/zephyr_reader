//! 生词管理业务逻辑
//!
//! 提供生词的 CRUD、状态管理和统计功能。
//! 数据访问委托给 VocabRepository。

use crate::common::AppError;
use crate::domain::vocabulary::models::{Vocab, VocabStats, VocabStatus};
use crate::domain::vocabulary::vocab_repo::VocabRepository;
use crate::infra::manager::storage_pool;

/// 创建生词记录
#[allow(clippy::too_many_arguments)]
pub async fn create_vocabulary_word(
    word: &str,
    pinyin: &str,
    translation: &str,
    context_sentence: Option<String>,
    book_id: Option<String>,
    chapter_index: Option<i64>,
    char_offset: Option<i64>,
    word_list: Option<String>,
) -> Result<Vocab, AppError> {
    let vocab = Vocab::new(word, pinyin, translation, context_sentence, book_id, chapter_index, char_offset, word_list);
    let pool = storage_pool()?;
    VocabRepository::save(&pool, &vocab).await
}

/// 根据状态筛选生词
pub async fn list_vocabulary_by_status(
    book_id: Option<String>,
    status: Option<VocabStatus>,
    word_list: Option<String>,
) -> Result<Vec<Vocab>, AppError> {
    let pool = storage_pool()?;
    VocabRepository::find_by_status(&pool, book_id.as_deref(), status, word_list.as_deref()).await
}

/// 搜索生词
pub async fn search_vocabulary_words(query: &str) -> Result<Vec<Vocab>, AppError> {
    let pool = storage_pool()?;
    VocabRepository::search(&pool, query).await
}

/// 更新生词状态
pub async fn update_vocabulary_status(id: &str, status: VocabStatus) -> Result<(), AppError> {
    let pool = storage_pool()?;
    VocabRepository::update_by_status(&pool, id, status).await
}

/// 删除生词
pub async fn delete_vocabulary(id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    VocabRepository::delete_by_id(&pool, id).await
}

/// 获取生词统计信息
pub async fn get_vocabulary_stats() -> Result<VocabStats, AppError> {
    let pool = storage_pool()?;
    VocabRepository::count(&pool).await
}
