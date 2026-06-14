//! 生词管理 API 集成测试
//!
//! 测试生词的 CRUD：创建、列表筛选、搜索、状态更新、删除、统计。

mod common;

use rust_lib_zephyr_reader::api::data::vocabulary;
use rust_lib_zephyr_reader::storage::models::VocabStatus;


// 使用 tag 生成唯一的单词名称，避免并行测试间数据污染
fn unique_word(name: &str) -> String {
    format!("vocab_test_{name}")
}

#[tokio::test]
async fn test_create_and_list_vocab_word() {
    common::init_logger();
    common::init_test_storage().await;

    let word = unique_word("create_list");
    let entry = vocabulary::create_vocabulary_word(
        word.clone(), "fang qi".to_string(), "放弃".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();
    assert_eq!(entry.word, word);

    // list 返回所有词，至少包含刚创建的这个
    let words = vocabulary::list_vocabulary_by_status(None, None, None)
        .await
        .unwrap();
    assert!(
        words.iter().any(|w| w.word == word),
        "created word should appear in list"
    );
}

#[tokio::test]
async fn test_create_vocab_with_book_and_word_list() {
    common::init_logger();
    common::init_test_storage().await;

    let entry = vocabulary::create_vocabulary_word(
        unique_word("with_context").to_string(),
        String::new(), "你好".to_string(),
        Some("Hello, world!".to_string()),
        Some("book1".to_string()),
        Some(1), Some(100),
        Some("CET-4".to_string()),
    )
    .await
    .unwrap();

    assert_eq!(entry.book_id.as_deref(), Some("book1"));
    assert_eq!(entry.word_list.as_deref(), Some("CET-4"));
    assert_eq!(entry.chapter_index, Some(1));
    assert_eq!(entry.char_offset, Some(100));
}

#[tokio::test]
async fn test_list_vocab_filter_by_status() {
    common::init_logger();
    common::init_test_storage().await;

    let word = unique_word("filter_status");
    let entry = vocabulary::create_vocabulary_word(
        word.clone(), String::new(), "你好".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();

    // 将状态改为 Mastered
    vocabulary::update_vocabulary_status(entry.id.clone(), VocabStatus::Mastered)
        .await
        .unwrap();

    // 按 Mastered 筛选应能找到
    let mastered = vocabulary::list_vocabulary_by_status(
        None, Some(VocabStatus::Mastered), None,
    )
    .await
    .unwrap();
    assert!(
        mastered.iter().any(|w| w.word == word),
        "Mastered word should appear in Mastered filter"
    );
    assert!(
        mastered.iter().all(|w| w.status == VocabStatus::Mastered),
        "all returned words should be Mastered"
    );

    // 按 Unstarted 筛选不应包含该词
    let unstarted = vocabulary::list_vocabulary_by_status(
        None, Some(VocabStatus::Unstarted), None,
    )
    .await
    .unwrap();
    assert!(
        unstarted.iter().all(|w| w.word != word),
        "Mastered word should not appear in Unstarted filter"
    );
}

#[tokio::test]
async fn test_list_vocab_filter_by_word_list() {
    common::init_logger();
    common::init_test_storage().await;

    let w1 = unique_word("wl_cet4");
    let w2 = unique_word("wl_cet6");

    vocabulary::create_vocabulary_word(
        w1.clone(), String::new(), "你好".to_string(),
        None, None, None, None, Some("CET-4".to_string()),
    )
    .await
    .unwrap();
    vocabulary::create_vocabulary_word(
        w2.clone(), String::new(), "世界".to_string(),
        None, None, None, None, Some("CET-6".to_string()),
    )
    .await
    .unwrap();

    let cet4 = vocabulary::list_vocabulary_by_status(
        None, None, Some("CET-4".to_string()),
    )
    .await
    .unwrap();
    assert!(
        cet4.iter().any(|w| w.word == w1),
        "CET-4 word should appear in CET-4 filter"
    );
    assert!(
        cet4.iter().all(|w| w.word_list.as_deref() == Some("CET-4")),
        "all returned should be CET-4"
    );
}

#[tokio::test]
async fn test_search_vocabulary() {
    common::init_logger();
    common::init_test_storage().await;

    let unique = unique_word("search_target");
    vocabulary::create_vocabulary_word(
        unique.clone(), "".to_string(), "测试".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();
    vocabulary::create_vocabulary_word(
        "other_word_dummy".to_string(), "".to_string(), "占位".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();

    // 搜索唯一词应精确命中
    let results = vocabulary::search_vocabulary_words(unique.clone())
        .await
        .unwrap();
    assert!(
        results.iter().any(|w| w.word == unique),
        "search should find the target word"
    );
    assert_eq!(results.len(), 1, "should find exactly 1");

    // 搜索不存在的词应返回空
    let no_results = vocabulary::search_vocabulary_words("ZZZZZ_NONEXISTENT".to_string())
        .await
        .unwrap();
    assert!(no_results.is_empty());
}

#[tokio::test]
async fn test_update_vocabulary_status() {
    common::init_logger();
    common::init_test_storage().await;

    let word = unique_word("status_update");
    let entry = vocabulary::create_vocabulary_word(
        word.clone(), String::new(), "你好".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();
    assert_eq!(entry.status, VocabStatus::Unstarted);

    vocabulary::update_vocabulary_status(entry.id.clone(), VocabStatus::Mastered)
        .await
        .unwrap();

    // 按 Mastered 筛选应出现
    let mastered = vocabulary::list_vocabulary_by_status(
        None, Some(VocabStatus::Mastered), None,
    )
    .await
    .unwrap();
    assert!(mastered.iter().any(|w| w.word == word));
}

#[tokio::test]
async fn test_delete_vocabulary() {
    common::init_logger();
    common::init_test_storage().await;

    let word = unique_word("delete_me");
    let entry = vocabulary::create_vocabulary_word(
        word.clone(), String::new(), "你好".to_string(),
        None, None, None, None, None,
    )
    .await
    .unwrap();

    vocabulary::delete_vocabulary(entry.id.clone()).await.unwrap();

    let all = vocabulary::list_vocabulary_by_status(None, None, None)
        .await
        .unwrap();
    assert!(
        all.iter().all(|w| w.word != word),
        "deleted word should not appear in list"
    );
}

#[tokio::test]
async fn test_vocabulary_stats() {
    common::init_logger();
    common::init_test_storage().await;

    // stats 返回全局值，无法精确断言具体数字
    // 验证类型和结构正确即可
    let stats = vocabulary::get_vocabulary_stats().await.unwrap();
    assert!(stats.total_words >= 0, "total_words should be non-negative");
    assert!(
        stats.learning_count + stats.unstarted_count + stats.mastered_count + stats.ignored_count
            <= stats.total_words,
        "status breakdown should not exceed total"
    );
}

#[tokio::test]
async fn test_list_word_lists() {
    common::init_logger();
    common::init_test_storage().await;

    let lists = vocabulary::list_word_lists();
    assert!(!lists.is_empty(), "should have at least one built-in list");
    assert!(
        lists.contains(&"CET-4".to_string()),
        "should contain CET-4"
    );
    assert!(
        lists.contains(&"CET-6".to_string()),
        "should contain CET-6"
    );
}
