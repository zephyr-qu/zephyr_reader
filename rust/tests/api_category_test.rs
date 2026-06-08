//! 分类 API 集成测试
//!
//! 测试分类的 CRUD 操作和书籍分类关联功能。

mod common;

use rust_lib_zephyr_reader::api::data::{book, category, init};
use rust_lib_zephyr_reader::storage::models::{Book, BookFormat, BookStatus};
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

// 创建测试书籍（book_categories 表有 FK 约束）
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

// ==================== 分类 CRUD ====================

#[tokio::test]
async fn test_create_and_list_categories() {
    ensure_storage_initialized().await;

    let cat = category::create_category(
        "TestCat".to_string(),
        "#FF0000".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    let categories = category::list_categories()
        .await
        .expect("failed to list categories");
    assert!(
        categories.iter().any(|c| c.id == cat.id),
        "created category should be in list"
    );
}

#[tokio::test]
async fn test_get_category() {
    ensure_storage_initialized().await;

    let cat = category::create_category(
        "GetTest".to_string(),
        "#00FF00".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    let found = category::get_category(cat.id.clone())
        .await
        .expect("failed to get category");
    assert!(found.is_some(), "category should exist");
    assert_eq!(found.unwrap().name, "GetTest");

    let not_found = category::get_category("nonexistent-id".to_string())
        .await
        .expect("failed to get category");
    assert!(not_found.is_none(), "nonexistent category should return None");
}

#[tokio::test]
async fn test_upsert_category() {
    ensure_storage_initialized().await;

    // upsert_category always creates a new category (no category_id param in current API)
    let cat = category::upsert_category(
        "UpsertCat".to_string(),
        "#0000FF".to_string(),
        1,
        Some("upserted".to_string()),
    )
    .await
    .expect("failed to upsert category");

    assert_eq!(cat.name, "UpsertCat");
    assert_eq!(cat.color, "#0000FF");
    assert_eq!(cat.sort_order, 1);
    assert_eq!(cat.description, Some("upserted".to_string()));

    let categories = category::list_categories()
        .await
        .expect("failed to list categories");
    assert!(
        categories.iter().any(|c| c.id == cat.id),
        "upserted category should be in list"
    );
}

#[tokio::test]
async fn test_delete_category() {
    ensure_storage_initialized().await;

    let cat = category::create_category(
        "DeleteMe".to_string(),
        "#FF0000".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    category::delete_category(cat.id.clone())
        .await
        .expect("failed to delete category");

    let found = category::get_category(cat.id.clone())
        .await
        .expect("failed to get category");
    assert!(found.is_none(), "deleted category should not exist");
}

#[tokio::test]
async fn test_delete_nonexistent() {
    ensure_storage_initialized().await;

    // Deleting a nonexistent category should succeed (idempotent)
    category::delete_category("nonexistent-id".to_string())
        .await
        .expect("deleting nonexistent category should succeed");
}

// ==================== 书籍-分类关联 ====================

#[tokio::test]
async fn test_assign_and_list_by_book() {
    ensure_storage_initialized().await;

    let book_id = "assign-list-book";
    ensure_book(book_id).await;

    let cat = category::create_category(
        "AssignTest".to_string(),
        "#FF0000".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    category::assign_category_to_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to assign category to book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert!(
        book_cats.iter().any(|c| c.id == cat.id),
        "assigned category should be in book's categories"
    );
}

#[tokio::test]
async fn test_clear_category_from_book() {
    ensure_storage_initialized().await;

    let book_id = "clear-cat-book";
    ensure_book(book_id).await;

    let cat = category::create_category(
        "ClearTest".to_string(),
        "#00FF00".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    category::assign_category_to_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to assign category");

    category::clear_category_from_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to clear category from book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert!(
        book_cats.is_empty(),
        "book should have no categories after clearing"
    );
}

#[tokio::test]
async fn test_set_categories_for_book() {
    ensure_storage_initialized().await;

    let book_id = "set-cats-book";
    ensure_book(book_id).await;

    let cat1 = category::create_category(
        "SetTest1".to_string(),
        "#FF0000".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category 1");

    let cat2 = category::create_category(
        "SetTest2".to_string(),
        "#00FF00".to_string(),
        1,
        None,
    )
    .await
    .expect("failed to create category 2");

    category::set_categories_for_book(book_id.to_string(), vec![cat1.id.clone(), cat2.id.clone()])
        .await
        .expect("failed to set categories for book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert_eq!(
        book_cats.len(),
        2,
        "book should have exactly 2 categories"
    );
}

#[tokio::test]
async fn test_clear_categories_by_book() {
    ensure_storage_initialized().await;

    let book_id = "clear-cats-book";
    ensure_book(book_id).await;

    let cat = category::create_category(
        "ClearAllTest".to_string(),
        "#0000FF".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    category::assign_category_to_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to assign category");

    category::clear_categories_by_book(book_id.to_string())
        .await
        .expect("failed to clear categories by book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert!(
        book_cats.is_empty(),
        "book should have no categories after clearing all"
    );
}

#[tokio::test]
async fn test_list_books_by_category() {
    ensure_storage_initialized().await;

    let book_id = "list-books-by-cat";
    ensure_book(book_id).await;

    let cat = category::create_category(
        "ListBooksByCat".to_string(),
        "#FF0000".to_string(),
        0,
        None,
    )
    .await
    .expect("failed to create category");

    category::assign_category_to_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to assign category");

    let books = category::list_books_by_category(cat.id.clone())
        .await
        .expect("failed to list books by category");
    assert!(
        books.iter().any(|b| b.book_id == book_id),
        "assigned book should be in category's books"
    );
}
