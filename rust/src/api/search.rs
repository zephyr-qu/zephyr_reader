//! 搜索 API

pub use crate::api::ApiResult;
use crate::api::ParserError;
use crate::search::SearchEngine;
pub use crate::ffi::SearchResult;
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;

/// 全局搜索引擎单例
static SEARCH_ENGINE: OnceCell<Mutex<SearchEngine>> = OnceCell::new();

/// 初始化搜索引擎（需要数据库路径）
#[frb]
pub fn init_search_engine(db_path: String) -> ApiResult<()> {
    // 验证数据库路径在允许的基目录内
    let path = std::path::Path::new(&db_path);
    if let Some(parent) = path.parent().and_then(|p| p.to_str()) {
        if !parent.is_empty() {
            // 验证父目录（数据库文件可能还不存在，但父目录必须存在且在允许的基目录内）
            crate::api::security::validate_file_path(parent)?;
        }
    }

    let engine = SearchEngine::open_or_create(&db_path)?;
    SEARCH_ENGINE
        .set(Mutex::new(engine))
        .map_err(|_| ParserError::InternalError("Search engine already initialized".into()))?;
    Ok(())
}

/// 获取搜索引擎实例
fn get_search_engine() -> ApiResult<&'static Mutex<SearchEngine>> {
    SEARCH_ENGINE
        .get()
        .ok_or_else(|| ParserError::InternalError("Search engine not initialized. Call init_search_engine() first.".into()))
}

/// 索引章节内容
///
/// 将指定章节的文本内容添加到搜索索引中。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `chapter_id` - 章节ID
/// * `chapter_title` - 章节标题
/// * `content` - 章节文本内容
#[frb]
pub fn index_chapter_content(
    book_id: String,
    chapter_id: i32,
    chapter_title: String,
    content: String,
) -> ApiResult<()> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .index_chapter(&book_id, chapter_id, &chapter_title, &content)?;
    Ok(())
}

/// 在书籍中搜索
///
/// 在指定书籍的索引中搜索关键词，返回匹配的搜索结果。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `query` - 搜索关键词
/// * `limit` - 返回结果数量限制
#[frb(sync)]
pub fn search_in_book(book_id: String, query: String, limit: i32) -> ApiResult<Vec<SearchResult>> {
    let engine = get_search_engine()?;
    let limit = limit.max(0) as usize;
    let results = engine.lock().search(&book_id, &query, limit)?;
    Ok(results)
}

/// 清除所有搜索索引
#[frb]
pub fn clear_all_search_index() -> ApiResult<()> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .clear_all()
        .map_err(|e| ParserError::InternalError(format!("Failed to clear search index: {}", e)))?;
    Ok(())
}
