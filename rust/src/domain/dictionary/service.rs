//! 词典业务逻辑
//!
//! 引擎操作委托给 Engine，数据访问委托给 DictionaryRepository。
//! 数据访问委托给 DictionaryRepository，引擎操作委托给 MdictEngine。

use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::common::AppError;
use crate::domain::dictionary::dictionary_repo::DictionaryRepository;
use crate::domain::dictionary::DictSearchResult;
use crate::domain::dictionary::engine::Engine;
use crate::domain::dictionary::models::Dictionary;
use crate::infra::manager::storage_pool;

// ==================== 全局 MDict 引擎 ====================

static MDICT: LazyLock<Mutex<Option<Engine>>> = LazyLock::new(|| Mutex::new(None));

// ==================== 词典数据 CRUD ====================

/// 创建词典记录
pub async fn create_dictionary(
    name: &str,
    file_path: &str,
    dict_type: &str,
    lang_from: Option<String>,
    lang_to: Option<String>,
    is_enabled: bool,
    word_count: i64,
) -> Result<Dictionary, AppError> {
    let dict = Dictionary::new(name, file_path, dict_type, lang_from, lang_to, is_enabled, word_count);
    let pool = storage_pool()?;
    DictionaryRepository::save(&pool, &dict).await
}

/// 新增或更新词典
pub async fn upsert_dictionary(dict: &Dictionary) -> Result<(), AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::save(&pool, dict).await.map(|_| ())
}

/// 获取所有词典列表
pub async fn list_dictionaries() -> Result<Vec<Dictionary>, AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::find_all(&pool).await
}

/// 根据 ID 获取词典
pub async fn get_dictionary(id: &str) -> Result<Option<Dictionary>, AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::find_by_id(&pool, id).await
}

/// 删除词典
pub async fn delete_dictionary(id: &str) -> Result<bool, AppError> {
    let pool = storage_pool()?;
    DictionaryRepository::delete(&pool, id).await
}

// ==================== 词典引擎管理 ====================

/// 初始化 MDict 词典引擎
pub async fn init_dictionary(mdx_path: &str, mdd_path: Option<String>) -> Result<(), AppError> {
    let engine = Engine::open(mdx_path, mdd_path.as_deref())
        .map_err(|e| AppError::InternalError {
            reason: format!("Failed to open MDict: {e}"),
        })?;
    let mut guard = MDICT.lock();
    if guard.is_some() {
        return Err(AppError::InternalError {
            reason: "Dictionary already initialized. Call close_dictionary() first.".into(),
        });
    }
    *guard = Some(engine);
    Ok(())
}

/// 关闭当前词典引擎
pub fn close_dictionary() {
    *MDICT.lock() = None;
}

/// 精确查询单词
pub async fn lookup_mdict(word: &str) -> Result<Option<DictSearchResult>, AppError> {
    let word = word.to_string();
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError {
                reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
            }
        })?;
        Ok(engine.lookup(&word))
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "lookup mdict".into(),
        details: e.to_string(),
    })?
}

/// 前缀搜索自动补全
pub async fn suggest_mdict(prefix: &str, limit: i32) -> Result<Vec<String>, AppError> {
    let prefix = prefix.to_string();
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError {
                reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
            }
        })?;
        Ok(engine.suggest(&prefix, limit.clamp(1, 50) as usize))
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "suggest mdict".into(),
        details: e.to_string(),
    })?
}

/// 从 .mdd 提取音频
pub async fn extract_audio(audio_key: &str) -> Result<Option<Vec<u8>>, AppError> {
    let audio_key = audio_key.to_string();
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError {
                reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
            }
        })?;
        Ok(engine.extract_audio(&audio_key))
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "extract audio".into(),
        details: e.to_string(),
    })?
}

