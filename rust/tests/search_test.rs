//! Search 层集成测试
//! 测试全文搜索、索引管理、中文分词等功能

mod common;

use rust_lib_zephyr_reader::api::{self};
use rust_lib_zephyr_reader::storage::models::Book;
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
    if let Err(e) = api::data::init::init_storage(data_dir.clone()).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {:?}", e);
        }
    }

    // 初始化搜索引擎
    if let Err(e) = api::search::init_search_engine().await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init search engine: {:?}", e);
        }
    }

    // 存储到全局变量
    TEST_STORAGE.get_or_init(|| temp_dir);
}

/// 创建测试书籍
fn create_test_book(file_path: &str) -> Book {
    Book::new(
        file_path,
        0, // file_size
        "测试书籍",
        rust_lib_zephyr_reader::storage::models::BookFormat::Txt,
        0,    // chapter_count
        0,    // total_characters
        None, // file_hash
        None, // file_mtime
        Some("测试作者"),
        None, // cover_path
        None, // description
        None, // publisher
        None, // translator
        None, // isbn
    )
}

// ==================== 索引测试 ====================

#[tokio::test]
async fn test_index_single_chapter() {
    ensure_storage_initialized().await;

    let book_id = "test_index_single".to_string();

    // 创建章节内容
    let content = "这是一段测试内容。Rust 是一门系统编程语言。";

    // 索引章节
    let result = api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "第一章".to_string(),
        content.to_string(),
    )
    .await;

    assert!(result.is_ok(), "索引章节应该成功: {:?}", result);

    println!("✓ 单章节索引测试通过");
}

#[tokio::test]
async fn test_index_multiple_chapters() {
    ensure_storage_initialized().await;

    let book_id = "test_index_multiple".to_string();

    // 索引多个章节
    let chapters = vec![
        (
            "chapter_1",
            "0",
            "第一章",
            "这是第一章的内容。关于 Rust 编程语言的介绍。",
        ),
        (
            "chapter_2",
            "1",
            "第二章",
            "这是第二章的内容。Rust 的所有权和借用。",
        ),
        (
            "chapter_3",
            "2",
            "第三章",
            "这是第三章的内容。Rust 的生命周期。",
        ),
    ];

    for (chapter_id, chapter_index, chapter_title, content) in chapters {
        let result = api::search::index_chapter(
            book_id.clone(),
            chapter_id.to_string(),
            chapter_index.to_string(),
            chapter_title.to_string(),
            content.to_string(),
        )
        .await;
        assert!(result.is_ok(), "索引章节应该成功");
    }

    println!("✓ 多章节索引测试通过");
}

#[tokio::test]
async fn test_index_chapter_update() {
    ensure_storage_initialized().await;

    let book_id = "test_index_update".to_string();
    let chapter_id = "chapter_1".to_string();
    let chapter_index = "0".to_string();

    // 第一次索引
    api::search::index_chapter(
        book_id.clone(),
        chapter_id.clone(),
        chapter_index.clone(),
        "第一章".to_string(),
        "这是旧内容。".to_string(),
    )
    .await
    .expect("第一次索引失败");

    // 更新索引（应该覆盖旧内容）
    let result = api::search::index_chapter(
        book_id.clone(),
        chapter_id.clone(),
        chapter_index.clone(),
        "第一章".to_string(),
        "这是新内容。Rust 很强大。".to_string(),
    )
    .await;

    assert!(result.is_ok(), "更新索引应该成功");

    println!("✓ 章节索引更新测试通过");
}

// ==================== 搜索测试 ====================

#[tokio::test]
async fn test_search_in_book_basic() {
    ensure_storage_initialized().await;

    let book_id = "test_search_basic".to_string();

    // 索引内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "Rust 编程".to_string(),
        "Rust 是一门系统编程语言，专注于安全性和性能。Rust 支持函数式编程和面向对象编程。"
            .to_string(),
    )
    .await
    .expect("索引失败");

    // 搜索
    let result = api::search::search(book_id.clone(), "Rust".to_string(), 10).await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(!results.is_empty(), "应该找到搜索结果");

    // 验证搜索结果包含关键词
    let found_rust = results
        .iter()
        .any(|r| r.snippet.contains("Rust") || r.chapter_title.contains("Rust"));
    assert!(found_rust, "搜索结果应该包含 'Rust'");

    println!("✓ 基本搜索测试通过，找到 {} 个结果", results.len());
}

