//! 搜索 API

use crate::domain::{AppError, SearchResult};
use crate::search::SearchEngine;
use crate::storage::storage_pool;
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use tokio::sync::Mutex;


/// 全局搜索引擎单例
static SEARCH_ENGINE: OnceCell<Mutex<SearchEngine>> = OnceCell::new();

/// 初始化搜索引擎
#[frb]
pub async fn init_search_engine() -> Result<(), AppError> {
    let pool = storage_pool()?;
    let engine = SearchEngine::new(pool.clone());
    engine.ensure_table().await.map_err(|e| {
        AppError::internal(format!("Failed to create FTS5 table: {e}"))
    })?;
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
pub async fn index_chapter(
    book_id: String,
    chapter_id: String,
    chapter_index: String,
    chapter_title: String,
    content: String,
) -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .await
        .index_chapter(&book_id, &chapter_id,&chapter_index, &chapter_title, &content)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}

/// 在书籍中搜索
#[frb]
pub async fn search(
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

/// 搜索所有书籍内容
#[frb]
pub async fn search_all_books(
    query: String,
    limit: i32,
) -> Result<Vec<SearchResult>, AppError> {
    let engine = get_search_engine()?;
    let limit = limit.max(0) as usize;
    let results = engine
        .lock()
        .await
        .search_all_books(&query, limit)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(results)
}

/// 清除所有搜索索引
#[frb]
pub async fn clear_all() -> Result<(), AppError> {
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
pub async fn delete_by_book(book_id: String) -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .lock()
        .await
        .delete_by_book(&book_id)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}
