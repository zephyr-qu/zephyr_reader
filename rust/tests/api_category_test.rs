//! 分类 API 集成测试
//!
//! 测试分类的 CRUD 操作和书籍分类关联功能。

mod common;

use rust_lib_zephyr_reader::api::category;

// ==================== 分类 CRUD ====================

#[tokio::test]
async fn test_create_and_list_categories() {
    common::init_test_storage().await;

    let cat = category::create_category("TestCat".to_string(), "#FF0000".to_string(), 0, None)
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
    common::init_test_storage().await;

    let cat = category::create_category("GetTest".to_string(), "#00FF00".to_string(), 0, None)
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
    assert!(
        not_found.is_none(),
        "nonexistent category should return None"
    );
}

#[tokio::test]
async fn test_upsert_category() {
    common::init_test_storage().await;

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
    common::init_test_storage().await;

    let cat = category::create_category("DeleteMe".to_string(), "#FF0000".to_string(), 0, None)
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
    common::init_test_storage().await;

    // Deleting a nonexistent category should succeed (idempotent)
    category::delete_category("nonexistent-id".to_string())
        .await
        .expect("deleting nonexistent category should succeed");
}

// ==================== 书籍-分类关联 ====================

#[tokio::test]
async fn test_assign_and_list_by_book() {
    common::init_test_storage().await;

    let book_id = "assign-list-book";
    common::ensure_test_book(book_id).await;

    let cat = category::create_category("AssignTest".to_string(), "#FF0000".to_string(), 0, None)
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
    common::init_test_storage().await;

    let book_id = "clear-cat-book";
    common::ensure_test_book(book_id).await;

    let cat = category::create_category("ClearTest".to_string(), "#00FF00".to_string(), 0, None)
        .await
        .expect("failed to create category");

    category::assign_category_to_book(book_id.to_string(), cat.id.clone())
        .await
        .expect("failed to assign category");

    category::delete_category(book_id.to_string(), cat.id.clone())
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
    common::init_test_storage().await;

    let book_id = "set-cats-book";
    common::ensure_test_book(book_id).await;

    let cat1 = category::create_category("SetTest1".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .expect("failed to create category 1");

    let cat2 = category::create_category("SetTest2".to_string(), "#00FF00".to_string(), 1, None)
        .await
        .expect("failed to create category 2");

    category::set_categories_for_book(book_id.to_string(), vec![cat1.id.clone(), cat2.id.clone()])
        .await
        .expect("failed to set categories for book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert_eq!(book_cats.len(), 2, "book should have exactly 2 categories");
}

#[tokio::test]
async fn test_clear_categories_by_book() {
    common::init_test_storage().await;

    let book_id = "clear-cats-book";
    common::ensure_test_book(book_id).await;

    let cat = category::create_category("ClearAllTest".to_string(), "#0000FF".to_string(), 0, None)
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
    common::init_test_storage().await;

    let book_id = "list-books-by-cat";
    common::ensure_test_book(book_id).await;

    let cat =
        category::create_category("ListBooksByCat".to_string(), "#FF0000".to_string(), 0, None)
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