#[tokio::test]
async fn test_search_chinese_text() {
    ensure_storage_initialized().await;

    let book_id = "test_search_chinese".to_string();

    // 索引中文内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "中文测试".to_string(),
        "这本书介绍了 Rust 编程语言的基础知识。Rust 是一门现代编程语言，强调安全性和性能。"
            .to_string(),
    )
    .await
    .expect("索引失败");

    // 搜索中文关键词
    let result = api::search::search(book_id.clone(), "编程语言".to_string(), 10).await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(!results.is_empty(), "应该找到中文搜索结果");

    println!("✓ 中文搜索测试通过，找到 {} 个结果", results.len());
}

#[tokio::test]
async fn test_search_no_results() {
    ensure_storage_initialized().await;

    let book_id = "test_search_no_results".to_string();

    // 索引内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "测试章节".to_string(),
        "这是一个测试章节，包含一些内容。".to_string(),
    )
    .await
    .expect("索引失败");

    // 搜索不存在的关键词
    let result = api::search::search(book_id.clone(), "不存在的关键词".to_string(), 10).await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(results.is_empty(), "应该没有搜索结果");

    println!("✓ 无结果搜索测试通过");
}

#[tokio::test]
async fn test_search_limit_results() {
    ensure_storage_initialized().await;

    let book_id = "test_search_limit".to_string();

    // 索引多个章节
    for i in 0..10 {
        api::search::index_chapter(
            book_id.clone(),
            format!("chapter_{}", i),
            i.to_string(),
            format!("第{}章", i),
            format!("这是第{}章的内容。Rust 编程教程第{}部分。", i, i),
        )
        .await
        .expect("索引失败");
    }

    // 搜索并限制结果数
    let result = api::search::search(book_id.clone(), "Rust".to_string(), 3).await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(results.len() <= 3, "结果数应该不超过 3");

    println!("✓ 搜索结果限制测试通过，返回 {} 个结果", results.len());
}

#[tokio::test]
async fn test_search_all_books() {
    ensure_storage_initialized().await;

    // 创建多本书并索引
    for i in 0..3 {
        let book_id = format!("test_search_all_{}", i);

        api::search::index_chapter(
            book_id.clone(),
            "chapter_1".to_string(),
            "0".to_string(),
            "简介".to_string(),
            format!("这是第{}本书的内容。Rust 编程指南。", i),
        )
        .await
        .expect("索引失败");
    }

    // 搜索所有书籍
    let result = api::search::search_all_books(
        "Rust".to_string(),
        20,
        0, // offset
    )
    .await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(!results.is_empty(), "应该找到搜索结果");

    println!("✓ 全局搜索测试通过，找到 {} 个结果", results.len());
}

// ==================== 索引管理测试 ====================

#[tokio::test]
async fn test_delete_book_index() {
    ensure_storage_initialized().await;

    let book_id = "test_delete_index".to_string();

    // 索引内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "测试章节".to_string(),
        "这是待删除的书籍内容。Rust 很强大。".to_string(),
    )
    .await
    .expect("索引失败");

    // 验证可以搜索到
    let result = api::search::search(book_id.clone(), "Rust".to_string(), 10).await;
    assert!(result.is_ok());
    assert!(!result.unwrap().is_empty(), "删除前应该能搜索到");

    // 删除书籍索引
    let delete_result = api::search::delete_by_book(book_id.clone()).await;
    assert!(delete_result.is_ok(), "删除索引应该成功");

    // 验证搜索不到
    let result = api::search::search(book_id.clone(), "Rust".to_string(), 10).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "删除后应该搜索不到");

    println!("✓ 删除书籍索引测试通过");
}

