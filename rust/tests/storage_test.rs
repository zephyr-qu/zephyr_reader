//! 存储层集成测试
//! 测试书籍、书签、笔记的 CRUD 操作，以及数据关系一致性。

mod common;

use rust_lib_zephyr_reader::domain::book::{Book, BookFormat, BookStatus};

// ==================== 测试工具函数 ====================

// 创建测试书籍
fn create_test_book(file_path: &str) -> Book {
    Book {
        book_id: uuid::Uuid::new_v4().to_string(),
        file_path: file_path.to_string(),
        file_hash: Some("test_hash".to_string()),
        file_size: 1024,
        file_mtime: None,
        title: "测试书籍".to_string(),
        author: Some("测试作者".to_string()),
        cover_path: None,
        chapter_count: 5,
        format: BookFormat::Txt,
        added_at: chrono::Utc::now(),
        last_opened_at: None,
        status: BookStatus::Reading,
        is_pinned: false,
        description: None,
        publisher: None,
        translator: None,
        isbn: None,
    }
}

// ==================== 书籍 CRUD 测试 ====================

#[tokio::test]
// 测试创建书籍并获取，验证各字段正确性
async fn test_book_create_and_get() {
    common::init_test_storage().await;

    // 创建书籍
    let book = create_test_book("/tmp/test1.txt");
    let book_id = book.book_id.clone();

    // 保存书籍
    let result = rust_lib_zephyr_reader::api::book::upsert_book(book.clone()).await;
    assert!(result.is_ok(), "创建书籍应该成功: {:?}", result);

    // 获取书籍
    let result = rust_lib_zephyr_reader::api::book::get_book(book_id.clone()).await;
    assert!(result.is_ok(), "获取书籍应该成功");

    let retrieved_book = result.unwrap();
    assert!(retrieved_book.is_some(), "应该能找到书籍");

    let retrieved_book = retrieved_book.unwrap();
    assert_eq!(retrieved_book.title, "测试书籍");
    assert_eq!(retrieved_book.author, Some("测试作者".to_string()));
    assert_eq!(retrieved_book.format, BookFormat::Txt);

    println!("✓ 书籍创建和获取测试通过");
}

// 测试更新书籍状态和标题，验证更新持久化
#[tokio::test]
async fn test_book_update() {
    common::init_test_storage().await;

    // 创建书籍
    let mut book = create_test_book("/tmp/test2.txt");
    rust_lib_zephyr_reader::api::book::upsert_book(book.clone())
        .await
        .expect("创建失败");

    // 更新书籍状态
    book.status = BookStatus::Completed;
    book.title = "更新后的标题".to_string();

    let result = rust_lib_zephyr_reader::api::book::upsert_book(book.clone()).await;
    assert!(result.is_ok(), "更新书籍应该成功");

    // 验证更新
    let retrieved = rust_lib_zephyr_reader::api::book::get_book(book.book_id.clone())
        .await
        .expect("获取失败")
        .expect("书籍不存在");

    assert_eq!(retrieved.status, BookStatus::Completed);
    assert_eq!(retrieved.title, "更新后的标题");

    println!("✓ 书籍更新测试通过");
}

#[tokio::test]
async fn test_book_delete() {
    // 测试删除书籍，验证删除后无法获取
    common::init_test_storage().await;

    // 创建书籍
    let book = create_test_book("/tmp/test3.txt");
    let book_id = book.book_id.clone();

    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建失败");

    // 删除书籍
    let result =
        rust_lib_zephyr_reader::api::book::delete_book(book_id.clone(), String::new()).await;
    assert!(result.is_ok(), "删除书籍应该成功");

    // 验证删除
    let result = rust_lib_zephyr_reader::api::book::get_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "删除后应该找不到书籍");

    println!("✓ 书籍删除测试通过");
}

