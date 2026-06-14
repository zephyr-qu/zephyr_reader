//! 词典服务模块 (Dictionary Service)
//!
//! 提供 MDict (.mdx/.mdd) 词典查询、模糊搜索、分词功能。
//! - 使用 rs-mdict 加载 .mdx 词典文件
//! - 支持从 .mdd 提取音频资源
//! - 保留 jieba 中文分词（原 search 模块）

use std::sync::LazyLock;

use flutter_rust_bridge::frb;
use parking_lot::Mutex;

use crate::dictionary::DictSearchResult;
use crate::dictionary::MdictEngine;
use crate::domain::AppError;
use crate::storage::models::Dictionary;
use crate::storage::repos::DictionaryRepository;

// ==================== 词典数据 CRUD ====================

/// 创建词典记录（自动生成 UUID）
#[frb]
// TODO: 多词典管理页面（设置页），后续实现
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
        &name,
        &file_path,
        &dict_type,
        lang_from.as_deref(),
        lang_to.as_deref(),
        is_enabled,
        word_count,
    );
    crate::async_storage!(|pool| DictionaryRepository::save(pool, &dict))
}

/// 新增或更新词典(upsert)
// TODO: 多词典管理页面（设置页），后续实现
#[frb]
pub async fn upsert_dictionary(dict: Dictionary) -> Result<(), AppError> {
    crate::async_storage!(|pool| DictionaryRepository::save(pool, &dict)).map(|_| ())
}

/// 获取所有词典列表
// TODO: 多词典管理页面（设置页），后续实现
#[frb]
pub async fn list_dictionaries() -> Result<Vec<Dictionary>, AppError> {
    crate::async_storage!(|pool| DictionaryRepository::find_all(pool))
}

/// 根据 ID 获取词典
// TODO: 多词典管理页面（设置页），后续实现
#[frb]
pub async fn get_dictionary(id: String) -> Result<Option<Dictionary>, AppError> {
    crate::async_storage!(|pool| DictionaryRepository::find_by_id(pool, &id))
}

/// 删除词典
// TODO: 多词典管理页面（设置页），后续实现
#[frb]
pub async fn delete_dictionary(id: String) -> Result<bool, AppError> {
    tracing::info!("[dictionary] delete_dictionary: id={}", id);
    crate::async_storage!(|pool| DictionaryRepository::delete(pool, &id))
}

// ==================== 全局 MDict 引擎 ====================

/// MDict 词典引擎（单例，惰性初始化）
static MDICT: LazyLock<Mutex<Option<MdictEngine>>> = LazyLock::new(|| Mutex::new(None));

// ==================== 词典初始化和关闭 ====================

/// 初始化 MDict 词典引擎
///
/// # 参数
/// - `mdx_path`: .mdx 词典文件路径
/// - `mdd_path`: 可选的 .mdd 资源文件路径（音频/图片）
///
/// # 说明
/// 必须在调用其他词典功能前调用此函数，使用 OnceCell 确保只初始化一次。
/// 如需要切换词典，先调用 `close_dictionary()`。
#[frb]
pub async fn init_dictionary(mdx_path: String, mdd_path: Option<String>) -> Result<(), AppError> {
    tracing::info!("[dictionary] init_dictionary: mdx_path={}", mdx_path);
    let engine = MdictEngine::open(&mdx_path, mdd_path.as_deref())
        .map_err(|e| AppError::InternalError { reason: format!("Failed to open MDict: {e}").into() })?;

    let mut guard = MDICT.lock();
    if guard.is_some() {
        return Err(AppError::InternalError { reason: "Dictionary already initialized. Call close_dictionary() first.".into() });
    }
    *guard = Some(engine);
    Ok(())
}

/// 关闭当前词典引擎（释放文件句柄、重置状态）
///
/// 切换词典时先调用此函数，再调用 `init_dictionary()`。
#[frb(sync)]
pub fn close_dictionary() {
    *MDICT.lock() = None;
}

// ==================== 词典查询功能 ====================

/// 精确查询：在 MDict 词典中查找单词
///
/// # 参数
/// - `word`: 要查询的单词
///
/// # 返回
/// 返回 `DictSearchResult`，包含精确匹配条目和拼写纠错建议
#[frb]
pub async fn lookup_mdict(word: String) -> Result<Option<DictSearchResult>, AppError> {
    tracing::debug!("[dictionary] lookup_mdict: word={}", word);
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError { reason: "Dictionary not initialized. Call init_dictionary() first.".into() }
        })?;
        Ok(engine.lookup(&word))
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "lookup mdict".into(), details: e.to_string().into() })?
}

/// 前缀搜索：自动补全建议
///
/// # 参数
/// - `prefix`: 输入前缀
/// - `limit`: 最大返回数量（默认 10）
// TODO: Dart 侧计划在查词面板顶部添加搜索输入框 + 自动补全时使用
#[frb]
pub async fn suggest_mdict(prefix: String, limit: i32) -> Result<Vec<String>, AppError> {
    tracing::debug!("[dictionary] suggest_mdict: prefix={}", prefix);
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError { reason: "Dictionary not initialized. Call init_dictionary() first.".into() }
        })?;
        Ok(engine.suggest(&prefix, limit.max(1).min(50) as usize))
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "suggest mdict".into(), details: e.to_string().into() })?
}

/// 从 .mdd 资源文件中提取音频数据
///
/// # 参数
/// - `audio_key`: 音频资源在 .mdd 中的路径（如 `\hello.spx`）
///
/// # 返回
/// 返回音频文件的原始字节（WAV/SPX/MP3 格式），可用于直接播放
#[frb]
pub async fn extract_audio(audio_key: String) -> Result<Option<Vec<u8>>, AppError> {
    tracing::debug!("[dictionary] extract_audio: audio_key={}", audio_key);
    tokio::task::spawn_blocking(move || {
        let mut guard = MDICT.lock();
        let engine = guard.as_mut().ok_or_else(|| {
            AppError::InternalError { reason: "Dictionary not initialized. Call init_dictionary() first.".into() }
        })?;
        Ok(engine.extract_audio(&audio_key))
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "extract audio".into(), details: e.to_string().into() })?
}

// ==================== 中文分词功能 ====================

/// 中文文本分词：使用 jieba 将中文句子切分为词语
///
/// # 参数
/// - `text`: 待分词的中文文本
///
/// # 返回
/// 返回分词后的词语列表
///
/// # 示例
/// 输入："我喜欢学习中文"
/// → 输出：["我", "喜欢", "学习", "中文"]
///
/// # 用途
/// 用于阅读时的生词识别、点击查词等功能（词典独立）
#[frb]
pub async fn segment_text(text: String) -> Result<Vec<String>, AppError> {
    tracing::debug!("[dictionary] segment_text: len={}", text.len());
    let tokenized = crate::search::tokenize_chinese_text(&text);
    Ok(tokenized.split_whitespace().map(String::from).collect())
}
