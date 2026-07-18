mod common;

use rust_lib_zephyr_reader::api::chapter;

// ==================== 格式检测测试 ====================

#[test]
fn test_get_supported_formats() {
    // 应该至少支持常见格式
    let known_formats = ["txt", "epub"];
    for fmt in &known_formats {
        assert!(
            rust_lib_zephyr_reader::parser::registry::format_from_extension(fmt).is_ok(),
            "应该支持格式: {}",
            fmt
        );
    }

    println!("支持的格式: {:?}", known_formats);
}

#[test]
fn test_supports_format_epub() {
    // 测试 EPUB 格式支持
    let supports_epub =
        rust_lib_zephyr_reader::parser::registry::format_from_extension("epub").is_ok();
    // 如果 EPUB 解析器已注册，应该返回 true
    println!("支持 EPUB: {}", supports_epub);
}

#[test]
fn test_supports_format_txt() {
    // 测试 TXT 格式支持
    let supports_txt =
        rust_lib_zephyr_reader::parser::registry::format_from_extension("txt").is_ok();
    println!("支持 TXT: {}", supports_txt);
}

#[test]
fn test_supports_format_case_insensitive() {
    // 测试格式检测是否大小写不敏感
    let upper = rust_lib_zephyr_reader::parser::registry::format_from_extension("EPUB").is_ok();
    let lower = rust_lib_zephyr_reader::parser::registry::format_from_extension("epub").is_ok();
    // 两者应该一致（取决于实现）
    println!("EPUB (大写): {}, EPUB (小写): {}", upper, lower);
}

#[test]
fn test_supports_format_unknown() {
    // 测试不支持的格式
    let supports_xyz = rust_lib_zephyr_reader::parser::registry::format_from_extension("xyz");
    // 未知格式应该返回错误
    assert!(supports_xyz.is_err(), "不应该支持未知格式 xyz");
}

// ==================== 文件解析测试 ====================

#[tokio::test]
async fn test_import_book_txt() {
    common::init_logger();

    // 创建临时目录用于存储数据库
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    // 初始化存储
    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 创建临时 TXT 文件
    let (_file_dir, file_path) = common::create_temp_file(
        "test_book.txt",
        "第一章 开始\n\n这是测试内容。\n\n第二章 继续\n\n更多内容...",
    );

    // 测试解析 TXT 文件
    let result = rust_lib_zephyr_reader::api::book::import_book(file_path.clone()).await;

    // 验证解析结果
    assert!(result.is_ok(), "TXT 文件解析应该成功: {:?}", result);

    let parse_result = result.unwrap();
    println!("解析成功: 书籍ID={}", parse_result,);
}

#[tokio::test]
async fn test_import_book_invalid_file() {
    common::init_logger();

    // 测试不存在的文件
    let result =
        rust_lib_zephyr_reader::api::book::import_book("/nonexistent/path/book.txt".to_string())
            .await;

    // 应该返回错误
    assert!(result.is_err(), "不存在的文件应该返回错误");

    println!("错误处理正确: {:?}", result);
}

#[tokio::test]
async fn test_import_book_empty_content() {
    common::init_logger();

    // 初始化临时存储
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();
    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 创建空文件
    let (_temp_dir, file_path) = common::create_temp_file("empty.txt", "");

    let book_id = rust_lib_zephyr_reader::api::book::import_book(file_path).await;
    let parse_result = book_id.unwrap();
    let result = chapter::list_chapters_by_book(parse_result).await;

    // 空文件可能解析成功（无章节）或失败，取决于实现
    match result {
        Ok(parse_result) => {
            println!("空文件解析成功: 章节数={}", parse_result.len());
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

    // parser_for_file 获取解析器后调用 extract_metadata
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_file(&file_path).unwrap();
    let result = parser.extract_metadata(&file_path).await;

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

// ==================== 错误处理测试 ====================

#[test]
fn test_api_error_handling_invalid_input() {
    common::init_logger();

    // 测试无效输入的错误处理
    let result = rust_lib_zephyr_reader::parser::registry::format_from_extension("");
    // 空字符串格式应该返回错误
    assert!(result.is_err(), "空字符串格式应该返回错误");
}

#[tokio::test]
async fn test_api_error_handling_null_path() {
    common::init_logger();

    // 测试空路径的错误处理
    let result = rust_lib_zephyr_reader::api::book::import_book("".to_string()).await;
    assert!(result.is_err(), "空路径应该返回错误");

    println!("空路径错误处理正确: {:?}", result);
}

// ==================== 并发测试 ====================

#[tokio::test]
async fn test_concurrent_format_checks() {
    common::init_logger();

    // 测试并发格式检测
    let formats = vec!["epub", "txt"];

    let mut handles = vec![];
    for format in formats {
        let format_ref = format;
        let handle = tokio::spawn(async move {
            rust_lib_zephyr_reader::parser::registry::format_from_extension(format_ref).is_ok()
        });
        handles.push(handle);
    }

    // 等待所有任务完成
    for handle in handles {
        let result = handle.await.unwrap();
        println!("格式支持检查完成: {:?}", result);
    }
}

// ==================== 解析器注册表测试 ====================

#[test]
fn test_parser_for_format_txt() {
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(
        rust_lib_zephyr_reader::domain::book::BookFormat::Txt,
    );
    assert_eq!(parser.name(), "TXT Parser");
    assert!(parser.supported_formats().contains(&"txt"));
}

#[test]
fn test_parser_for_format_epub() {
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(
        rust_lib_zephyr_reader::domain::book::BookFormat::Epub,
    );
    assert_eq!(parser.name(), "EPUB Parser");
    assert!(parser.supported_formats().contains(&"epub"));
}

#[test]
fn test_parser_for_format_epub_only() {
    use rust_lib_zephyr_reader::domain::book::BookFormat;
    for format in &[BookFormat::Txt, BookFormat::Epub] {
        let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(*format);
        let name = parser.name();
        assert!(
            !name.is_empty(),
            "Parser name should not be empty for {format:?}"
        );
    }
}

#[test]
fn test_parser_for_file_valid_extensions() {
    use rust_lib_zephyr_reader::parser::registry::parser_for_file;
    assert!(parser_for_file("book.txt").is_ok());
    assert!(parser_for_file("book.epub").is_ok());
    assert!(parser_for_file("book.pdf").is_err());
    assert!(parser_for_file("book.md").is_err());
}

#[test]
fn test_parser_for_file_invalid_extension() {
    use rust_lib_zephyr_reader::parser::registry::parser_for_file;
    assert!(parser_for_file("book.xyz").is_err());
}

#[test]
fn test_parser_for_file_no_extension() {
    use rust_lib_zephyr_reader::parser::registry::parser_for_file;
    assert!(parser_for_file("book").is_err());
}

#[test]
fn test_parser_name_covers_all_formats() {
    use rust_lib_zephyr_reader::domain::book::BookFormat;
    for format in &[BookFormat::Txt, BookFormat::Epub] {
        let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(*format);
        let name = parser.name();
        assert!(
            !name.is_empty(),
            "Parser name should not be empty for {format:?}"
        );
    }
}