#[tokio::test]
async fn test_book_list_all() {
    // 测试获取所有书籍列表，验证列表完整性
    common::init_test_storage().await;

    // 创建多本书籍（使用唯一 ID 避免冲突）
    for i in 0..3 {
        let mut book = create_test_book(&format!("/tmp/test_list_{}.txt", i));
        book.book_id = format!("unique_book_list_{}", i);
        book.title = format!("书籍{}", i);
        rust_lib_zephyr_reader::api::book::upsert_book(book)
            .await
            .expect("创建失败");
    }

    // 通过当前书架主路径获取所有书籍
    let result =
        rust_lib_zephyr_reader::api::book::list_bookshelf_books(None, None, None, None).await;
    assert!(result.is_ok(), "获取书籍列表应该成功");

    let books = result.unwrap();
    assert!(books.len() >= 3, "应该至少有3本书籍");

    println!("✓ 书籍列表测试通过，共 {} 本", books.len());
}

#[tokio::test]
async fn test_book_search() {
    // 测试按书名关键词搜索书籍
    common::init_test_storage().await;

    // 创建测试书籍
    let mut book1 = create_test_book("/tmp/search1.txt");
    book1.book_id = "unique_search_1".to_string();
    book1.title = "Rust编程指南".to_string();
    rust_lib_zephyr_reader::api::book::upsert_book(book1)
        .await
        .expect("创建失败");

    let mut book2 = create_test_book("/tmp/search2.txt");
    book2.book_id = "unique_search_2".to_string();
    book2.title = "Python入门教程".to_string();
    rust_lib_zephyr_reader::api::book::upsert_book(book2)
        .await
        .expect("创建失败");

    // 搜索书籍
    let result = rust_lib_zephyr_reader::api::book::search_books("Rust".to_string()).await;
    assert!(result.is_ok(), "搜索应该成功");

    let books = result.unwrap();
    assert!(!books.is_empty(), "应该至少找到1本包含'Rust'的书籍");

    println!("✓ 书籍搜索测试通过");
}

#[tokio::test]
async fn test_book_get_by_status() {
    // 测试按阅读状态筛选书籍
    common::init_test_storage().await;

    // 创建不同状态的书籍
    let mut book1 = create_test_book("/tmp/status1.txt");
    book1.book_id = "unique_status_1".to_string();
    book1.status = BookStatus::Reading;
    rust_lib_zephyr_reader::api::book::upsert_book(book1)
        .await
        .expect("创建失败");

    let mut book2 = create_test_book("/tmp/status2.txt");
    book2.book_id = "unique_status_2".to_string();
    book2.status = BookStatus::Completed;
    rust_lib_zephyr_reader::api::book::upsert_book(book2)
        .await
        .expect("创建失败");

    let mut book3 = create_test_book("/tmp/status3.txt");
    book3.book_id = "unique_status_3".to_string();
    book3.status = BookStatus::Reading;
    rust_lib_zephyr_reader::api::book::upsert_book(book3)
        .await
        .expect("创建失败");

    // 获取阅读中的书籍
    let result = rust_lib_zephyr_reader::api::book::list_bookshelf_books(None, Some(BookStatus::Reading), None, None).await;
    assert!(result.is_ok(), "获取书籍应该成功");

    let books = result.unwrap();
    assert!(books.len() >= 2, "应该至少有2本阅读中的书籍");

    println!("✓ 按状态获取书籍测试通过");
}

// ==================== 书签 CRUD 测试 ====================

#[tokio::test]
async fn test_bookmark_create_and_get() {
    // 测试创建书签并获取，验证字段正确性
    common::init_test_storage().await;

    // 先创建关联的书籍记录
    let book = create_test_book("/tmp/bookmark_test.txt");
    let book_id = book.book_id.clone();
    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建书籍失败");

    // 创建书签
    let result = rust_lib_zephyr_reader::api::bookmark::create_bookmark(
        book_id.clone(),
        0,   // chapter_index
        100, // char_offset
        "第一章标记".to_string(),
        None, // locator_json
    )
    .await;

    assert!(result.is_ok(), "创建书签应该成功");
    let bookmark = result.unwrap();
    assert_eq!(bookmark.book_id, book_id);
    assert_eq!(bookmark.title, "第一章标记");
    assert_eq!(bookmark.char_offset, 100);

    // 通过当前书签列表主路径验证持久化
    let bookmarks = rust_lib_zephyr_reader::api::bookmark::list_bookmarks_by_book(book_id)
        .await
        .expect("获取书签列表失败");
    assert!(bookmarks.iter().any(|entry| entry.id == bookmark.id));

    println!("✓ 书签创建和获取测试通过");
}

