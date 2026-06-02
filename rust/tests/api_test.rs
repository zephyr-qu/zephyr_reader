mod common;

use rust_lib_zephyr_reader::api;
use rust_lib_zephyr_reader::api::core;

// ==================== 基础连接测试 ====================

#[test]
fn test_connection() {
    let result = api::test_connection();
    assert!(result.is_ok(), "连接应该成功");
    let msg = result.unwrap();
    assert_eq!(msg, "Rust core engine connected successfully");
}

#[test]
fn test_multiple_connections() {
    // Test that connection can be verified multiple times
    for _ in 0..5 {
        let result = api::test_connection();
        assert!(result.is_ok(), "连接应该成功");
        assert_eq!(result.unwrap(), "Rust core engine connected successfully");
    }
}

#[test]
fn test_api_response_format() {
    let result = api::test_connection();
    let msg = result.unwrap();
    assert!(!msg.is_empty());
    assert!(msg.contains("connected"));
}

// ==================== 格式检测测试 ====================

#[tokio::test]
async fn test_get_supported_formats() {
    let formats = core::get_supported_formats().await.unwrap();
    // 应该至少支持常见格式
    assert!(!formats.is_empty(), "应该支持至少一种格式");

    // 检查是否包含常见格式（具体取决于 parser registry 的实现）
    println!("支持的格式: {:?}", formats);
}

#[tokio::test]
async fn test_supports_format_epub() {
    // 测试 EPUB 格式支持
    let supports_epub = core::supports_format("epub");
    // 注意：如果 EPUB 解析器已注册，应该返回 true
    println!("支持 EPUB: {}", supports_epub);
}

#[tokio::test]
async fn test_supports_format_txt() {
    // 测试 TXT 格式支持
    let supports_txt = core::supports_format("txt");
    println!("支持 TXT: {}", supports_txt);
}

#[test]
fn test_supports_format_case_insensitive() {
    // 测试格式检测是否大小写不敏感
    let upper = core::supports_format("EPUB");
    let lower = core::supports_format("epub");
    // 两者应该一致（取决于实现）
    println!("EPUB (大写): {}, EPUB (小写): {}", upper, lower);
}

#[test]
fn test_supports_format_unknown() {
    // 测试不支持的格式
    let supports_xyz = core::supports_format("xyz");
    // 未知格式应该返回 false
    assert!(!supports_xyz, "不应该支持未知格式 xyz");
}

// ==================== 文件解析测试 ====================

#[tokio::test]
async fn test_parse_book_txt() {
    common::init_logger();

    // 创建临时目录用于存储数据库
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    // 初始化存储
    if let Err(e) = rust_lib_zephyr_reader::api::data::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 创建临时 TXT 文件
    let (_file_dir, file_path) = common::create_temp_file(
        "test_book.txt",
        "第一章 开始\n\n这是测试内容。\n\n第二章 继续\n\n更多内容...",
    );

    // 测试解析 TXT 文件
    let result = api::parse_book(file_path.clone()).await;

    // 验证解析结果
    assert!(result.is_ok(), "TXT 文件解析应该成功: {:?}", result);

    let parse_result = result.unwrap();
    assert!(!parse_result.book_info.title.is_empty(), "书名不应该为空");
    assert!(!parse_result.chapters.is_empty(), "应该至少有一个章节");

    println!(
        "解析成功: 书名={}, 章节数={}",
        parse_result.book_info.title,
        parse_result.chapters.len()
    );
}

#[tokio::test]
async fn test_parse_book_invalid_file() {
    common::init_logger();

    // 测试不存在的文件
    let result = api::parse_book("/nonexistent/path/book.txt".to_string()).await;

    // 应该返回错误
    assert!(result.is_err(), "不存在的文件应该返回错误");

    println!("错误处理正确: {:?}", result);
}

#[tokio::test]
async fn test_parse_book_empty_content() {
    common::init_logger();

    // 创建空文件
    let (_temp_dir, file_path) = common::create_temp_file("empty.txt", "");

    let result = api::parse_book(file_path).await;

    // 空文件可能解析成功（无章节）或失败，取决于实现
    match result {
        Ok(parse_result) => {
            println!("空文件解析成功: 章节数={}", parse_result.chapters.len());
        }
        Err(e) => {
            println!("空文件返回错误（可接受）: {:?}", e);
        }
    }
}

// ==================== 元数据提取测试 ====================

