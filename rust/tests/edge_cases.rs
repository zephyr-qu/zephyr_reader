//! 边界条件测试
//! 测试极端情况和边界条件

use rust_lib_zephyr_reader::{api, ffi::TypesetConfig};

/// 测试空文件处理
#[test]
fn test_empty_file() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("empty.txt");
    std::fs::write(&file_path, "").unwrap();

    let result = api::parse_txt_file(file_path.to_string_lossy().to_string());
    assert!(result.is_ok(), "空文件解析应该成功");

    let parse_result = result.unwrap();
    assert_eq!(parse_result.book_info.total_characters, 0);

    std::fs::remove_file(file_path).ok();
}

/// 测试大文件处理（10MB）
#[test]
fn test_large_file() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("large.txt");

    let content = "测试内容\n".repeat(600_000);
    std::fs::write(&file_path, &content).unwrap();

    let result = api::read_file_chunk(file_path.to_string_lossy().to_string(), 0, 1024);
    assert!(result.is_ok(), "大文件读取失败");

    std::fs::remove_file(file_path).ok();
}

/// 测试特殊字符处理
#[test]
fn test_special_characters() {
    let content = "特殊字符测试：\u{0000}\u{FFFF}\u{1F600}";

    let config = TypesetConfig::default();
    let result = api::typeset_text(content.to_string(), "zh".to_string(), config);
    assert!(result.is_ok(), "特殊字符排版失败");
}

/// 测试超长单行文本
#[test]
fn test_very_long_line() {
    let content = "A".repeat(10000);

    let config = TypesetConfig {
        page_width: 400,
        page_height: 600,
        font_size: 18,
        ..Default::default()
    };

    let result = api::typeset_text(content, "zh".to_string(), config);
    assert!(result.is_ok(), "超长行排版失败");
}

/// 测试无效配置自动修复
#[test]
fn test_invalid_config_fix() {
    let config = TypesetConfig {
        font_size: 200,
        page_width: 50,
        line_spacing: 10.0,
        ..Default::default()
    };

    assert!(config.validate().is_err());

    let fixed = config.validate_and_fix();

    assert_eq!(fixed.font_size, 100);
    assert_eq!(fixed.page_width, 100);
    assert_eq!(fixed.line_spacing, 5.0);
}

/// 测试空配置
#[test]
fn test_default_config() {
    let config = TypesetConfig::default();
    assert!(config.validate().is_ok(), "默认配置应该有效");
}

/// 测试分页器空内容
#[test]
fn test_empty_page_streamer() {
    let config = TypesetConfig::default();
    let streamer = api::create_page_streamer("".to_string(), config);

    assert_eq!(streamer.total_pages(), 0);
    assert!(streamer.current_page(0).is_none());
}

/// 测试文件不存在错误
#[test]
fn test_file_not_found() {
    let result = api::parse_txt_file("/nonexistent/path/file.txt".to_string());
    assert!(result.is_err(), "应该返回文件不存在错误");

    let error = result.unwrap_err();
    assert!(error.user_message().contains("文件不存在"));
}

/// 测试中英文混排
#[test]
fn test_mixed_language() {
    let content = "这是中文 This is English 混合文本";

    let config = TypesetConfig::default();
    let result = api::typeset_text(content.to_string(), "mix".to_string(), config);
    assert!(result.is_ok(), "中英文混排失败");
}

/// 测试配置哈希一致性
#[test]
fn test_config_hash_consistency() {
    let config1 = TypesetConfig::default();
    let config2 = TypesetConfig::default();

    let hash1 = api::compute_config_hash(config1.clone());
    let hash2 = api::compute_config_hash(config2.clone());

    assert_eq!(hash1, hash2, "相同配置的哈希值应该一致");

    let config3 = TypesetConfig {
        font_size: 20,
        ..Default::default()
    };
    let hash3 = api::compute_config_hash(config3);
    assert_ne!(hash1, hash3, "不同配置的哈希值应该不同");
}

/// 测试纯英文内容
#[test]
fn test_english_only() {
    let content = "This is a test of the emergency broadcast system.";

    let config = TypesetConfig::default();
    let result = api::typeset_text(content.to_string(), "en".to_string(), config);
    assert!(result.is_ok(), "纯英文排版失败");
}

/// 测试并发排版（多段落）
#[test]
fn test_parallel_typeset() {
    let mut content = String::new();
    for i in 0..20 {
        content.push_str(&format!("这是第 {} 段测试文本。\n\n", i));
    }

    let config = TypesetConfig::default();
    let result = api::typeset_text(content, "zh".to_string(), config);
    assert!(result.is_ok(), "多段落排版失败");
}
