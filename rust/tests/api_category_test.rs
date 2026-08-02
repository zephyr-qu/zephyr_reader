//! 分类 API 集成测试
//!
//! 测试分类的 CRUD 操作和书籍分类关联功能。

mod common;

use rust_lib_zephyr_reader::api::category;

// ==================== 分类 CRUD ====================

#[tokio::test]
async fn test_upsert_and_list_categories() {
    common::init_test_storage().await;

    let cat = category::upsert_category("TestCat".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .expect("failed to upsert category");

    let categories = category::list_categories()
        .await
        .expect("failed to list categories");
    assert!(
        categories.iter().any(|c| c.id == cat.id),
        "created category should be in list"
    );
}

#[tokio::test]
async fn test_upsert_category_fields() {
    common::init_test_storage().await;

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

    let cat = category::upsert_category("DeleteMe".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .expect("failed to upsert category");

    category::delete_category(cat.id.clone())
        .await
        .expect("failed to delete category");

    let categories = category::list_categories()
        .await
        .expect("failed to list categories");
    assert!(
        !categories.iter().any(|c| c.id == cat.id),
        "deleted category should not be in list"
    );
}

#[tokio::test]
async fn test_delete_nonexistent() {
    common::init_test_storage().await;

    // Deleting a nonexistent category should succeed (idempotent)
    category::delete_category("nonexistent-id".to_string())
        .await
        .expect("deleting nonexistent category should succeed");
}

#[tokio::test]
async fn test_reorder_categories() {
    common::init_test_storage().await;

    let cat1 = category::upsert_category("Reorder1".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .unwrap();
    let cat2 = category::upsert_category("Reorder2".to_string(), "#00FF00".to_string(), 1, None)
        .await
        .unwrap();

    // reorder_categories 的契约：每个对象携带新的 sort_order 字段
    let mut reordered = vec![cat2.clone(), cat1.clone()];
    reordered[0].sort_order = 0; // cat2 排第一
    reordered[1].sort_order = 1; // cat1 排第二
    category::reorder_categories(reordered)
        .await
        .expect("failed to reorder categories");

    let categories = category::list_categories()
        .await
        .expect("failed to list categories");
    let positions: Vec<String> = categories.iter().map(|c| c.id.clone()).collect();
    let pos1 = positions.iter().position(|id| id == &cat1.id).unwrap();
    let pos2 = positions.iter().position(|id| id == &cat2.id).unwrap();
    assert!(pos1 > pos2, "reordered category should come first");
}

// ==================== 书籍-分类关联 ====================

#[tokio::test]
async fn test_set_and_list_by_book() {
    common::init_test_storage().await;

    let book_id = "assign-list-book";
    common::ensure_test_book(book_id).await;

    let cat = category::upsert_category("AssignTest".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .expect("failed to upsert category");

    category::set_categories_for_book(book_id.to_string(), vec![cat.id.clone()])
        .await
        .expect("failed to set category for book");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert!(
        book_cats.iter().any(|c| c.id == cat.id),
        "assigned category should be in book's categories"
    );
}

#[tokio::test]
async fn test_set_empty_clears_book_categories() {
    common::init_test_storage().await;

    let book_id = "clear-cats-book";
    common::ensure_test_book(book_id).await;

    let cat = category::upsert_category("ClearAllTest".to_string(), "#0000FF".to_string(), 0, None)
        .await
        .expect("failed to upsert category");

    category::set_categories_for_book(book_id.to_string(), vec![cat.id.clone()])
        .await
        .expect("failed to set category");

    // 清空：传空列表即解除全部关联
    category::set_categories_for_book(book_id.to_string(), vec![])
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
async fn test_set_categories_replaces_old_list() {
    common::init_test_storage().await;

    let book_id = "set-cats-book";
    common::ensure_test_book(book_id).await;

    let cat1 = category::upsert_category("SetTest1".to_string(), "#FF0000".to_string(), 0, None)
        .await
        .expect("failed to upsert category 1");

    let cat2 = category::upsert_category("SetTest2".to_string(), "#00FF00".to_string(), 1, None)
        .await
        .expect("failed to upsert category 2");

    category::set_categories_for_book(book_id.to_string(), vec![cat1.id.clone()])
        .await
        .expect("failed to set categories (first pass)");

    // 第二次设置应替换而非追加
    category::set_categories_for_book(book_id.to_string(), vec![cat1.id.clone(), cat2.id.clone()])
        .await
        .expect("failed to set categories (second pass)");

    let book_cats = category::list_categories_by_book(book_id.to_string())
        .await
        .expect("failed to list categories by book");
    assert_eq!(book_cats.len(), 2, "book should have exactly 2 categories");
}
