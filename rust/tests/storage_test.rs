//! 存储层集成测试
//! 测试书籍、书签、笔记的 CRUD 操作，以及数据关系一致性。

mod common;

use rust_lib_zephyr_reader::api::data::{self, init};
use rust_lib_zephyr_reader::storage::models::{Book, BookFormat, BookStatus, NoteType};
use std::sync::OnceLock;
use tempfile::TempDir;

// ==================== 测试工具函数 ====================

static TEST_STORAGE: OnceLock<TempDir> = OnceLock::new();

/// 初始化测试存储环境（全局只初始化一次）
async fn ensure_storage_initialized() {
    if TEST_STORAGE.get().is_some() {
        return;
    }

    let temp_dir = TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    // 初始化存储（忽略已初始化的错误）
    if let Err(e) = init::init_storage(data_dir.clone()).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {:?}", e);
        }
    }

    // 存储到全局变量
    TEST_STORAGE.get_or_init(|| temp_dir);
}

/// 创建测试书籍
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
        total_characters: 10000,
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
/// 测试创建书籍并获取，验证各字段正确性
async fn test_book_create_and_get() {
    ensure_storage_initialized().await;

    // 创建书籍
    let book = create_test_book("/tmp/test1.txt");
    let book_id = book.book_id.clone();

    // 保存书籍
    let result = data::book::upsert_book(book.clone()).await;
    assert!(result.is_ok(), "创建书籍应该成功: {:?}", result);

    // 获取书籍
    let result = data::book::get_book(book_id.clone()).await;
    assert!(result.is_ok(), "获取书籍应该成功");

    let retrieved_book = result.unwrap();
    assert!(retrieved_book.is_some(), "应该能找到书籍");

    let retrieved_book = retrieved_book.unwrap();
    assert_eq!(retrieved_book.title, "测试书籍");
    assert_eq!(retrieved_book.author, Some("测试作者".to_string()));
    assert_eq!(retrieved_book.format, BookFormat::Txt);

    println!("✓ 书籍创建和获取测试通过");
}

/// 测试更新书籍状态和标题，验证更新持久化
#[tokio::test]
async fn test_book_update() {
    ensure_storage_initialized().await;

    // 创建书籍
    let mut book = create_test_book("/tmp/test2.txt");
    data::book::upsert_book(book.clone())
        .await
        .expect("创建失败");

    // 更新书籍状态
    book.status = BookStatus::Completed;
    book.title = "更新后的标题".to_string();

    let result = data::book::upsert_book(book.clone()).await;
    assert!(result.is_ok(), "更新书籍应该成功");

    // 验证更新
    let retrieved = data::book::get_book(book.book_id.clone())
        .await
        .expect("获取失败")
        .expect("书籍不存在");

    assert_eq!(retrieved.status, BookStatus::Completed);
    assert_eq!(retrieved.title, "更新后的标题");

    println!("✓ 书籍更新测试通过");
}

#[tokio::test]
async fn test_book_delete() {
/// 测试删除书籍，验证删除后无法获取
    ensure_storage_initialized().await;

    // 创建书籍
    let book = create_test_book("/tmp/test3.txt");
    let book_id = book.book_id.clone();

    data::book::upsert_book(book).await.expect("创建失败");

    // 删除书籍
    let result = data::book::delete_book(book_id.clone(), String::new()).await;
    assert!(result.is_ok(), "删除书籍应该成功");

    // 验证删除
    let result = data::book::get_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "删除后应该找不到书籍");

    println!("✓ 书籍删除测试通过");
}

#[tokio::test]
async fn test_book_list_all() {
/// 测试获取所有书籍列表，验证列表完整性
    ensure_storage_initialized().await;

    // 创建多本书籍（使用唯一 ID 避免冲突）
    for i in 0..3 {
        let mut book = create_test_book(&format!("/tmp/test_list_{}.txt", i));
        book.book_id = format!("unique_book_list_{}", i);
        book.title = format!("书籍{}", i);
        data::book::upsert_book(book).await.expect("创建失败");
    }

    // 获取所有书籍
    let result = data::book::list_books().await;
    assert!(result.is_ok(), "获取书籍列表应该成功");

    let books = result.unwrap();
    assert!(books.len() >= 3, "应该至少有3本书籍");

    println!("✓ 书籍列表测试通过，共 {} 本", books.len());
}

