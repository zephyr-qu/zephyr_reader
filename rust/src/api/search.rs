//! 搜索 API

pub use crate::api::ApiResult;
use crate::{api::SearchResult, search::SearchEngine};
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;

/// 全局搜索引擎单例
static SEARCH_ENGINE: OnceCell<Mutex<SearchEngine>> = OnceCell::new();

/// 初始化搜索引擎（需要数据库路径）
#[frb]
pub fn init_search_engine(db_path: String) -> ApiResult<()> {
    let engine = SearchEngine::open_or_create(&db_path)?;
    SEARCH_ENGINE
        .set(Mutex::new(engine))
        .map_err(|_| anyhow::anyhow!("Search engine already initialized"))?;
    Ok(())
}

/// 获取搜索引擎实例
fn get_search_engine() -> Result<&'static Mutex<SearchEngine>, anyhow::Error> {
    SEARCH_ENGINE.get().ok_or_else(|| {
        anyhow::anyhow!("Search engine not initialized. Call init_search_engine() first.")
    })
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
#[frb]
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
        .map_err(|e| anyhow::anyhow!("Failed to clear search index: {}", e))?;
    Ok(())
}