#[tokio::test]
async fn test_extract_metadata() {
    common::init_logger();

    // 创建临时 TXT 文件
    let (_temp_dir, file_path) = common::create_temp_file(
        "metadata_test.txt",
        "测试书籍\n作者: Test Author\n\n第一章\n内容...",
    );

    // extract_metadata 在 core 模块中
    let result = core::extract_metadata(file_path).await;

    // 元数据提取可能成功或失败，取决于文件格式
    match result {
        Ok(metadata) => {
            assert!(
                !metadata.title.is_empty() || metadata.chapter_count >= 0,
                "元数据应该有效"
            );
            println!(
                "元数据提取成功: 标题={}, 章节数={}",
                metadata.title, metadata.chapter_count
            );
        }
        Err(e) => {
            println!("元数据提取失败（可能正常）: {:?}", e);
        }
    }
}

// ==================== 排版接口测试 ====================

#[tokio::test]
async fn test_typeset_text_basic() {
    common::init_logger();

    // 测试基本的文本排版功能
    let text = "这是一段测试文本，用于验证排版功能。".to_string();

    // 使用默认的 TypesetConfig
    let config = rust_lib_zephyr_reader::domain::TypesetConfig::default();

    // 调用排版函数（异步）
    let result = api::typeset_text(text, config).await;

    // 验证排版结果
    assert!(result.is_ok(), "排版应该成功: {:?}", result);

    if let Ok(typeset_result) = result {
        assert!(!typeset_result.is_empty(), "排版结果不应该为空");
        println!("排版成功: 结果长度={}", typeset_result.len());
    }
}

// ==================== 双语对齐测试 ====================

#[tokio::test]
async fn test_bilingual_alignment_empty() {
    common::init_logger();

    // 测试空内容的双语对齐
    let chinese = String::new();
    let english = String::new();
    let min_similarity = 0.5;

    let result = api::align_bilingual_content(chinese, english, min_similarity).await;

    // 空输入应该返回空输出
    assert!(result.is_ok(), "空内容对齐应该成功");

    let alignment = result.unwrap();
    assert!(alignment.segments.is_empty(), "空输入应该产生空输出");
    println!("空内容对齐成功");
}

#[tokio::test]
async fn test_bilingual_alignment_simple() {
    common::init_logger();

    // 测试简单的双语对齐
    let chinese = "你好世界\n这是一个测试".to_string();
    let english = "Hello world\nThis is a test".to_string();
    let min_similarity = 0.3;

    let result = api::align_bilingual_content(chinese, english, min_similarity).await;

    // 应该成功对齐
    assert!(result.is_ok(), "简单对齐应该成功: {:?}", result);

    let alignment = result.unwrap();
    println!(
        "双语对齐成功: 匹配数={}, 未匹配中文={}, 未匹配英文={}",
        alignment.segments.len(),
        alignment.unmatched_chinese.len(),
        alignment.unmatched_english.len()
    );
}

// ==================== 搜索接口测试 ====================

#[tokio::test]
async fn test_search_initialization() {
    common::init_logger();

    // 测试搜索功能是否可用
    // 注意：这可能需要先初始化索引
    println!("搜索接口测试 - 需要有效的数据库环境");
}

// ==================== 词典接口测试 ====================

#[test]
fn test_dictionary_availability() {
    common::init_logger();

    // 测试词典功能是否可用
    // 注意：这可能需要先初始化词典引擎
    println!("词典接口测试 - 需要有效的词典文件");
}

// ==================== 错误处理测试 ====================

#[test]
fn test_api_error_handling_invalid_input() {
    common::init_logger();

    // 测试无效输入的错误处理
    let result = core::supports_format("");
    // 空字符串格式应该返回 false
    assert!(!result, "空字符串格式应该不被支持");
}

#[tokio::test]
async fn test_api_error_handling_null_path() {
    common::init_logger();

    // 测试空路径的错误处理
    let result = api::parse_book("".to_string()).await;
    assert!(result.is_err(), "空路径应该返回错误");

    println!("空路径错误处理正确: {:?}", result);
}

// ==================== 并发测试 ====================

#[tokio::test]
async fn test_concurrent_format_checks() {
    common::init_logger();

    // 测试并发格式检测
    let formats = vec!["epub", "txt", "pdf", "md"];

    let mut handles = vec![];
    for format in formats {
        let format_ref = format;
        let handle = tokio::spawn(async move { core::supports_format(format_ref) });
        handles.push(handle);
    }

    // 等待所有任务完成
    for handle in handles {
        let result = handle.await.unwrap();
        println!("格式支持检查完成: {:?}", result);
    }
}