#[tokio::test]
async fn test_book_search() {
/// 测试按书名关键词搜索书籍
    ensure_storage_initialized().await;

    // 创建测试书籍
    let mut book1 = create_test_book("/tmp/search1.txt");
    book1.book_id = "unique_search_1".to_string();
    book1.title = "Rust编程指南".to_string();
    data::book::upsert_book(book1).await.expect("创建失败");

    let mut book2 = create_test_book("/tmp/search2.txt");
    book2.book_id = "unique_search_2".to_string();
    book2.title = "Python入门教程".to_string();
    data::book::upsert_book(book2).await.expect("创建失败");

    // 搜索书籍
    let result = data::book::search_books("Rust".to_string()).await;
    assert!(result.is_ok(), "搜索应该成功");

    let books = result.unwrap();
    assert!(books.len() >= 1, "应该至少找到1本包含'Rust'的书籍");

    println!("✓ 书籍搜索测试通过");
}

#[tokio::test]
async fn test_book_get_by_status() {
/// 测试按阅读状态筛选书籍
    ensure_storage_initialized().await;

    // 创建不同状态的书籍
    let mut book1 = create_test_book("/tmp/status1.txt");
    book1.book_id = "unique_status_1".to_string();
    book1.status = BookStatus::Reading;
    data::book::upsert_book(book1).await.expect("创建失败");

    let mut book2 = create_test_book("/tmp/status2.txt");
    book2.book_id = "unique_status_2".to_string();
    book2.status = BookStatus::Completed;
    data::book::upsert_book(book2).await.expect("创建失败");

    let mut book3 = create_test_book("/tmp/status3.txt");
    book3.book_id = "unique_status_3".to_string();
    book3.status = BookStatus::Reading;
    data::book::upsert_book(book3).await.expect("创建失败");

    // 获取阅读中的书籍
    let result = data::book::list_books_by_status(BookStatus::Reading).await;
    assert!(result.is_ok(), "获取书籍应该成功");

    let books = result.unwrap();
    assert!(books.len() >= 2, "应该至少有2本阅读中的书籍");

    println!("✓ 按状态获取书籍测试通过");
}

// ==================== 书签 CRUD 测试 ====================

#[tokio::test]
async fn test_bookmark_create_and_get() {
/// 测试创建书签并获取，验证字段正确性
    ensure_storage_initialized().await;

    // 先创建关联的书籍记录
    let book = create_test_book("/tmp/bookmark_test.txt");
    let book_id = book.book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建书签
    let result = data::bookmark::create_bookmark(
        book_id.clone(),
        0,   // chapter_index
        100, // char_offset
        "第一章标记".to_string(),
    )
    .await;

    assert!(result.is_ok(), "创建书签应该成功");
    let bookmark = result.unwrap();
    let bookmark_id = bookmark.id.clone();

    assert_eq!(bookmark.book_id, book_id);
    assert_eq!(bookmark.title, "第一章标记");
    assert_eq!(bookmark.char_offset, 100);

    // 获取书签
    let result = data::bookmark::get_bookmark(bookmark_id.clone()).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_some(), "应该能找到书签");

    println!("✓ 书签创建和获取测试通过");
}

#[tokio::test]
/// 测试按书籍获取所有书签列表
async fn test_bookmark_list_by_book() {
    ensure_storage_initialized().await;

    let book_id = "test_book_for_list_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_list_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建多个书签
    for i in 0..5 {
        data::bookmark::create_bookmark(
            book_id.clone(),
            i as i32,
            i as i64 * 100,
            format!("书签{}", i),
        )
        .await
        .expect("创建失败");
    }

    // 获取书签列表
    let result = data::bookmark::list_bookmarks_by_book(book_id.clone()).await;
    assert!(result.is_ok(), "获取书签列表应该成功");

    let bookmarks = result.unwrap();
    assert_eq!(bookmarks.len(), 5, "应该有5个书签");

    println!("✓ 书签列表测试通过，共 {} 个", bookmarks.len());
}

