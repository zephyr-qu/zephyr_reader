//! Rust 引擎集成测试
//! 测试核心功能的完整工作流程

use rust_lib_zephyr_reader::{
    api,
    ffi::{LanguageType, TypesetConfig},
};
// use std::sync::Once;

// static INIT: Once = Once::new();

// /// 初始化测试数据库（只执行一次）
// fn init_test_db() {
//     INIT.call_once(|| {
//         let temp_dir = std::env::temp_dir().join(format!("zephyr_test_{}", std::process::id()));
//         std::fs::create_dir_all(&temp_dir).ok();
//         // 初始化存储
//         let _ = rust_lib_zephyr_reader::storage::init_storage(&temp_dir);
//     });
// }

/// 测试 TXT 文件解析完整流程
#[test]
fn test_txt_parse_workflow() {
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

    // 测试解析（使用新的 parse_book API）
    let result = api::parse_book(file_path.to_string_lossy().to_string());

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
    assert_eq!(first_page.chapter_index, 0);
    assert_eq!(first_page.page_index, 0);
    assert!(!first_page.content.is_empty());
}

// /// 测试阅读进度管理
// #[test]
// fn test_reading_progress_workflow() {
//     // 初始化数据库
//     init_test_db();

//     // 使用唯一 ID 避免测试间干扰
//     let book_id = format!(
//         "test_book_{}",
//         std::time::SystemTime::now()
//             .duration_since(std::time::UNIX_EPOCH)
//             .unwrap()
//             .as_millis()
//     );

//     // 先保存书籍（外键约束要求）
//     let book = rust_lib_zephyr_reader::storage::models::DbBookRecord {
//         book_id: book_id.clone(),
//         title: "测试书籍".to_string(),
//         author: "测试作者".to_string(),
//         file_path: "/test/book.txt".to_string(),
//         file_size: 1000,
//         description: None,
//         cover_path: None,
//         chapter_count: 10,
//         total_characters: 50000,
//         format: rust_lib_zephyr_reader::storage::models::DbBookFormat::Txt,
//         added_at: chrono::Local::now(),
//         last_opened_at: None,
//         status: rust_lib_zephyr_reader::storage::models::DbBookStatus::Reading,
//         is_pinned: false,
//         category_ids: vec![],
//         last_read_at: None,
//     };
//     let _ = api::save_book(book);

//     // 保存进度（使用新的 API 签名）
//     let result = api::save_reading_progress(
//         book_id.to_string(),
//         1,   // chapter_index
//         0,   // char_offset
//         5,   // page_index
//         100, // total_pages
//         300, // reading_time_seconds
//     );

//     assert!(result.is_ok(), "保存进度失败：{:?}", result.err());

//     // 获取进度
//     let retrieved = api::get_reading_progress(book_id.to_string()).unwrap();
//     assert!(retrieved.is_some(), "应该能获取到进度");
//     let progress = retrieved.unwrap();
//     assert_eq!(progress.chapter_index, 1);
//     assert_eq!(progress.page_index, 5);
//     assert_eq!(progress.total_pages, 100);

//     // 清除进度
//     let cleared = api::clear_reading_progress(book_id.to_string());
//     assert!(cleared.is_ok(), "清除进度失败: {:?}", cleared.err());

//     // 验证已清除（获取默认进度）
//     let retrieved = api::get_reading_progress(book_id.to_string()).unwrap();
//     assert!(
//         retrieved.is_none() || retrieved.unwrap().chapter_id == 0,
//         "进度应该被清除"
//     );

//     // 清理：删除测试书籍
//     let _ = api::delete_book(book_id.to_string());
// }

// /// 测试书签管理
// #[test]
// fn test_bookmark_workflow() {
//     // 初始化数据库
//     init_test_db();

//     // 使用唯一 ID 避免测试间干扰
//     let book_id = format!(
//         "test_book_{}",
//         std::time::SystemTime::now()
//             .duration_since(std::time::UNIX_EPOCH)
//             .unwrap()
//             .as_millis()
//     );

