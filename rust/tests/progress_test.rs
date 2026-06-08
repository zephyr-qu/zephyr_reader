//! 阅读进度 API 集成测试
//!
//! 测试进度的 CRUD 操作：获取、更新、列表、清除。

mod common;

use rust_lib_zephyr_reader::api::data::{book, init, progress};
use rust_lib_zephyr_reader::storage::models::{
    Book, BookFormat, BookStatus, ReadingProgress,
};
use std::sync::OnceLock;
use tempfile::TempDir;

static TEST_STORAGE: OnceLock<TempDir> = OnceLock::new();

async fn ensure_storage_initialized() {
    if TEST_STORAGE.get().is_some() {
        return;
    }

    let temp_dir = TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    if let Err(e) = init::init_storage(data_dir.clone()).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {:?}", e);
        }
    }

    TEST_STORAGE.get_or_init(|| temp_dir);
}

// 创建测试书籍并插入 DB（progress 表有 FK 约束）
async fn ensure_book(book_id: &str) {
    let book = Book {
        book_id: book_id.to_string(),
        file_path: format!("/test/{book_id}.txt"),
        file_hash: None,
        file_size: 1024,
        file_mtime: None,
        title: book_id.to_string(),
        author: None,
        cover_path: None,
        chapter_count: 1,
        total_characters: 1000,
        format: BookFormat::Txt,
        added_at: chrono::Utc::now(),
        last_opened_at: None,
        status: BookStatus::Reading,
        is_pinned: false,
        description: None,
        publisher: None,
        translator: None,
        isbn: None,
    };
    book::upsert_book(book).await.unwrap();
}

fn make_progress(book_id: &str, chapter_index: i64) -> ReadingProgress {
    ReadingProgress {
        book_id: book_id.to_string(),
        chapter_index,
        chunk_index: 0,
        chapter_id: None,
        char_offset: 0,
        page_index: 0,
        total_pages: 10,
        is_completed: false,
        progress: 0.0,
        reading_time_seconds: 0,
        last_read_at: chrono::Utc::now(),
    }
}

#[tokio::test]
async fn test_progress_upsert_and_get() {
    common::init_logger();
    ensure_storage_initialized().await;
    ensure_book("test_progress_book").await;

    let p = make_progress("test_progress_book", 1);
    progress::upsert_progress(p).await.unwrap();

    let retrieved = progress::get_progress("test_progress_book".to_string())
        .await
        .unwrap();
    assert!(retrieved.is_some());
    assert_eq!(retrieved.unwrap().book_id, "test_progress_book");
}

#[tokio::test]
async fn test_progress_get_nonexistent() {
    common::init_logger();
    ensure_storage_initialized().await;

    let result = progress::get_progress("nonexistent_book".to_string())
        .await
        .unwrap();
    assert!(result.is_none());
}

#[tokio::test]
async fn test_progress_upsert_updates_existing() {
    common::init_logger();
    ensure_storage_initialized().await;
    ensure_book("test_progress_update").await;

    let p1 = make_progress("test_progress_update", 1);
    progress::upsert_progress(p1).await.unwrap();

    let p2 = ReadingProgress {
        book_id: "test_progress_update".to_string(),
        chapter_index: 2,
        chunk_index: 0,
        chapter_id: None,
        char_offset: 100,
        page_index: 3,
        total_pages: 20,
        is_completed: true,
        progress: 0.3,
        reading_time_seconds: 300,
        last_read_at: chrono::Utc::now(),
    };
    progress::upsert_progress(p2).await.unwrap();

    let retrieved = progress::get_progress("test_progress_update".to_string())
        .await
        .unwrap()
        .unwrap();
    assert_eq!(retrieved.chapter_index, 2);
    assert_eq!(retrieved.char_offset, 100);
    assert_eq!(retrieved.progress, 0.3);
}

#[tokio::test]
async fn test_list_all_progresses() {
    common::init_logger();
    ensure_storage_initialized().await;
    ensure_book("test_list_progress_a").await;
    ensure_book("test_list_progress_b").await;

    let p1 = make_progress("test_list_progress_a", 1);
    progress::upsert_progress(p1).await.unwrap();
    let p2 = make_progress("test_list_progress_b", 1);
    progress::upsert_progress(p2).await.unwrap();

    let all = progress::list_all_progresses().await.unwrap();
    let ids: Vec<&str> = all.iter().map(|bp| bp.book.book_id.as_str()).collect();
    assert!(ids.contains(&"test_list_progress_a"));
    assert!(ids.contains(&"test_list_progress_b"));
}

#[tokio::test]
async fn test_clear_progress() {
    common::init_logger();
    ensure_storage_initialized().await;
    ensure_book("test_clear_progress").await;

    let p = make_progress("test_clear_progress", 1);
    progress::upsert_progress(p).await.unwrap();

    progress::clear_progress("test_clear_progress".to_string())
        .await
        .unwrap();

    let retrieved = progress::get_progress("test_clear_progress".to_string())
        .await
        .unwrap();
    assert!(retrieved.is_none());
}