#[tokio::test]
// 测试按书籍获取所有书签列表
async fn test_bookmark_list_by_book() {
    common::init_test_storage().await;

    let book_id = "test_book_for_list_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_list_test.txt");
    book.book_id = book_id.clone();
    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建书籍失败");

    // 创建多个书签
    for i in 0..5 {
        rust_lib_zephyr_reader::api::bookmark::create_bookmark(
            book_id.clone(),
            i,
            i * 100,
            format!("书签{}", i),
            None, // locator_json
        )
        .await
        .expect("创建失败");
    }

    // 获取书签列表
    let result =
        rust_lib_zephyr_reader::api::bookmark::list_bookmarks_by_book(book_id.clone()).await;
    assert!(result.is_ok(), "获取书签列表应该成功");

    let bookmarks = result.unwrap();
    assert_eq!(bookmarks.len(), 5, "应该有5个书签");

    println!("✓ 书签列表测试通过，共 {} 个", bookmarks.len());
}

#[tokio::test]
async fn test_bookmark_delete() {
    // 测试删除书签，验证删除后无法获取
    common::init_test_storage().await;

    let book_id = "test_book_for_delete_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_delete_test.txt");
    book.book_id = book_id.clone();
    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建书籍失败");

    // 创建书签
    let bookmark = rust_lib_zephyr_reader::api::bookmark::create_bookmark(
        book_id.clone(),
        0,
        50,
        "待删除书签".to_string(),
        None, // locator_json
    )
    .await
    .expect("创建失败");

    let bookmark_id = bookmark.id.clone();

    // 删除书签
    let result = rust_lib_zephyr_reader::api::bookmark::delete_bookmark(bookmark_id.clone()).await;
    assert!(result.is_ok(), "删除书签应该成功");

    // 通过当前书签列表主路径验证删除
    let bookmarks = rust_lib_zephyr_reader::api::bookmark::list_bookmarks_by_book(book_id)
        .await
        .expect("获取书签列表失败");
    assert!(
        bookmarks.iter().all(|entry| entry.id != bookmark_id),
        "删除后应该找不到书签"
    );

    println!("✓ 书签删除测试通过");
}

#[tokio::test]
async fn test_bookmark_clear_by_book() {
    // 测试清除某本书的所有书签
    common::init_test_storage().await;

    let book_id = "test_book_for_clear_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_clear_test.txt");
    book.book_id = book_id.clone();
    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建书籍失败");

    // 创建多个书签
    for i in 0..3 {
        rust_lib_zephyr_reader::api::bookmark::create_bookmark(
            book_id.clone(),
            i,
            i * 100,
            format!("书签{}", i),
            None, // locator_json
        )
        .await
        .expect("创建失败");
    }

    // 清除所有书签
    let result =
        rust_lib_zephyr_reader::api::bookmark::delete_bookmarks_by_book(book_id.clone()).await;
    assert!(result.is_ok(), "清除书签应该成功");

    // 验证清除
    let result = rust_lib_zephyr_reader::api::bookmark::list_bookmarks_by_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "清除后应该没有书签");

    println!("✓ 清除书签测试通过");
}


// ==================== 数据一致性测试 ====================

#[tokio::test]
async fn test_book_and_bookmark_relation() {
    // 测试删除书籍时级联删除关联书签
    common::init_test_storage().await;

    // 创建书籍
    let mut book = create_test_book("/tmp/relation_test.txt");
    let book_id = "test_relation_bookmark_book".to_string();
    book.book_id = book_id.clone();
    rust_lib_zephyr_reader::api::book::upsert_book(book)
        .await
        .expect("创建书籍失败");

    // 为书籍创建书签
    rust_lib_zephyr_reader::api::bookmark::create_bookmark(
        book_id.clone(),
        0,
        100,
        "关联测试".to_string(),
        None, // locator_json
    )
    .await
    .expect("创建书签失败");

    // 删除书籍（应该级联删除书签）
    rust_lib_zephyr_reader::api::book::delete_book(book_id.clone(), String::new())
        .await
        .expect("删除书籍失败");

    // 验证书签也被删除
    let result = rust_lib_zephyr_reader::api::bookmark::list_bookmarks_by_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "删除书籍后书签应该也被删除");

    println!("✓ 书籍-书签关联删除测试通过");
}

