//! PDF 文件解析主逻辑
//! 负责整合元数据提取、文本解析、图像提取等功能

use std::path::Path;
use uuid::Uuid;

use super::metadata::extract_metadata_from_path;
use super::text::estimate_total_chars;
use crate::api::security::validate_file_path;
use crate::ffi::{ApiResult, BookInfo, ChapterInfo, ParseResult, ParserError};

/// 默认每章包含的页数
const DEFAULT_PAGES_PER_CHAPTER: usize = 10;

/// 解析 PDF 文件
///
/// 读取并解析 PDF 文件，提取书籍信息、元数据和章节列表。
/// PDF 章节按页数划分，每 10 页为一章（可配置）。
///
/// # 参数
///
/// * `file_path` - PDF 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
pub fn parse_pdf(file_path: String) -> ApiResult<ParseResult> {
    let start_time = std::time::Instant::now();
    tracing::info!("开始解析 PDF 文件：{}", file_path);

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(ParserError::file_not_found(&file_path));
    }
    tracing::debug!("文件存在性检查通过：{}", file_path);

    // 提取元数据
    let metadata = extract_metadata_from_path(&file_path);
    tracing::debug!(
        "元数据提取完成：title={:?}, author={:?}, pages={}",
        metadata.title,
        metadata.author,
        metadata.page_count
    );

    // 生成章节（每 10 页为一章）
    let chapters = generate_chapters(metadata.page_count as usize, DEFAULT_PAGES_PER_CHAPTER);
    let chapter_count = chapters.len() as i32;
    tracing::debug!("章节生成完成，章节数：{}", chapter_count);

    // 估算总字符数
    let total_chars = estimate_total_chars(&file_path, 5);
    tracing::debug!("字符数估算完成：{}", total_chars);

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 提取书名
    let title = metadata.title.clone().unwrap_or_else(|| {
        Path::new(&file_path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("未知书籍")
            .to_string()
    });

    let book_info = BookInfo {
        book_id,
        title,
        author: metadata.author.unwrap_or_else(|| "未知作者".to_string()),
        chapter_count,
        total_characters: total_chars,
        file_path,
        file_type: "pdf".to_string(),
        cover_path: None,
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "PDF 解析完成：{} 章节，{} 字符，{} 页，耗时：{:?}",
        chapter_count,
        total_chars,
        metadata.page_count,
        elapsed
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}

/// 根据页数生成章节
fn generate_chapters(total_pages: usize, pages_per_chapter: usize) -> Vec<ChapterInfo> {
    let mut chapters = Vec::new();

    if total_pages == 0 {
        return chapters;
    }

    let pages_per_chapter = pages_per_chapter.max(1);

    for (chapter_index, start_page) in (0..total_pages).step_by(pages_per_chapter).enumerate() {
        let end_page = (start_page + pages_per_chapter).min(total_pages);

        chapters.push(ChapterInfo {
            chapter_id: Uuid::new_v4().to_string(),
            title: format!("第 {} 章", chapter_index + 1),
            start_index: start_page as i64,
            end_index: end_page as i64,
            content_length: (end_page - start_page) as i64,
            index: chapter_index as i32,
            level: 0,
        });
    }

    chapters
}

/// 异步解析 PDF 文件
pub async fn async_parse_pdf_file(file_path: String) -> ApiResult<ParseResult> {
    validate_file_path(&file_path)?;

    tokio::task::spawn_blocking(move || { parse_pdf(file_path) })
    .await
    .map_err(|e| ParserError::Other(format!("异步任务执行失败：{}", e)))?
}

/// 获取 PDF 文件的页数
///
/// 注意：每次调用都会创建新的 Pdfium 实例（涉及加载动态库）。
/// 由于此函数调用频率低，性能影响可接受。
#[allow(dead_code)]
pub fn get_pdf_page_count(file_path: String) -> i32 {
    use pdfium_render::prelude::Pdfium;

    let pdfium = Pdfium::default();
    let load_result = pdfium.load_pdf_from_file(&file_path, None);
    match load_result {
        Ok(pdf) => pdf.pages().len() as i32,
        Err(_) => 0,
    }
}

/// 获取 PDF 元数据
pub fn get_pdf_metadata(file_path: String) -> crate::ffi::PdfMetadata {
    extract_metadata_from_path(&file_path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_parse_pdf_file_not_found() {
        let result = parse_pdf("non_existent.pdf".to_string());
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_parse_pdf_invalid_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("invalid.pdf");
        fs::write(&file_path, b"not a pdf file").unwrap();

        let result = parse_pdf(file_path.to_str().unwrap().to_string());
        // 空文件或者无效内容应该返回错误或者 0 页
        // pdf 库可能对某些无效文件也返回成功，但页数为 0
        if let Ok(parse_result) = result {
            // 如果成功，页数应该为 0
            assert_eq!(parse_result.book_info.chapter_count, 0);
        }
        // 或者返回错误也是可以接受的
    }

    #[test]
    fn test_generate_chapters_basic() {
        let chapters = generate_chapters(25, 10);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].start_index, 0);
        assert_eq!(chapters[0].end_index, 10);
        assert_eq!(chapters[1].start_index, 10);
        assert_eq!(chapters[1].end_index, 20);
        assert_eq!(chapters[2].start_index, 20);
        assert_eq!(chapters[2].end_index, 25);
    }

    #[test]
    fn test_generate_chapters_empty() {
        let chapters = generate_chapters(0, 10);
        assert!(chapters.is_empty());
    }

    #[test]
    fn test_generate_chapters_exact_multiple() {
        // 测试页数正好是每章页数的倍数的情况
        let chapters = generate_chapters(30, 10);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].start_index, 0);
        assert_eq!(chapters[0].end_index, 10);
        assert_eq!(chapters[1].start_index, 10);
        assert_eq!(chapters[1].end_index, 20);
        assert_eq!(chapters[2].start_index, 20);
        assert_eq!(chapters[2].end_index, 30);
    }

    #[test]
    fn test_generate_chapters_single_page() {
        let chapters = generate_chapters(1, 10);
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].start_index, 0);
        assert_eq!(chapters[0].end_index, 1);
    }

    #[test]
    fn test_generate_chapters_zero_pages_per_chapter() {
        // 测试每章 0 页的边界情况（应该被修正为至少 1 页）
        let chapters = generate_chapters(10, 0);
        assert!(!chapters.is_empty());
    }

    #[test]
    fn test_get_pdf_metadata_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        fs::write(&file_path, b"").unwrap();

        let metadata = get_pdf_metadata(file_path.to_str().unwrap().to_string());
        // 空文件应该返回默认元数据
        assert_eq!(metadata.page_count, 0);
        assert!(metadata.title.is_none());
        assert!(metadata.author.is_none());
    }

    #[test]
    fn test_get_pdf_page_count_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        fs::write(&file_path, b"").unwrap();

        let count = get_pdf_page_count(file_path.to_str().unwrap().to_string());
        assert_eq!(count, 0);
    }

    // 集成测试：需要真实的 PDF 测试样本
    #[test]
    #[ignore]
    fn test_parse_pdf_integration() {
        // 此测试需要真实的 PDF 文件，默认跳过
        // 运行：cargo test test_parse_pdf_integration -- --ignored
        let test_pdf_path = std::env::var("TEST_PDF_PATH").unwrap_or_else(|_| "".to_string());
        if test_pdf_path.is_empty() {
            eprintln!("跳过集成测试：未设置 TEST_PDF_PATH 环境变量");
            return;
        }

        let result = parse_pdf(test_pdf_path);
        assert!(result.is_ok(), "PDF 集成测试失败：{:?}", result);
        let parse_result = result.unwrap();
        assert!(!parse_result.book_info.title.is_empty());
        assert!(!parse_result.chapters.is_empty());
    }
}
