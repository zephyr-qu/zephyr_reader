//! 章节 API 集成测试
//!
//! 测试章节的 CRUD 操作：创建、列表、查询、清除。

mod common;

use rust_lib_zephyr_reader::api::data::chapter::{
    clear_chapters_by_book, get_chapter_by_index, list_chapters_by_book, upsert_chapters,
};
use rust_lib_zephyr_reader::storage::ensure_storage;
use rust_lib_zephyr_reader::storage::models::{Book, BookFormat, Chapter};
use rust_lib_zephyr_reader::storage::repos::BookRepository;


// 创建测试书籍用于 FK 约束
async fn ensure_test_book(book_id: &str) {
    let storage = ensure_storage().expect("storage not initialized");
    let pool = storage.pool().expect("failed to get pool");

    if BookRepository::find_by_id(&pool, book_id)
        .await
        .ok()
        .flatten()
        .is_some()
    {
        return;
    }

    let book = Book::new(
        &format!("/test/path/{book_id}.epub"),
        0,
        "Test Book",
        BookFormat::Epub,
        10,
        10000,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
    );
    let patched = Book {
        book_id: book_id.to_string(),
        ..book
    };
    BookRepository::save(&pool, &patched)
        .await
        .expect("failed to create test book");
}

#[tokio::test]
async fn test_upsert_and_list_chapters() {
    common::init_test_storage().await;
    ensure_test_book("chapter-test-book-1").await;

    let chapters = vec![
        Chapter::new("chapter-test-book-1", "第一章", 0, 1, 0, 1000),
        Chapter::new("chapter-test-book-1", "第二章", 1, 1, 1001, 2000),
        Chapter::new("chapter-test-book-1", "第三章", 2, 1, 2001, 3000),
    ];
    upsert_chapters("chapter-test-book-1".to_string(), chapters)
        .await
        .expect("failed to upsert chapters");

    let result = list_chapters_by_book("chapter-test-book-1".to_string())
        .await
        .expect("failed to list chapters");
    assert_eq!(result.len(), 3);
    assert_eq!(result[0].title, "第一章");
    assert_eq!(result[1].title, "第二章");
    assert_eq!(result[2].title, "第三章");
}

#[tokio::test]
async fn test_get_chapter_by_index() {
    common::init_test_storage().await;
    ensure_test_book("chapter-test-book-2").await;

    let chapters = vec![
        Chapter::new("chapter-test-book-2", "Introduction", 0, 1, 0, 500),
        Chapter::new("chapter-test-book-2", "Chapter One", 1, 1, 501, 1500),
    ];
    upsert_chapters("chapter-test-book-2".to_string(), chapters)
        .await
        .expect("failed to upsert chapters");

    let ch = get_chapter_by_index("chapter-test-book-2".to_string(), 0)
        .await
        .expect("failed to get chapter by index")
        .expect("expected chapter at index 0");
    assert_eq!(ch.title, "Introduction");
    assert_eq!(ch.chapter_index, 0);

    let missing = get_chapter_by_index("chapter-test-book-2".to_string(), 99)
        .await
        .expect("failed to get chapter by index");
    assert!(missing.is_none());
}

#[tokio::test]
async fn test_get_chapter_by_index_validates_correct_chapter() {
    common::init_test_storage().await;
    ensure_test_book("chapter-test-book-3").await;

    let chapters = vec![
        Chapter::new("chapter-test-book-3", "Chapter Zero", 0, 1, 0, 500),
        Chapter::new("chapter-test-book-3", "Chapter One", 1, 2, 501, 1000),
        Chapter::new("chapter-test-book-3", "Chapter Two", 2, 1, 1001, 1500),
    ];
    upsert_chapters("chapter-test-book-3".to_string(), chapters)
        .await
        .expect("failed to upsert chapters");

    let ch0 = get_chapter_by_index("chapter-test-book-3".to_string(), 0)
        .await
        .expect("failed")
        .expect("chapter 0 should exist");
    assert_eq!(ch0.chapter_index, 0);
    assert_eq!(ch0.title, "Chapter Zero");
    assert_eq!(ch0.level, 1);

    let ch1 = get_chapter_by_index("chapter-test-book-3".to_string(), 1)
        .await
        .expect("failed")
        .expect("chapter 1 should exist");
    assert_eq!(ch1.chapter_index, 1);
    assert_eq!(ch1.title, "Chapter One");
    assert_eq!(ch1.level, 2);

    let ch2 = get_chapter_by_index("chapter-test-book-3".to_string(), 2)
        .await
        .expect("failed")
        .expect("chapter 2 should exist");
    assert_eq!(ch2.chapter_index, 2);
    assert_eq!(ch2.title, "Chapter Two");
    assert_eq!(ch2.level, 1);
}

#[tokio::test]
async fn test_clear_chapters_by_book() {
    common::init_test_storage().await;
    ensure_test_book("chapter-test-book-4").await;

    let chapters = vec![
        Chapter::new("chapter-test-book-4", "第一章", 0, 1, 0, 500),
        Chapter::new("chapter-test-book-4", "第二章", 1, 1, 501, 1000),
    ];
    upsert_chapters("chapter-test-book-4".to_string(), chapters)
        .await
        .expect("failed to upsert chapters");

    clear_chapters_by_book("chapter-test-book-4".to_string())
        .await
        .expect("failed to clear chapters");

    let result = list_chapters_by_book("chapter-test-book-4".to_string())
        .await
        .expect("failed to list chapters");
    assert!(result.is_empty());
}

#[tokio::test]
async fn test_upsert_empty_chapters() {
    common::init_test_storage().await;
    ensure_test_book("chapter-test-book-5").await;

    let initial = list_chapters_by_book("chapter-test-book-5".to_string())
        .await
        .expect("failed to list chapters");
    assert!(initial.is_empty());

    upsert_chapters("chapter-test-book-5".to_string(), vec![])
        .await
        .expect("failed to upsert empty chapters");

    let result = list_chapters_by_book("chapter-test-book-5".to_string())
        .await
        .expect("failed to list chapters");
    assert!(result.is_empty());
}