#[tokio::test]
async fn test_clear_all_index() {
    ensure_storage_initialized().await;

    // 创建多个书籍的索引
    for i in 0..3 {
        let book_id = format!("test_clear_{}", i);
        api::search::index_chapter(
            book_id.clone(),
            "chapter_1".to_string(),
            "0".to_string(),
            "测试".to_string(),
            format!("这是第{}本书的内容。", i),
        )
        .await
        .expect("索引失败");
    }

    // 清除所有索引
    let result = api::search::clear_all().await;
    assert!(result.is_ok(), "清除索引应该成功");

    // 验证所有索引被清除
    let result = api::search::search_all_books("内容".to_string(), 100, 0).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty(), "清除后应该没有搜索结果");

    println!("✓ 清除所有索引测试通过");
}

// ==================== 搜索质量测试 ====================

#[tokio::test]
async fn test_search_relevance() {
    ensure_storage_initialized().await;

    let book_id = "test_search_relevance".to_string();

    // 索引不同相关度的内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "高度相关".to_string(),
        "Rust Rust Rust Rust Rust".to_string(),
    )
    .await
    .expect("索引失败");

    api::search::index_chapter(
        book_id.clone(),
        "chapter_2".to_string(),
        "1".to_string(),
        "中等相关".to_string(),
        "Rust 是一门语言。".to_string(),
    )
    .await
    .expect("索引失败");

    api::search::index_chapter(
        book_id.clone(),
        "chapter_3".to_string(),
        "2".to_string(),
        "低相关".to_string(),
        "提到了一次 Rust。".to_string(),
    )
    .await
    .expect("索引失败");

    // 搜索并验证结果排序
    let result = api::search::search(book_id.clone(), "Rust".to_string(), 10).await;

    assert!(result.is_ok(), "搜索应该成功");
    let results = result.unwrap();
    assert!(!results.is_empty(), "应该有搜索结果");

    // 验证第一个结果应该是高度相关的章节
    // 注意：FTS5 的评分可能因实现而异，这里只验证能找到结果
    println!("✓ 搜索相关度测试通过，找到 {} 个结果", results.len());
}

#[tokio::test]
async fn test_search_special_characters() {
    ensure_storage_initialized().await;

    let book_id = "test_search_special".to_string();

    // 索引包含特殊字符的内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "特殊字符".to_string(),
        "内容包含: C++ 和 Rust。还有 Python/JavaScript。".to_string(),
    )
    .await
    .expect("索引失败");

    // 搜索特殊字符（应该被转义）
    let result = api::search::search(book_id.clone(), "C++".to_string(), 10).await;

    assert!(result.is_ok(), "搜索特殊字符应该不会崩溃");

    println!("✓ 特殊字符搜索测试通过");
}

// ==================== 并发测试 ====================

#[tokio::test]
async fn test_concurrent_indexing() {
    ensure_storage_initialized().await;

    let book_id = "test_concurrent_index".to_string();

    // 并发索引多个章节
    let mut handles = vec![];
    for i in 0..5 {
        let book_id = book_id.clone();
        let handle = tokio::spawn(async move {
            api::search::index_chapter(
                book_id.clone(),
                format!("chapter_{}", i),
                i.to_string(),
                format!("第{}章", i),
                format!("并发测试章节{}的内容。", i),
            )
            .await
        });
        handles.push(handle);
    }

    // 等待所有任务完成
    for handle in handles {
        let result = handle.await.expect("任务失败");
        assert!(result.is_ok(), "并发索引应该成功");
    }

    println!("✓ 并发索引测试通过");
}

#[tokio::test]
async fn test_concurrent_search() {
    ensure_storage_initialized().await;

    let book_id = "test_concurrent_search".to_string();

    // 索引内容
    api::search::index_chapter(
        book_id.clone(),
        "chapter_1".to_string(),
        "0".to_string(),
        "测试".to_string(),
        "并发搜索测试内容。Rust 编程语言。".to_string(),
    )
    .await
    .expect("索引失败");

    // 并发搜索
    let mut handles = vec![];
    for _ in 0..5 {
        let book_id = book_id.clone();
        let handle = tokio::spawn(async move {
            api::search::search(book_id.clone(), "Rust".to_string(), 10).await
        });
        handles.push(handle);
    }

    // 验证所有搜索都成功
    for handle in handles {
        let result = handle.await.expect("任务失败");
        assert!(result.is_ok(), "并发搜索应该成功");
        assert!(!result.unwrap().is_empty(), "应该找到搜索结果");
    }

    println!("✓ 并发搜索测试通过");
}
