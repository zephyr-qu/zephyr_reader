mod common;

use rust_lib_zephyr_reader::api;
use rust_lib_zephyr_reader::domain::{LanguageType, TypesetConfig};

#[tokio::test]
async fn test_typeset_text_english() {
    let content = "The quick brown fox jumps over the lazy dog.".to_string();
    let config = TypesetConfig {
        language: LanguageType::English,
        ..Default::default()
    };
    let result = api::typeset_text(content.clone(), config).await;
    assert!(
        result.is_ok(),
        "typeset_text should succeed: {:?}",
        result.err()
    );
    let output = result.unwrap();
    assert!(
        output.contains("quick brown fox"),
        "output should contain the original text"
    );
}

#[tokio::test]
async fn test_typeset_text_chinese() {
    let content = "你好世界，这是一个测试。".to_string();
    let config = TypesetConfig::default();
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok(), "typeset_text should succeed for Chinese");
    let output = result.unwrap();
    assert!(!output.is_empty(), "output should not be empty");
}

#[tokio::test]
async fn test_typeset_text_exceeds_max_length() {
    let oversized = "x".repeat(1_000_001);
    let config = TypesetConfig::default();
    let result = api::typeset_text(oversized, config).await;
    assert!(result.is_err(), "should reject oversized input");
    assert_eq!(result.unwrap_err().code(), "INVALID_INPUT");
}

#[tokio::test]
async fn test_typeset_text_empty() {
    let result = api::typeset_text(String::new(), TypesetConfig::default()).await;
    assert!(result.is_ok(), "empty input should still succeed");
}

#[tokio::test]
async fn test_typeset_text_cjk_mixed() {
    let content = "Hello 你好 World 世界".to_string();
    let config = TypesetConfig {
        language: LanguageType::Auto,
        ..Default::default()
    };
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok(), "mixed CJK/Latin should work");
    let output = result.unwrap();
    assert!(!output.is_empty());
}

#[tokio::test]
async fn test_typeset_text_with_line_spacing() {
    let content = "Line one.\nLine two.\nLine three.".to_string();
    let config = TypesetConfig {
        language: LanguageType::English,
        line_spacing: 2.0,
        ..Default::default()
    };
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok(), "custom line spacing should work");
}

#[tokio::test]
async fn test_typeset_text_special_characters() {
    let content = "Special chars: !@#$%^&*()_+{}|:\"<>?".to_string();
    let config = TypesetConfig::default();
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_typeset_text_multiple_paragraphs() {
    let content = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.".to_string();
    let config = TypesetConfig::default();
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok());
    let output = result.unwrap();
    // Should preserve paragraph structure
    assert!(output.contains("First") || output.contains("paragraph"));
}

#[tokio::test]
async fn test_typeset_text_numbers_and_symbols() {
    let content = "Price: $99.99 USD. Version 2.0.5 released on 2024-01-15.".to_string();
    let config = TypesetConfig::default();
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok());
}

#[tokio::test]
async fn test_typeset_text_long_sentence() {
    let long_sentence = "A".repeat(10_000);
    let config = TypesetConfig::default();
    let result = api::typeset_text(long_sentence, config).await;
    assert!(result.is_ok(), "long sentence should be handled");
}

#[tokio::test]
async fn test_typeset_text_word_wrap_test() {
    let content = "This is a longer English sentence that should demonstrate word wrapping behavior in the typesetting engine.".to_string();
    let config = TypesetConfig {
        language: LanguageType::English,
        page_width: 375,
        font_size: 16,
        ..Default::default()
    };
    let result = api::typeset_text(content, config).await;
    assert!(result.is_ok());
}
