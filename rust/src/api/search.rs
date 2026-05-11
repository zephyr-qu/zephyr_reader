//! 搜索 API

use crate::domain::{AppError, SearchResult};
use crate::search::SearchEngine;
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use tokio::sync::Mutex;

/// 全局搜索引擎单例
static SEARCH_ENGINE: OnceCell<Mutex<SearchEngine>> = OnceCell::new();

/// 初始化搜索引擎
#[frb]
pub async fn init_search_engine() -> Result<(), AppError> {
    let storage = crate::storage::ensure_storage()
        .map_err(|e| AppError::internal(e.to_string()))?;
    let pool = storage
        .pool()
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let engine = SearchEngine::new(pool);
    SEARCH_ENGINE
        .set(Mutex::new(engine))
        .map_err(|_| AppError::internal("Search engine already initialized"))?;
    Ok(())
}

/// 获取搜索引擎实例
pub(crate) fn get_search_engine() -> Result<&'static Mutex<SearchEngine>, AppError> {
    SEARCH_ENGINE
        .get()
        .ok_or_else(|| AppError::internal("Search engine not initialized. Call init_search_engine() first."))
}

/// 索引章节内容
#[frb]
pub async fn index_chapter_content(
    book_id: String,
    chapter_id: i32,
    chapter_title: String,
    content: String,
) -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .await
        .index_chapter(&book_id, chapter_id, &chapter_title, &content)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}

/// 在书籍中搜索
#[frb]
pub async fn search_in_book(
    book_id: String,
    query: String,
    limit: i32,
) -> Result<Vec<SearchResult>, AppError> {
    let engine = get_search_engine()?;
    let limit = limit.max(0) as usize;
    let results = engine
        .lock()
        .await
        .search(&book_id, &query, limit)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(results)
}

/// 清除所有搜索索引
#[frb]
pub async fn clear_all_search_index() -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .await
        .clear_all()
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}

/// 删除某本书的搜索索引
#[frb]
pub async fn delete_book_search_index(book_id: String) -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .await
        .delete_book(&book_id)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}
