//! 搜索 API — FRB 薄封装层

use std::sync::OnceLock;

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::search::SearchEngine;
use crate::pipeline::{IndexStats, SearchResult};
use crate::infra::manager::storage_pool;

static SEARCH_ENGINE: OnceLock<SearchEngine> = OnceLock::new();

/// 初始化搜索引擎
#[frb]
pub async fn init_search_engine() -> Result<(), AppError> {
    tracing::info!("[search] init_search_engine");
    if SEARCH_ENGINE.get().is_some() {
        return Ok(());
    }
    let pool = storage_pool()?;
    let engine = SearchEngine::new(pool.clone());
    engine
        .ensure_table()
        .await
        .map_err(|e| AppError::SearchError { reason: format!("Failed to create FTS5 table: {e}").into() })?;
    let _ = SEARCH_ENGINE.set(engine);
    Ok(())
}

fn get_search_engine() -> Result<&'static SearchEngine, AppError> {
    SEARCH_ENGINE.get().ok_or_else(|| {
        AppError::InternalError { reason: "Search engine not initialized. Call init_search_engine() first.".into() }
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
    tracing::debug!("[search] index_chapter: book_id={}, chapter_index={}", book_id, chapter_index);
    let engine = get_search_engine()?;
    engine.index_chapter(&book_id, &chapter_id, chapter_index, &chapter_title, &content).await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })?;
    Ok(())
}

/// 在书籍中搜索
#[frb]
pub async fn search(book_id: String, query: String, limit: i32) -> Result<Vec<SearchResult>, AppError> {
    tracing::debug!("[search] search: book_id={}, query={}", book_id, query);
    let engine = get_search_engine()?;
    engine.search(&book_id, &query, limit.max(0) as usize).await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })
}

/// 统计搜索结果数量
#[frb]
pub async fn count_matches(
    book_id: String, query: String, chapter_index: Option<i32>,
) -> Result<i32, AppError> {
    let engine = get_search_engine()?;
    let count = engine.count_matches(&book_id, &query, chapter_index).await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })?;
    Ok(count as i32)
}

/// 搜索所有书籍内容
#[frb]
pub async fn search_all_books(query: String, limit: i32, offset: i32) -> Result<Vec<SearchResult>, AppError> {
    tracing::debug!("[search] search_all_books: query={}", query);
    let engine = get_search_engine()?;
    let results = engine.search_all_books(&query, limit.max(1).min(200) as usize, offset.max(0) as usize).await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })?;
    Ok(results)
}

/// 清除所有搜索索引
#[frb]
pub async fn clear_all() -> Result<(), AppError> {
    tracing::info!("[search] clear_all");
    let engine = get_search_engine()?;
    engine.clear_all().await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })
}

/// 删除某本书的搜索索引
#[frb]
pub async fn delete_by_book(book_id: String) -> Result<(), AppError> {
    tracing::info!("[search] delete_by_book: book_id={}", book_id);
    let engine = get_search_engine()?;
    engine.delete_by_book(&book_id).await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })
}

/// 获取搜索索引统计信息
#[frb]
pub async fn get_index_stats() -> Result<IndexStats, AppError> {
    tracing::debug!("[search] get_index_stats");
    let engine = get_search_engine()?;
    engine.get_index_stats().await
        .map_err(|e| AppError::SearchError { reason: e.to_string().into() })
}
