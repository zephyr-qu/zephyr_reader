//! 搜索 API

use std::sync::OnceLock;

use crate::domain::{AppError, SearchResult};
use crate::search::SearchEngine;
use crate::storage::storage_pool;
use flutter_rust_bridge::frb;

/// 全局搜索引擎单例
static SEARCH_ENGINE: OnceLock<SearchEngine> = OnceLock::new();

/// 初始化搜索引擎
#[frb]
pub async fn init_search_engine() -> Result<(), AppError> {
    if SEARCH_ENGINE.get().is_some() {
        return Ok(());
    }
    let pool = storage_pool()?;
    let engine = SearchEngine::new(pool.clone());
    engine
        .ensure_table()
        .await
        .map_err(|e| AppError::search_error(format!("Failed to create FTS5 table: {e}")))?;
    let _ = SEARCH_ENGINE.set(engine);
    Ok(())
}

/// 获取搜索引擎实例
pub(crate) fn get_search_engine() -> Result<&'static SearchEngine, AppError> {
    SEARCH_ENGINE.get().ok_or_else(|| {
        AppError::internal("Search engine not initialized. Call init_search_engine() first.")
    })
}

/// 索引章节内容
#[frb]
pub async fn index_chapter(
    book_id: String,
    chapter_id: String,
    chapter_index: i32,
    chapter_title: String,
    content: String,
) -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
        .index_chapter(
            &book_id,
            &chapter_id,
            chapter_index,
            &chapter_title,
            &content,
        )
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
    offset: i32,
) -> Result<Vec<SearchResult>, AppError> {
    let engine = get_search_engine()?;
    let limit = limit.max(1).min(200) as usize;
    let offset = offset.max(0) as usize;
    let results = engine
        .search_all_books(&query, limit, offset)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(results)
}

/// 清除所有搜索索引
#[frb]
pub async fn clear_all() -> Result<(), AppError> {
    let engine = get_search_engine()?;
    engine
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
        .delete_by_book(&book_id)
        .await
        .map_err(|e| AppError::search_error(e.to_string()))?;
    Ok(())
}