#[tokio::test]
async fn test_bookmark_delete() {
/// 测试删除书签，验证删除后无法获取
    ensure_storage_initialized().await;

    let book_id = "test_book_for_delete_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_delete_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建书签
    let bookmark =
        data::bookmark::create_bookmark(book_id.clone(), 0, 50, "待删除书签".to_string())
            .await
            .expect("创建失败");

    let bookmark_id = bookmark.id.clone();

    // 删除书签
    let result = data::bookmark::delete_bookmark(bookmark_id.clone()).await;
    assert!(result.is_ok(), "删除书签应该成功");

    // 验证删除
    let result = data::bookmark::get_bookmark(bookmark_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "删除后应该找不到书签");

    println!("✓ 书签删除测试通过");
}

#[tokio::test]
async fn test_bookmark_clear_by_book() {
/// 测试清除某本书的所有书签
    ensure_storage_initialized().await;

    let book_id = "test_book_for_clear_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/bookmark_clear_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建多个书签
    for i in 0..3 {
        data::bookmark::create_bookmark(
            book_id.clone(),
            i as i32,
            i as i64 * 100,
            format!("书签{}", i),
        )
        .await
        .expect("创建失败");
    }

    // 清除所有书签
    let result = data::bookmark::clear_bookmarks_by_book(book_id.clone()).await;
    assert!(result.is_ok(), "清除书签应该成功");

    // 验证清除
    let result = data::bookmark::list_bookmarks_by_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "清除后应该没有书签");

    println!("✓ 清除书签测试通过");
}

// ==================== 笔记 CRUD 测试 ====================

#[tokio::test]
async fn test_note_create_highlight() {
/// 测试创建高亮笔记，验证类型和字段正确性
    ensure_storage_initialized().await;

    let book_id = "test_book_for_highlight_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_highlight_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建高亮笔记
    let result = data::note::create_highlight(
        book_id.clone(),
        0,   // chapter_index
        100, // char_offset
        50,  // length
        "这是高亮文本".to_string(),
        0xFFFF00, // color (yellow)
        None,     // language
        None,     // paired_note_id
    )
    .await;

    assert!(result.is_ok(), "创建高亮应该成功");
    let note = result.unwrap();

    assert_eq!(note.book_id, book_id);
    assert_eq!(note.note_type, NoteType::Highlight);
    assert_eq!(note.selected_text, Some("这是高亮文本".to_string()));
    assert_eq!(note.length, 50);

    println!("✓ 高亮笔记创建测试通过");
}

#[tokio::test]
async fn test_note_create_annotation() {
/// 测试创建批注笔记，验证类型和字段正确性
    ensure_storage_initialized().await;

    let book_id = "test_book_for_annotation_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_annotation_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建批注笔记
    let result = data::note::create_annotation(
        book_id.clone(),
        1,   // chapter_index
        200, // char_offset
        "这是批注内容".to_string(),
        Some("关联文本".to_string()),
        Some("zh".to_string()), // language
        None,                   // paired_note_id
    )
    .await;

    assert!(result.is_ok(), "创建批注应该成功");
    let note = result.unwrap();

    assert_eq!(note.book_id, book_id);
    assert_eq!(note.note_type, NoteType::Annotation);
    assert_eq!(note.content, "这是批注内容");

    println!("✓ 批注笔记创建测试通过");
}

#[tokio::test]
async fn test_note_list_by_book() {
/// 测试按书籍获取所有笔记列表，支持按类型筛选
    ensure_storage_initialized().await;

    let book_id = "test_book_for_notes_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_list_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建多个笔记
    data::note::create_highlight(
        book_id.clone(),
        0,
        100,
        50,
        "高亮1".to_string(),
        0xFFFF00,
        None,
        None,
    )
    .await
    .expect("创建失败");

    data::note::create_annotation(
        book_id.clone(),
        0,
        200,
        "批注1".to_string(),
        None,
        None,
        None,
    )
    .await
    .expect("创建失败");

    data::note::create_highlight(
        book_id.clone(),
        1,
        300,
        30,
        "高亮2".to_string(),
        0xFF0000,
        None,
        None,
    )
    .await
    .expect("创建失败");

    // 获取所有笔记
    let result = data::note::list_notes_by_book(book_id.clone(), None).await;
    assert!(result.is_ok(), "获取笔记列表应该成功");

    let notes = result.unwrap();
    assert_eq!(notes.len(), 3, "应该有3个笔记");

    println!("✓ 笔记列表测试通过，共 {} 个", notes.len());
}

