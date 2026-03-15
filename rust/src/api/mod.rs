//! Rust 核心引擎 API
//! 向 Flutter 暴露的主要接口函数

pub mod simple;

use crate::ffi::{ApiResult, Bookmark, PageContent, ParseResult, ReadingProgress, TypesetConfig};
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use uuid::Uuid;

// 全局阅读进度存储（内存中）
static READING_PROGRESS: once_cell::sync::Lazy<Arc<RwLock<HashMap<String, ReadingProgress>>>> =
    once_cell::sync::Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

// 全局书签存储（内存中）
static BOOKMARKS: once_cell::sync::Lazy<Arc<RwLock<HashMap<String, Vec<Bookmark>>>>> =
    once_cell::sync::Lazy::new(|| Arc::new(RwLock::new(HashMap::new())));

/// 初始化应用
#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    log::info!("Zephyr Reader Rust Engine initialized");
}

/// 测试连接
#[frb(sync)]
pub fn test_connection() -> String {
    "Zephyr Reader Rust Engine OK".to_string()
}

/// 解析 TXT 文件
#[frb(sync)]
pub fn parse_txt_file(file_path: String) -> ApiResult<ParseResult> {
    crate::parser::parse_txt(file_path)
}

/// 解析 EPUB 文件
#[frb(sync)]
pub fn parse_epub_file(file_path: String) -> ApiResult<ParseResult> {
    crate::parser::parse_epub(file_path)
}

/// 排版处理文本
#[frb(sync)]
pub fn typeset_text(content: String, language: String, config: TypesetConfig) -> ApiResult<String> {
    crate::text_process::typeset_content(content, language, config)
}

/// 获取文件大小
#[frb(sync)]
pub fn get_file_size(file_path: String) -> ApiResult<i64> {
    crate::stream::get_file_size(file_path)
}

/// 读取文件块
#[frb(sync)]
pub fn read_file_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String> {
    crate::stream::read_chunk(file_path, start_pos, chunk_size)
}

/// 创建分页器
#[frb(sync)]
pub fn create_page_streamer(content: String, config: TypesetConfig) -> crate::stream::PageStreamer {
    crate::stream::PageStreamer::new(content, config)
}

/// 将所有内容分页
#[frb(sync)]
pub fn paginate_all_content(
    content: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> Vec<PageContent> {
    crate::stream::paginate_all(content, chapter_id, config)
}

// ==================== 阅读进度管理 ====================

/// 创建或更新阅读进度
#[frb(sync)]
pub fn update_reading_progress(
    book_id: String,
    chapter_id: i32,
    page_index: i32,
    total_pages: i32,
) -> ReadingProgress {
    let mut progress_map = READING_PROGRESS.write().unwrap();

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    let progress = progress_map
        .entry(book_id.clone())
        .or_insert_with(|| ReadingProgress {
            chapter_id: 0,
            page_index: 0,
            total_pages: 0,
            progress: 0.0,
            reading_time_seconds: 0,
            last_read_timestamp: 0,
        });

    progress.chapter_id = chapter_id;
    progress.page_index = page_index;
    progress.total_pages = total_pages;
    progress.progress = if total_pages > 0 {
        (page_index + 1) as f32 / total_pages as f32
    } else {
        0.0
    };
    progress.last_read_timestamp = now;

    progress.clone()
}

/// 获取阅读进度
#[frb(sync)]
pub fn get_reading_progress(book_id: String) -> Option<ReadingProgress> {
    let progress_map = READING_PROGRESS.read().unwrap();
    progress_map.get(&book_id).cloned()
}

/// 清除阅读进度
#[frb(sync)]
pub fn clear_reading_progress(book_id: String) -> bool {
    let mut progress_map = READING_PROGRESS.write().unwrap();
    progress_map.remove(&book_id).is_some()
}

/// 获取所有书籍的阅读进度
#[frb(sync)]
pub fn get_all_reading_progress() -> Vec<ReadingProgress> {
    let progress_map = READING_PROGRESS.read().unwrap();
    progress_map.values().cloned().collect()
}

// ==================== 书签管理 ====================

/// 添加书签
#[frb(sync)]
pub fn add_bookmark(
    book_id: String,
    chapter_id: i32,
    page_index: i32,
    title: String,
    note: Option<String>,
) -> Bookmark {
    let mut bookmarks_map = BOOKMARKS.write().unwrap();

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    let bookmark = Bookmark {
        bookmark_id: Uuid::new_v4().to_string(),
        book_id: book_id.clone(),
        chapter_id,
        page_index,
        title,
        created_timestamp: now,
        note,
    };

    bookmarks_map
        .entry(book_id)
        .or_insert_with(Vec::new)
        .push(bookmark.clone());

    bookmark
}

/// 获取书籍的所有书签
#[frb(sync)]
pub fn get_bookmarks(book_id: String) -> Vec<Bookmark> {
    let bookmarks_map = BOOKMARKS.read().unwrap();
    bookmarks_map.get(&book_id).cloned().unwrap_or_default()
}

/// 删除书签
#[frb(sync)]
pub fn remove_bookmark(book_id: String, bookmark_id: String) -> bool {
    let mut bookmarks_map = BOOKMARKS.write().unwrap();

    if let Some(bookmarks) = bookmarks_map.get_mut(&book_id) {
        let original_len = bookmarks.len();
        bookmarks.retain(|b| b.bookmark_id != bookmark_id);
        return bookmarks.len() < original_len;
    }

    false
}

/// 清除书籍的所有书签
#[frb(sync)]
pub fn clear_bookmarks(book_id: String) -> usize {
    let mut bookmarks_map = BOOKMARKS.write().unwrap();

    if let Some(bookmarks) = bookmarks_map.remove(&book_id) {
        let count = bookmarks.len();
        count
    } else {
        0
    }
}

/// 获取所有书签
#[frb(sync)]
pub fn get_all_bookmarks() -> Vec<Bookmark> {
    let bookmarks_map = BOOKMARKS.read().unwrap();
    bookmarks_map.values().flatten().cloned().collect()
}
