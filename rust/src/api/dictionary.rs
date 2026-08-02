//! 词典服务 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::dictionary::dictionary_repo::DictionaryRepository;
use crate::domain::dictionary::service;
use crate::domain::dictionary::{models::Dictionary, DictSearchResult};
use crate::infra::manager::storage_pool;

// ==================== 词典数据 CRUD ====================

/// 创建词典记录
#[frb]
pub async fn create_dictionary(
    name: String,
    file_path: String,
    dict_type: String,
    lang_from: Option<String>,
    lang_to: Option<String>,
    is_enabled: bool,
    word_count: i64,
) -> Result<Dictionary, AppError> {
    tracing::info!("[dictionary] create_dictionary: name={}", name);
    let dict = Dictionary::new(
        &name, &file_path, &dict_type, lang_from, lang_to, is_enabled, word_count,
    );
    let pool = storage_pool()?;
    DictionaryRepository::save(&pool, &dict).await
}

/// 新增或更新词典
#[frb]
pub async fn upsert_dictionary(dict: Dictionary) -> Result<(), AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::save(&pool, &dict).await.map(|_| ())
}

/// 获取所有词典列表
#[frb]
pub async fn list_dictionaries() -> Result<Vec<Dictionary>, AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::find_all(&pool).await
}

/// 根据 ID 获取词典
#[frb]
pub async fn get_dictionary(id: String) -> Result<Option<Dictionary>, AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::find_by_id(&pool, &id).await
}

/// 删除词典
#[frb]
pub async fn delete_dictionary(id: String) -> Result<bool, AppError> {
    tracing::info!("[dictionary] delete_dictionary: id={}", id);
    let pool = storage_pool()?;
    DictionaryRepository::delete(&pool, &id).await
}

// ==================== 词典引擎管理 ====================

/// 初始化 MDict 词典引擎
#[frb]
pub async fn init_dictionary(mdx_path: String, mdd_path: Option<String>) -> Result<(), AppError> {
    tracing::info!("[dictionary] init_dictionary: mdx_path={}", mdx_path);
    service::init_dictionary(&mdx_path, mdd_path).await
}

/// 关闭当前词典引擎
#[frb(sync)]
pub fn close_dictionary() {
    service::close_dictionary()
}

// ==================== 词典查询 ====================

/// 精确查询单词
#[frb]
pub async fn lookup_mdict(word: String) -> Result<Option<DictSearchResult>, AppError> {
    tracing::debug!("[dictionary] lookup_mdict: word={}", word);
    service::lookup_mdict(&word).await
}

/// 前缀搜索自动补全
#[frb]
pub async fn suggest_mdict(prefix: String, limit: i32) -> Result<Vec<String>, AppError> {
    tracing::debug!("[dictionary] suggest_mdict: prefix={}", prefix);
    service::suggest_mdict(&prefix, limit).await
}

/// 从 .mdd 提取音频
#[frb]
pub async fn extract_audio(audio_key: String) -> Result<Option<Vec<u8>>, AppError> {
    tracing::debug!("[dictionary] extract_audio: audio_key={}", audio_key);
    service::extract_audio(&audio_key).await
}