#[tokio::test]
async fn test_note_list_by_type() {
/// 测试按笔记类型筛选笔记
    ensure_storage_initialized().await;

    let book_id = "test_book_for_type_filter_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_type_filter_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建不同类型的笔记
    data::note::create_highlight(
        book_id.clone(),
        0,
        100,
        50,
        "高亮".to_string(),
        0xFFFF00,
        None,
        None,
    )
    .await
    .expect("创建失败");

    data::note::create_annotation(
        book_id.clone(),
        0,
        200,
        "批注".to_string(),
        None,
        None,
        None,
    )
    .await
    .expect("创建失败");

    // 只获取高亮笔记
    let result = data::note::list_notes_by_book(book_id.clone(), Some(NoteType::Highlight)).await;
    assert!(result.is_ok());

    let notes = result.unwrap();
    assert_eq!(notes.len(), 1, "应该只有1个高亮笔记");
    assert_eq!(notes[0].note_type, NoteType::Highlight);

    println!("✓ 按类型筛选笔记测试通过");
}

#[tokio::test]
async fn test_note_delete() {
/// 测试删除笔记
    ensure_storage_initialized().await;

    let book_id = "test_book_for_note_delete_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_delete_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建笔记
    let note = data::note::create_highlight(
        book_id,
        0,
        100,
        50,
        "待删除".to_string(),
        0xFFFF00,
        None,
        None,
    )
    .await
    .expect("创建失败");

    let note_id = note.id.clone();

    // 删除笔记
    let result = data::note::delete_note(note_id.clone()).await;
    assert!(result.is_ok(), "删除笔记应该成功");

    println!("✓ 笔记删除测试通过");
}

#[tokio::test]
async fn test_note_clear_by_book() {
/// 测试清除某本书的所有笔记
    ensure_storage_initialized().await;

    let book_id = "test_book_for_note_clear_unique".to_string();

    // 先创建关联的书籍记录
    let mut book = create_test_book("/tmp/note_clear_test.txt");
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 创建多个笔记
    for i in 0..3 {
        data::note::create_highlight(
            book_id.clone(),
            0,
            i as i64 * 100,
            50,
            format!("笔记{}", i),
            0xFFFF00,
            None,
            None,
        )
        .await
        .expect("创建失败");
    }

    // 清除所有笔记
    let result = data::note::clear_notes_by_book(book_id.clone()).await;
    assert!(result.is_ok(), "清除笔记应该成功");

    // 验证清除
    let result = data::note::list_notes_by_book(book_id, None).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "清除后应该没有笔记");

    println!("✓ 清除笔记测试通过");
}

// ==================== 数据一致性测试 ====================

#[tokio::test]
async fn test_book_and_bookmark_relation() {
/// 测试删除书籍时级联删除关联书签
    ensure_storage_initialized().await;

    // 创建书籍
    let mut book = create_test_book("/tmp/relation_test.txt");
    let book_id = "test_relation_bookmark_book".to_string();
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 为书籍创建书签
    data::bookmark::create_bookmark(book_id.clone(), 0, 100, "关联测试".to_string())
        .await
        .expect("创建书签失败");

    // 删除书籍（应该级联删除书签）
    data::book::delete_book(book_id.clone(), String::new())
        .await
        .expect("删除书籍失败");

    // 验证书签也被删除
    let result = data::bookmark::list_bookmarks_by_book(book_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "删除书籍后书签应该也被删除");

    println!("✓ 书籍-书签关联删除测试通过");
}

#[tokio::test]
async fn test_book_and_note_relation() {
/// 测试删除书籍时级联删除关联笔记
    ensure_storage_initialized().await;

    // 创建书籍
    let mut book = create_test_book("/tmp/note_relation_test.txt");
    let book_id = "test_relation_note_book".to_string();
    book.book_id = book_id.clone();
    data::book::upsert_book(book).await.expect("创建书籍失败");

    // 为书籍创建笔记
    data::note::create_highlight(
        book_id.clone(),
        0,
        100,
        50,
        "关联测试".to_string(),
        0xFFFF00,
        None,
        None,
    )
    .await
    .expect("创建笔记失败");

    // 删除书籍
    data::book::delete_book(book_id.clone(), String::new())
        .await
        .expect("删除书籍失败");

    // 验证笔记也被删除
    let result = data::note::list_notes_by_book(book_id, None).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "删除书籍后笔记应该也被删除");

    println!("✓ 书籍-笔记关联删除测试通过");
}