//     // 先保存书籍（外键约束要求）
//     let book = rust_lib_zephyr_reader::storage::models::BookRecord {
//         book_id: book_id.clone(),
//         title: "测试书籍".to_string(),
//         author: "测试作者".to_string(),
//         file_path: "/test/book.txt".to_string(),
//         file_size: 1000,
//         description: None,
//         cover_path: None,
//         chapter_count: 10,
//         total_characters: 50000,
//         format: rust_lib_zephyr_reader::storage::models::BookFormat::Txt,
//         added_at: chrono::Local::now(),
//         last_opened_at: None,
//         status: rust_lib_zephyr_reader::storage::models::BookStatus::Reading,
//         is_pinned: false,
//         category_ids: vec![],
//         last_read_at: None,
//     };
//     let save_result = api::save_book(book);
//     assert!(save_result.is_ok(), "保存书籍失败：{:?}", save_result.err());

//     // 创建书签（使用新的 API 签名）
//     let result = api::create_bookmark(
//         book_id.to_string(),
//         1,                              // chapter_index
//         100,                            // char_offset
//         Some("重要章节".to_string()),   // title
//         Some("选中的文本".to_string()), // selected_text
//         Some("测试备注".to_string()),   // note
//         None,                           // highlight_color
//     );

//     assert!(result.is_ok(), "创建书签失败：{:?}", result.err());
//     let bookmark = result.unwrap();
//     assert!(!bookmark.bookmark_id.is_empty());
//     assert_eq!(bookmark.book_id, book_id);
//     assert_eq!(bookmark.chapter_id, 1);

//     // 获取书签
//     let bookmarks = api::get_bookmarks(book_id.to_string()).unwrap();
//     assert_eq!(bookmarks.len(), 1, "书签数量异常");

//     // 删除书签（使用新的 API 签名）
//     let removed = api::delete_bookmark(bookmark.bookmark_id.clone());
//     assert!(removed.is_ok(), "删除书签失败: {:?}", removed.err());

//     // 验证已删除
//     let bookmarks = api::get_bookmarks(book_id.to_string()).unwrap();
//     assert!(bookmarks.is_empty(), "书签未被删除");

//     // 清理：删除测试书籍
//     let _ = api::delete_book(book_id.to_string());
// }

// /// 测试文件大小获取
// #[test]
// fn test_file_size() {
//     let temp_dir = std::env::temp_dir();
//     let file_path = temp_dir.join("test_file_size.txt");

//     let content = "Hello, World!";
//     std::fs::write(&file_path, content).expect("Failed to create test file");

//     let size = api::get_file_size(file_path.to_string_lossy().to_string());

//     assert!(size.is_ok(), "获取文件大小失败：{:?}", size.err());
//     assert_eq!(size.unwrap(), content.len() as i64);

//     // 清理
//     std::fs::remove_file(file_path).ok();
// }

// /// 测试文件分块读取
// #[test]
// fn test_chunk_read() {
//     let temp_dir = std::env::temp_dir();
//     let file_path = temp_dir.join("test_chunk_read.txt");

//     let content = "Hello, World! This is a test file for chunk reading.";
//     std::fs::write(&file_path, content).expect("Failed to create test file");

//     // 读取第一块
//     let chunk1 = api::read_file_chunk(file_path.to_string_lossy().to_string(), 0, 5);

//     assert!(chunk1.is_ok(), "读取文件块失败：{:?}", chunk1.err());
//     assert_eq!(chunk1.unwrap(), "Hello");

//     // 读取第二块
//     let chunk2 = api::read_file_chunk(file_path.to_string_lossy().to_string(), 7, 5);

//     assert!(chunk2.is_ok(), "读取文件块失败：{:?}", chunk2.err());
//     assert_eq!(chunk2.unwrap(), "World");

//     // 清理
//     std::fs::remove_file(file_path).ok();
// }
