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

/// 初始化搜索引擎
///
/// 与主数据库共享连接，确保索引操作参与主数据库事务。
/// `_db_path` 保留参数以兼容 Flutter 侧调用接口。
#[frb]
pub fn init_search_engine(_db_path: String) -> ApiResult<()> {
    // 初始化 Jieba 分词器（若词典缺失则返回明确错误而非 panic）
    crate::search::ensure_jieba().map_err(|e| {
        ParserError::InternalError(format!("搜索引擎初始化失败: {}", e))
    })?;

    let storage = crate::storage::ensure_storage()?;
    let db = storage.db();
    let engine = SearchEngine::new(db);
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

/// 删除指定书籍的所有搜索索引
///
/// 当书籍被删除时调用，防止搜索索引孤立。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
#[frb(sync)]
pub fn delete_book_search_index(book_id: String) -> ApiResult<()> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .delete_book(&book_id)?;
    Ok(())
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
