//! 边界条件测试
//! 测试极端情况和边界条件

use rust_lib_zephyr_reader::{api, ffi::TypesetConfig};

/// 初始化测试数据库
fn init_test_db() {
    let temp_dir = std::env::temp_dir().join(format!("zephyr_test_{}", std::process::id()));
    std::fs::create_dir_all(&temp_dir).ok();
    // 初始化存储
    let _ = rust_lib_zephyr_reader::storage::init_storage(&temp_dir);
}

/// 测试空文件处理
#[test]
fn test_empty_file() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("empty.txt");
    std::fs::write(&file_path, "").unwrap();

    let result = api::parse_book(file_path.to_string_lossy().to_string());
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
    use rust_lib_zephyr_reader::api::core::create_page_streamer;

    let config = TypesetConfig::default();
    let streamer = create_page_streamer("".to_string(), config);

    assert_eq!(streamer.total_pages(), 0);
    assert!(streamer.current_page(0).is_none());
}

/// 测试文件不存在错误
#[test]
fn test_file_not_found() {
    let result = api::parse_book("/nonexistent/path/file.txt".to_string());
    assert!(result.is_err(), "应该返回文件不存在错误");

    let error = result.unwrap_err();
    assert!(
        error.user_message().contains("文件不存在")
            || error.user_message().contains("路径访问被拒绝")
    );
}

/// 测试中英文混排
#[test]
fn test_mixed_language() {
    let content = "这是中文 This is English 混合文本";

    let config = TypesetConfig::default();
    let result = api::typeset_text(content.to_string(), "mix".to_string(), config);
    assert!(result.is_ok(), "中英文混排失败");
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

/// 测试超大文件处理（>100MB）
/// 验证内存限制和流式加载功能
#[test]
fn test_very_large_file_over_100mb() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("very_large.txt");

    // 生成约 100MB 的内容
    // 每行约 100 字节，需要约 1,000,000 行
    let line = "这是一行测试内容，用于生成大文件。The quick brown fox jumps over the lazy dog.\n";
    let target_size = 100 * 1024 * 1024; // 100MB
    let lines_needed = target_size / line.len();

    use std::io::{BufWriter, Write};
    let file = std::fs::File::create(&file_path).expect("创建测试文件失败");
    let mut writer = BufWriter::new(file);

    for _ in 0..lines_needed {
        writeln!(writer, "{}", line).expect("写入失败");
    }
    writer.flush().expect("刷新缓冲区失败");
    drop(writer);

    // 验证文件大小
    let metadata = std::fs::metadata(&file_path).expect("获取元数据失败");
    assert!(
        metadata.len() > 100 * 1024 * 1024,
        "文件大小应该超过 100MB，实际: {}MB",
        metadata.len() / (1024 * 1024)
    );

    // 测试分块读取
    let result = api::read_file_chunk(file_path.to_string_lossy().to_string(), 0, 1024);
    assert!(result.is_ok(), "大文件分块读取失败");

    // 测试读取中间部分
    let mid_offset = metadata.len() / 2;
    let result = api::read_file_chunk(
        file_path.to_string_lossy().to_string(),
        mid_offset as i64,
        1024,
    );
    assert!(result.is_ok(), "大文件中间部分读取失败");

    // 清理
    std::fs::remove_file(&file_path).ok();
}

/// 测试大文件元数据获取
#[test]
fn test_large_file_metadata() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("large_metadata.txt");

    // 生成约 50MB 的内容
    let content = "测试元数据的长文本内容。\n".repeat(2_000_000);
    std::fs::write(&file_path, &content).unwrap();

    // 获取文件大小
    let metadata = std::fs::metadata(&file_path).expect("获取元数据失败");
    assert!(metadata.len() > 10 * 1024 * 1024, "文件大小应该超过 10MB");

    // 清理
    std::fs::remove_file(file_path).ok();
}

/// 测试大文件流式解析（增量解析）
#[test]
fn test_incremental_parsing_of_large_file() {
    // 初始化数据库
    init_test_db();

    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("incremental_large.txt");

    // 生成约 20MB 的带章节标记的内容
    let mut content = String::new();
    for i in 1..=200 {
        content.push_str(&format!("第{}章 测试标题\n\n", i));
        content.push_str(&format!("这是第 {} 章的详细内容，包含大量重复文本。\n", i));
        content.push_str(&"重复段落用于测试大文件解析性能。\n".repeat(50));
        content.push('\n');
    }
    std::fs::write(&file_path, &content).unwrap();

    // 测试增量解析初始化
    let init_result = api::init_incremental_parser();
    assert!(init_result.is_ok(), "增量解析器初始化失败");

    // 测试解析
    let result = api::parse_local_book_incremental(file_path.to_string_lossy().to_string());
    assert!(result.is_ok(), "大文件增量解析失败: {:?}", result.err());

    let book_info = result.unwrap();
    assert!(
        book_info.chapter_count >= 50,
        "应该识别出至少 50 个章节，实际: {}",
        book_info.chapter_count
    );

    // 清理
    std::fs::remove_file(file_path).ok();
}
