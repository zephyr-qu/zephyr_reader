mod common;

// ==================== 格式检测测试 ====================

#[test]
fn test_get_supported_formats() {
    // 单引擎（EPUB only）决策：仅 EPUB 受支持
    let known_formats = ["epub"];
    for fmt in &known_formats {
        assert!(
            rust_lib_zephyr_reader::parser::registry::format_from_extension(fmt).is_ok(),
            "应该支持格式: {}",
            fmt
        );
    }
    // TXT 已下线
    assert!(
        rust_lib_zephyr_reader::parser::registry::format_from_extension("txt").is_err(),
        "TXT 不应受支持"
    );
    println!("支持的格式: {:?}", known_formats);
}

#[test]
fn test_supports_format_epub() {
    // 测试 EPUB 格式支持
    let supports_epub =
        rust_lib_zephyr_reader::parser::registry::format_from_extension("epub").is_ok();
    println!("支持 EPUB: {}", supports_epub);
}

#[test]
fn test_supports_format_txt_rejected() {
    // 单引擎决策：TXT 解析已下线，应返回错误
    let supports_txt =
        rust_lib_zephyr_reader::parser::registry::format_from_extension("txt").is_ok();
    assert!(!supports_txt, "TXT 不应受支持");
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

/// 在临时目录中构建一个最小合法 EPUB 文件，返回文件路径。
fn build_minimal_epub(dir: &std::path::Path) -> String {
    use std::io::Write;
    use zip::write::SimpleFileOptions;
    use zip::ZipWriter;

    let out_path = dir.join("minimal.epub");
    let out_file = std::fs::File::create(&out_path).unwrap();
    let mut out_zip = ZipWriter::new(out_file);

    let stored = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Stored)
        .unix_permissions(0o644);
    let deflated = SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o644);

    // mimetype 必须为存储格式且为第一个条目
    out_zip.start_file("mimetype", stored).unwrap();
    out_zip.write_all(b"application/epub+zip").unwrap();

    out_zip
        .start_file("META-INF/container.xml", deflated)
        .unwrap();
    out_zip
        .write_all(
            br#"<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#,
        )
        .unwrap();

    out_zip.start_file("OEBPS/content.opf", deflated).unwrap();
    out_zip
        .write_all(
            br#"<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">test-minimal</dc:identifier>
    <dc:title>Minimal Test EPUB</dc:title>
    <dc:language>zh</dc:language>
  </metadata>
  <manifest>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
  </spine>
</package>"#,
        )
        .unwrap();

    out_zip.start_file("OEBPS/ch1.xhtml", deflated).unwrap();
    out_zip
        .write_all(
            br#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body><h1>Chapter 1</h1><p>This is test content.</p></body>
</html>"#,
        )
        .unwrap();

    out_zip.finish().unwrap();
    out_path.to_string_lossy().to_string()
}

#[tokio::test]
async fn test_import_book_epub() {
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    // 初始化存储
    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 构建最小 EPUB 并导入
    let file_path = build_minimal_epub(temp_dir.path());
    let result = rust_lib_zephyr_reader::api::book::import_book(file_path.clone()).await;

    assert!(result.is_ok(), "EPUB 文件解析应该成功: {:?}", result);
    let book_id = result.unwrap();
    println!("解析成功: 书籍ID={}", book_id);

    // 章节应可读取
    let detail = rust_lib_zephyr_reader::api::book::get_book_detail(book_id.clone())
        .await
        .expect("get_book_detail should succeed");
    assert_eq!(detail.chapters.len(), 1, "EPUB 应解析出 1 个章节");
}

#[tokio::test]
async fn test_import_book_txt_rejected() {
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 创建临时 TXT 文件 —— 单引擎决策下应被拒绝
    let (_file_dir, file_path) = common::create_temp_file(
        "test_book.txt",
        "第一章 开始\n\n这是测试内容。\n\n第二章 继续\n\n更多内容...",
    );

    let result = rust_lib_zephyr_reader::api::book::import_book(file_path.clone()).await;
    assert!(result.is_err(), "TXT 文件应被拒绝: {:?}", result);
}

