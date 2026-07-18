//! 词典业务逻辑
//!
//! 引擎操作委托给 Engine，数据访问委托给 DictionaryRepository。
//! 纯 CRUD 透传已内联到 api/ 层，此处只保留有实际业务逻辑的操作。

use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::common::AppError;
use crate::common::security::validate_file_path;
use crate::domain::dictionary::DictSearchResult;
use crate::domain::dictionary::engine::Engine;

// ==================== 全局 MDict 引擎 ====================

static MDICT: LazyLock<Mutex<Option<Engine>>> = LazyLock::new(|| Mutex::new(None));

// ==================== 词典引擎管理 ====================

/// 初始化 MDict 词典引擎
pub async fn init_dictionary(mdx_path: &str, mdd_path: Option<String>) -> Result<(), AppError> {
    let validated_mdx = validate_file_path(mdx_path)?;
    let engine =
        Engine::open(&validated_mdx, mdd_path.as_deref()).map_err(|e| AppError::InternalError {
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

// ==================== 词典查询 ====================

/// 精确查询单词
pub async fn lookup_mdict(word: &str) -> Result<Option<DictSearchResult>, AppError> {
    let word = word.to_string();
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| AppError::InternalError {
            reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
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
        let engine = guard.as_mut().ok_or_else(|| AppError::InternalError {
            reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
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
        let engine = guard.as_mut().ok_or_else(|| AppError::InternalError {
            reason: "Dictionary not initialized. Call init_dictionary() first.".into(),
        })?;
        Ok(engine.extract_audio(&audio_key))
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "extract audio".into(),
        details: e.to_string(),
    })?
}
