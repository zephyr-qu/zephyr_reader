//! Rust 引擎集成测试
//! 测试核心功能的完整工作流程

mod common;

use rust_lib_zephyr_reader::{
    api,
    ffi::{LanguageType, TypesetConfig},
};

/// 初始化测试数据库
fn init_test_db() {
    let temp_dir = std::env::temp_dir();
    let db_path = temp_dir.join(format!("zephyr_test_{}.db", std::process::id()));
    let _ = api::init_storage(db_path.to_string_lossy().to_string());
}

/// 测试 TXT 文件解析完整流程
#[test]
fn test_txt_parse_workflow() {
    // 初始化数据库
    init_test_db();
    // 创建临时测试文件
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("test_txt_parse.txt");

    let content = r#"第一章 开始
这是第一章的内容，测试文本解析功能。

第二章 发展
这是第二章的内容，测试章节提取功能。

第三章 结局
这是第三章的内容，测试完整流程。
"#;

    std::fs::write(&file_path, content).expect("Failed to create test file");

    // 测试解析
    let result = api::parse_txt_file(file_path.to_string_lossy().to_string());

    // 验证结果
    assert!(result.is_ok(), "TXT 解析失败：{:?}", result.err());

    let parse_result = result.unwrap();
    assert_eq!(parse_result.book_info.file_type, "txt");
    assert!(parse_result.chapters.len() >= 1, "章节提取失败");

    // 清理测试文件
    std::fs::remove_file(file_path).ok();
}

/// 测试排版功能
#[test]
fn test_typeset_workflow() {
    let content = "这是一段测试文本，用于验证排版功能。包含中文和 English 混合内容。";

    let config = TypesetConfig {
        page_width: 400,
        page_height: 600,
        font_size: 18,
        line_spacing: 1.5,
        letter_spacing: 0.0,
        paragraph_spacing: 1.0,
        first_line_indent: 2,
        language: LanguageType::Auto,
        enable_hyphenation: false,
        hyphenation_language: None,
    };

    let result = api::typeset_text(content.to_string(), "auto".to_string(), config);

    assert!(result.is_ok(), "排版处理失败：{:?}", result.err());

    let typeset_content = result.unwrap();
    assert!(!typeset_content.is_empty(), "排版结果为空");
}

/// 测试分页功能
#[test]
fn test_pagination_workflow() {
    let content = "第一行\n第二行\n第三行\n第四行\n第五行\n第六行\n第七行\n第八行\n第九行\n第十行";

    let config = TypesetConfig {
        page_width: 400,
        page_height: 300,
        font_size: 16,
        line_spacing: 1.5,
        letter_spacing: 0.0,
        paragraph_spacing: 1.0,
        first_line_indent: 2,
        language: LanguageType::Auto,
        enable_hyphenation: false,
        hyphenation_language: None,
    };

    let pages = api::paginate_all_content(content.to_string(), 0, config);

    assert!(!pages.is_empty(), "分页结果为空");
    assert!(pages.len() >= 1, "分页数量异常");

    // 验证第一页
    let first_page = &pages[0];
    assert_eq!(first_page.chapter_id, 0);
    assert_eq!(first_page.page_index, 0);
    assert!(!first_page.content.is_empty());
}

/// 测试阅读进度管理
#[test]
fn test_reading_progress_workflow() {
    // 初始化数据库
    init_test_db();

    // 使用唯一 ID 避免测试间干扰
    let book_id = format!("test_book_{:?}", std::time::SystemTime::now());

    // 更新进度
    let progress = api::update_reading_progress(
        book_id.to_string(),
        1,   // chapter_id
        5,   // page_index
        100, // total_pages
    );

    assert_eq!(progress.chapter_id, 1);
    assert_eq!(progress.page_index, 5);
    assert_eq!(progress.total_pages, 100);
    assert!((progress.progress - 0.06).abs() < 0.01); // 6% 进度

    // 获取进度
    let retrieved = api::get_reading_progress(book_id.to_string());
    assert_eq!(retrieved.chapter_id, 1);

    // 清除进度
    let cleared = api::clear_reading_progress(book_id.to_string());
    // clear 返回是否删除了记录
    assert!(cleared, "清除进度失败");

    // 验证已清除（获取默认进度）
    let retrieved = api::get_reading_progress(book_id.to_string());
    // 清除后应该是默认值（chapter_id = 0）
    assert_eq!(retrieved.chapter_id, 0);
}

/// 测试书签管理
#[test]
fn test_bookmark_workflow() {
    // 初始化数据库
    init_test_db();

    // 使用唯一 ID 避免测试间干扰
    let book_id = format!("test_book_{:?}", std::time::SystemTime::now());

    // 添加书签
    let bookmark = api::add_bookmark(
        book_id.to_string(),
        1,  // chapter_id
        10, // page_index
        "重要章节".to_string(),
        Some("测试备注".to_string()),
    );

    assert!(!bookmark.bookmark_id.is_empty());
    assert_eq!(bookmark.book_id, book_id);
    assert_eq!(bookmark.chapter_id, 1);
    assert_eq!(bookmark.page_index, 10);

    // 获取书签
    let bookmarks = api::get_bookmarks(book_id.to_string());
    assert_eq!(bookmarks.len(), 1, "书签数量异常");

    // 删除书签
    let removed = api::remove_bookmark(book_id.to_string(), bookmark.bookmark_id.clone());
    assert!(removed, "删除书签失败");

    // 验证已删除
    let bookmarks = api::get_bookmarks(book_id.to_string());
    // 删除后应该为空
    assert!(bookmarks.is_empty(), "书签未被删除");
}

/// 测试文件大小获取
#[test]
fn test_file_size() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("test_file_size.txt");

    let content = "Hello, World!";
    std::fs::write(&file_path, content).expect("Failed to create test file");

    let size = api::get_file_size(file_path.to_string_lossy().to_string());

    assert!(size.is_ok(), "获取文件大小失败：{:?}", size.err());
    assert_eq!(size.unwrap(), content.len() as i64);

    // 清理
    std::fs::remove_file(file_path).ok();
}

/// 测试文件分块读取
#[test]
fn test_chunk_read() {
    let temp_dir = std::env::temp_dir();
    let file_path = temp_dir.join("test_chunk_read.txt");

    let content = "Hello, World! This is a test file for chunk reading.";
    std::fs::write(&file_path, content).expect("Failed to create test file");

    // 读取第一块
    let chunk1 = api::read_file_chunk(file_path.to_string_lossy().to_string(), 0, 5);

    assert!(chunk1.is_ok(), "读取文件块失败：{:?}", chunk1.err());
    assert_eq!(chunk1.unwrap(), "Hello");

    // 读取第二块
    let chunk2 = api::read_file_chunk(file_path.to_string_lossy().to_string(), 7, 5);

    assert!(chunk2.is_ok(), "读取文件块失败：{:?}", chunk2.err());
    assert_eq!(chunk2.unwrap(), "World");

    // 清理
    std::fs::remove_file(file_path).ok();
}