#[tokio::test]
async fn test_import_book_invalid_file() {
    // 测试不存在的文件
    let result =
        rust_lib_zephyr_reader::api::book::import_book("/nonexistent/path/book.epub".to_string())
            .await;

    // 应该返回错误
    assert!(result.is_err(), "不存在的文件应该返回错误");

    println!("错误处理正确: {:?}", result);
}

#[tokio::test]
async fn test_import_book_empty_content() {
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();
    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir.clone()).await {
        println!("存储初始化失败（可接受）: {:?}", e);
    }

    // 空文件不是合法 EPUB，应返回错误
    let (_temp_dir, file_path) = common::create_temp_file("empty.epub", "");
    let result = rust_lib_zephyr_reader::api::book::import_book(file_path).await;
    assert!(result.is_err(), "空文件应解析失败");
}

// ==================== 错误处理测试 ====================

#[test]
fn test_api_error_handling_invalid_input() {
    // 测试无效输入的错误处理
    let result = rust_lib_zephyr_reader::parser::registry::format_from_extension("");
    // 空字符串格式应该返回错误
    assert!(result.is_err(), "空字符串格式应该返回错误");
}

#[tokio::test]
async fn test_api_error_handling_null_path() {
    // 测试空路径的错误处理
    let result = rust_lib_zephyr_reader::api::book::import_book("".to_string()).await;
    assert!(result.is_err(), "空路径应该返回错误");

    println!("空路径错误处理正确: {:?}", result);
}

// ==================== 并发测试 ====================

#[tokio::test]
async fn test_concurrent_format_checks() {
    // 测试并发格式检测
    let formats = vec!["epub"];

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
fn test_parser_for_format_epub() {
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(
        rust_lib_zephyr_reader::domain::book::BookFormat::Epub,
    )
    .expect("EPUB parser should be available");
    assert_eq!(parser.name(), "EPUB Parser");
    assert!(parser.supported_formats().contains(&"epub"));
}

#[test]
fn test_parser_for_format_txt_rejected() {
    let result = rust_lib_zephyr_reader::parser::registry::parser_for_format(
        rust_lib_zephyr_reader::domain::book::BookFormat::Txt,
    );
    assert!(result.is_err(), "TXT 不应有解析器");
}

#[test]
fn test_parser_for_format_epub_only() {
    use rust_lib_zephyr_reader::domain::book::BookFormat;
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(BookFormat::Epub)
        .expect("EPUB parser should be available");
    assert!(!parser.name().is_empty());
}

#[test]
fn test_parser_for_file_valid_extensions() {
    use rust_lib_zephyr_reader::parser::registry::parser_for_file;
    assert!(parser_for_file("book.epub").is_ok());
    assert!(parser_for_file("book.txt").is_err(), "TXT 应被拒绝");
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
fn test_parser_name_epub() {
    use rust_lib_zephyr_reader::domain::book::BookFormat;
    let parser = rust_lib_zephyr_reader::parser::registry::parser_for_format(BookFormat::Epub)
        .expect("EPUB parser should be available");
    assert!(!parser.name().is_empty());
}

// ==================== 最近阅读（last_opened_at）测试 ====================

#[tokio::test]
async fn test_touch_book_updates_recent_list() {
    use rust_lib_zephyr_reader::api::book;

    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("touch-book-a").await;
    common::ensure_test_book("touch-book-b").await;

    // 未 touch 前：最近阅读应为空（last_opened_at 全 NULL）
    let empty = book::list_recently_opened_books(10).await.unwrap();
    assert!(empty.is_empty(), "未打开过任何书时最近阅读应为空");

    // 依次打开：touch a → touch b → 书架按最近阅读排序应 b 在前
    book::touch_book("touch-book-a".to_string()).await.unwrap();
    tokio::time::sleep(std::time::Duration::from_millis(5)).await;
    book::touch_book("touch-book-b".to_string()).await.unwrap();

    let recent = book::list_bookshelf_books(
        None,
        None,
        Some("last_opened_at".to_string()),
        Some("desc".to_string()),
    )
    .await
    .unwrap();
    let a_pos = recent.iter().position(|b| b.book_id == "touch-book-a");
    let b_pos = recent.iter().position(|b| b.book_id == "touch-book-b");
    assert!(a_pos.is_some() && b_pos.is_some(), "两本书都应出现在书架");
    assert!(b_pos.unwrap() < a_pos.unwrap(), "后打开的应排最前");
}
