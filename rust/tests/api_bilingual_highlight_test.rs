//! 双语高亮配对 API 集成测试
//!
//! 测试 create_bilingual_highlight_pair / get_bilingual_highlight_pairs / delete_bilingual_highlight_pair

mod common;

use rust_lib_zephyr_reader::api::bilingual::{
    create_bilingual_highlight_pair, delete_bilingual_highlight_pair,
    get_bilingual_highlight_pairs, BilingualHighlightParams,
};
use rust_lib_zephyr_reader::api::data::{self, init};
use rust_lib_zephyr_reader::storage::models::{Book, BookFormat, BookStatus};
use std::sync::OnceLock;
use tempfile::TempDir;

// ==================== 测试工具函数 ====================

static TEST_STORAGE: OnceLock<TempDir> = OnceLock::new();

// 初始化测试存储环境（全局只初始化一次）
async fn ensure_storage_initialized() {
    if TEST_STORAGE.get().is_some() {
        return;
    }
    let temp_dir = TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();
    if let Err(e) = init::init_storage(data_dir).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {e}");
        }
    }
    TEST_STORAGE.get_or_init(|| temp_dir);
}

// 创建测试书籍模板
fn create_test_book(file_path: &str) -> Book {
    Book {
        book_id: uuid::Uuid::new_v4().to_string(),
        file_path: file_path.to_string(),
        file_hash: Some("test_hash".to_string()),
        file_size: 1024,
        file_mtime: None,
        title: "双语测试书籍".to_string(),
        author: Some("测试作者".to_string()),
        cover_path: None,
        chapter_count: 10,
        total_characters: 10000,
        format: BookFormat::Epub,
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

// ==================== 创建 & 获取测试 ====================

#[tokio::test]
async fn test_create_and_get_bilingual_pair() {
    // 测试创建双语高亮配对，再通过 get 获取并验证字段正确性
    ensure_storage_initialized().await;

    let book_id = "bilingual-book-create-get".to_string();
    let mut book = create_test_book("/test/bilingual_cg.epub");
    book.book_id = book_id.clone();
    data::book::upsert_book(book)
        .await
        .expect("failed to create test book");

    let params = BilingualHighlightParams {
        source_book_id: book_id.clone(),
        source_chapter_index: 0,
        source_char_offset: 10,
        source_length: 5,
        source_selected_text: "中文高亮".to_string(),
        source_language: "zh".to_string(),
        target_book_id: book_id.clone(),
        target_chapter_index: 0,
        target_char_offset: 100,
        target_length: 5,
        target_selected_text: "English highlight".to_string(),
        target_language: "en".to_string(),
        highlight_color: 0xFF0000,
    };

    let result = create_bilingual_highlight_pair(params).await;
    assert!(result.is_ok(), "创建双语高亮配对应该成功");
    let pair = result.unwrap();

    // 验证 source_note 字段
    assert_eq!(
        pair.source_note.selected_text.as_deref(),
        Some("中文高亮")
    );
    // 验证 target_note 存在且字段正确
    assert!(pair.target_note.is_some(), "target_note 应该存在");
    assert_eq!(
        pair.target_note
            .as_ref()
            .unwrap()
            .selected_text
            .as_deref(),
        Some("English highlight")
    );
    // 验证配对 ID 一致
    assert_eq!(
        pair.source_note.paired_note_id,
        pair.target_note.as_ref().unwrap().paired_note_id
    );

    // 通过 get_bilingual_highlight_pairs 获取并验证
    let pairs = get_bilingual_highlight_pairs(book_id.clone(), 0)
        .await
        .expect("获取双语高亮列表应该成功");
    assert_eq!(pairs.len(), 1, "应该返回 1 个配对");
    assert_eq!(
        pairs[0].source_note.selected_text.as_deref(),
        Some("中文高亮")
    );
    assert!(pairs[0].target_note.is_some());
    assert_eq!(
        pairs[0]
            .target_note
            .as_ref()
            .unwrap()
            .selected_text
            .as_deref(),
        Some("English highlight")
    );
}

// ==================== 空章节测试 ====================

#[tokio::test]
async fn test_get_bilingual_pairs_empty_chapter() {
    // 测试查询不存在的书籍或没有配对的章节应返回空列表
    ensure_storage_initialized().await;

    let pairs = get_bilingual_highlight_pairs("nonexistent-book".to_string(), 0).await;
    assert!(pairs.is_ok(), "查询不存在的书籍应返回 Ok");
    assert!(
        pairs.unwrap().is_empty(),
        "不存在的书籍应返回空列表"
    );
}

// ==================== 删除测试 ====================

#[tokio::test]
async fn test_delete_bilingual_pair() {
    // 测试删除双语高亮配对后，配对的双方都被删除
    ensure_storage_initialized().await;

    let book_id = "bilingual-book-delete".to_string();
    let mut book = create_test_book("/test/bilingual_del.epub");
    book.book_id = book_id.clone();
    data::book::upsert_book(book)
        .await
        .expect("failed to create test book");

    // 创建配对
    let pair = create_bilingual_highlight_pair(BilingualHighlightParams {
        source_book_id: book_id.clone(),
        source_chapter_index: 0,
        source_char_offset: 10,
        source_length: 5,
        source_selected_text: "中文".to_string(),
        source_language: "zh".to_string(),
        target_book_id: book_id.clone(),
        target_chapter_index: 0,
        target_char_offset: 100,
        target_length: 5,
        target_selected_text: "English".to_string(),
        target_language: "en".to_string(),
        highlight_color: 0xFF0000,
    })
    .await
    .expect("创建双语高亮配对失败");

    let source_note_id = pair.source_note.id.clone();

    // 通过 source note ID 删除
    let delete_result = delete_bilingual_highlight_pair(source_note_id).await;
    assert!(
        delete_result.is_ok(),
        "删除双语高亮配对应该成功"
    );

    // 验证删除后列表为空
    let pairs = get_bilingual_highlight_pairs(book_id.clone(), 0)
        .await
        .expect("获取双语高亮列表应该成功");
    assert!(pairs.is_empty(), "删除后配对列表应该为空");
}

#[tokio::test]
async fn test_delete_nonexistent_pair() {
    // 测试删除不存在的配对 ID 应静默成功（无操作）
    ensure_storage_initialized().await;

    let result = delete_bilingual_highlight_pair("nonexistent-id".to_string()).await;
    assert!(
        result.is_ok(),
        "删除不存在的配对应静默成功"
    );
}

// ==================== 跨章节测试 ====================

#[tokio::test]
async fn test_create_bilingual_pair_same_book_diff_chapters() {
    // 测试在同一本书的不同章节间创建双语高亮配对
    ensure_storage_initialized().await;

    let book_id = "bilingual-book-diff-chapters".to_string();
    let mut book = create_test_book("/test/bilingual_diffc.epub");
    book.book_id = book_id.clone();
    data::book::upsert_book(book)
        .await
        .expect("failed to create test book");

    // 创建配对：source 在 chapter 0，target 在 chapter 1
    let params = BilingualHighlightParams {
        source_book_id: book_id.clone(),
        source_chapter_index: 0,
        source_char_offset: 10,
        source_length: 5,
        source_selected_text: "中文高亮".to_string(),
        source_language: "zh".to_string(),
        target_book_id: book_id.clone(),
        target_chapter_index: 1,
        target_char_offset: 100,
        target_length: 5,
        target_selected_text: "English highlight".to_string(),
        target_language: "en".to_string(),
        highlight_color: 0xFF0000,
    };

    let result = create_bilingual_highlight_pair(params).await;
    assert!(result.is_ok(), "跨章节创建双语高亮应成功");

    // 按 source 的 chapter (0) 查询应返回该配对
    let pairs = get_bilingual_highlight_pairs(book_id.clone(), 0)
        .await
        .expect("获取双语高亮列表应该成功");
    assert_eq!(pairs.len(), 1, "chapter 0 应该返回 1 个配对");
    assert_eq!(
        pairs[0].source_note.selected_text.as_deref(),
        Some("中文高亮")
    );
    assert!(
        pairs[0].target_note.is_some(),
        "target_note 应存在"
    );

    // 按 target 的 chapter (1) 查询也应返回该配对（target note 也有 paired_note_id）
    let pairs_target = get_bilingual_highlight_pairs(book_id.clone(), 1)
        .await
        .expect("获取双语高亮列表应该成功");
    assert_eq!(
        pairs_target.len(),
        1,
        "chapter 1 也应返回 1 个配对"
    );
    assert_eq!(
        pairs_target[0].source_note.selected_text.as_deref(),
        Some("English highlight"),
        "chapter 1 中 source_note 应为 target 侧文本"
    );
}
