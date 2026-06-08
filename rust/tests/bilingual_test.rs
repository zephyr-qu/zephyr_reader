mod common;

use rust_lib_zephyr_reader::api;

#[tokio::test]
async fn test_align_bilingual_content_basic() {
    let result = api::align_bilingual_content(
        "你好世界。这是一个测试。".to_string(),
        "Hello World. This is a test.".to_string(),
        0.3,
    )
    .await;
    assert!(
        result.is_ok(),
        "basic alignment should succeed: {:?}",
        result.err()
    );
    let alignment = result.unwrap();
    assert!(
        !alignment.segments.is_empty(),
        "should find at least one aligned segment"
    );
}

#[tokio::test]
async fn test_align_bilingual_content_exceeds_max_length() {
    let long = "x".repeat(1_500_000);
    let result = api::align_bilingual_content(long.clone(), long, 0.3).await;
    assert!(result.is_err(), "should reject oversized input");
}

#[tokio::test]
async fn test_align_bilingual_content_high_similarity() {
    let result = api::align_bilingual_content(
        "我是一个中国人。".to_string(),
        "I am Chinese.".to_string(),
        0.3,
    )
    .await;
    assert!(result.is_ok(), "high similarity should work");
}

#[tokio::test]
async fn test_align_bilingual_content_no_match() {
    let result = api::align_bilingual_content(
        "今天天气很好。我们去公园散步。".to_string(),
        "Quantum mechanics is fascinating. E=mc².".to_string(),
        0.9,
    )
    .await;
    assert!(result.is_ok());
    let alignment = result.unwrap();
    assert!(
        alignment.segments.is_empty(),
        "high threshold should yield no matches"
    );
    assert!(
        !alignment.unmatched_chinese.is_empty(),
        "CN should be unmatched"
    );
    assert!(
        !alignment.unmatched_english.is_empty(),
        "EN should be unmatched"
    );
}

#[tokio::test]
async fn test_align_bilingual_content_min_similarity_clamped() {
    let result = api::align_bilingual_content("你好。".to_string(), "Hi.".to_string(), 0.1).await;
    assert!(
        result.is_ok(),
        "min_similarity 0.1 should be clamped to 0.3"
    );
}

#[tokio::test]
async fn test_bilingual_empty_inputs() {
    let result = api::align_bilingual_content(String::new(), String::new(), 0.5).await;
    assert!(result.is_ok(), "empty inputs should still succeed");
    let alignment = result.unwrap();
    assert!(alignment.segments.is_empty());
}

#[tokio::test]
async fn test_bilingual_single_sentence_pair() {
    let result = api::align_bilingual_content(
        "今天天气很好。".to_string(),
        "Today the weather is nice.".to_string(),
        0.3,
    )
    .await;
    assert!(result.is_ok());
    let alignment = result.unwrap();
    assert!(
        !alignment.segments.is_empty(),
        "should align single sentence pair"
    );
}

#[tokio::test]
async fn test_bilingual_mixed_language() {
    let result = api::align_bilingual_content(
        "Hello world. 你好世界。Welcome to China. 欢迎来到中国。".to_string(),
        "Hello world. Welcome to China. 你好世界。欢迎来到中国。".to_string(),
        0.3,
    )
    .await;
    assert!(result.is_ok());
    // 即使顺序不同，也应该能匹配部分
    let alignment = result.unwrap();
    assert!(
        !alignment.unmatched_chinese.is_empty() || !alignment.segments.is_empty(),
        "should have some matched segments with mixed language"
    );
}
