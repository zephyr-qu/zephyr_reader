//! PDF 文件解析主逻辑
//! 负责整合元数据提取、文本解析、图像提取等功能

use std::path::Path;

use uuid::Uuid;

use super::metadata::extract_metadata_from_path;
use super::text::estimate_total_chars;

use super::DEFAULT_PAGES_PER_CHAPTER;
use crate::domain::{AppError, ParseResult, PdfMetadata};
use crate::storage::models::{Book, BookFormat, Chapter};

/// 解析 PDF 文件
///
/// 读取并解析 PDF 文件，提取书籍信息、元数据和章节列表。
/// PDF 章节按页数划分，每 10 页为一章（可配置）。
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(AppError)` - 解析失败
pub fn parse_pdf(file_path: String) -> Result<ParseResult, AppError> {
    let start_time = std::time::Instant::now();
    tracing::info!("start parsing PDF file: {}", file_path);

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(AppError::file_not_found(&file_path));
    }
    tracing::debug!("file existence check passed: {}", file_path);

    // 提取元数据
    let metadata = extract_metadata_from_path(&file_path)?;
    tracing::debug!(
        "metadata extracted: title={:?}, author={:?}, pages={}",
        metadata.title,
        metadata.author,
        metadata.page_count
    );

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 生成章节（每 10 页为一章）
    let chapters = generate_chapters(
        metadata.page_count as usize,
        DEFAULT_PAGES_PER_CHAPTER,
        &book_id,
    );
    let chapter_count = chapters.len() as i32;
    tracing::debug!("chapters generated, count: {}", chapter_count);

    // 估算总字符数
    let total_chars = estimate_total_chars(&file_path, 5);
    tracing::debug!("character count estimated: {}", total_chars);

    let title = metadata.title.clone().unwrap_or_else(|| {
        Path::new(&file_path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("Unknown Book")
            .to_string()
    });

    let book_info = Book {
        book_id,
        file_path: file_path.clone(),
        file_hash: None,
        file_size: 0,
        file_mtime: None,
        title,
        author: metadata.author,
        description: None,
        cover_path: None,
        publisher: None,
        translator: None,
        isbn: None,
        chapter_count:chapter_count as i64,
        total_characters: total_chars,
        format: BookFormat::Pdf,
        added_at: chrono::Utc::now(),
        last_opened_at: None,
        status: crate::storage::models::BookStatus::Reading,
        is_pinned: false,
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "PDF parse complete: {} chapters, {} chars, {} pages, elapsed: {:?}",
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
fn generate_chapters(total_pages: usize, pages_per_chapter: usize, book_id: &str) -> Vec<Chapter> {
    let mut chapters = Vec::new();

    if total_pages == 0 {
        return chapters;
    }

    let pages_per_chapter = pages_per_chapter.max(1);

    for (chapter_index, start_page) in (0..total_pages).step_by(pages_per_chapter).enumerate() {
        let end_page = (start_page + pages_per_chapter).min(total_pages);

        chapters.push(
          Chapter::new(book_id, &format!("Chapter {}", chapter_index + 1), chapter_index as i64, 0,  start_page as i64, end_page as i64)

        //   {
        //     id: Uuid::new_v4().to_string(),
        //     book_id: book_id.to_string(),
        //     title: format!("Chapter {}", chapter_index + 1),
        //     chapter_index: chapter_index as i64,
        //     word_count: 0,
        //     cached_at: chrono::Utc::now(),
        //     level: 0,
        //     start_index: start_page as i64,
        //     end_index: end_page as i64,
        //     // content_length: (end_page - start_page) as i64,
        // }

      );
    }

    chapters
}

/// 获取 PDF 元数据
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
///
/// # 返回值
///
/// * `Ok(PdfMetadata)` - 元数据（含页码数和信息字典内容）
/// * `Err(AppError)` - 提取失败
pub fn get_pdf_metadata(file_path: String) -> Result<PdfMetadata, AppError> {
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
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    #[ignore = "requires Pdfium library, skipped in CI"]
    fn test_parse_pdf_invalid_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("invalid.pdf");
        fs::write(&file_path, b"not a pdf file").unwrap();

        let result = parse_pdf(file_path.to_str().unwrap().to_string());
        if let Ok(parse_result) = result {
            assert_eq!(parse_result.book_info.chapter_count, 0);
        }
    }

    #[test]
    fn test_generate_chapters_basic() {
        let chapters = generate_chapters(25, 10, "test");
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
        let chapters = generate_chapters(0, 10, "test");
        assert!(chapters.is_empty());
    }

    #[test]
    fn test_generate_chapters_exact_multiple() {
        let chapters = generate_chapters(30, 10, "test");
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
        let chapters = generate_chapters(1, 10, "test");
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].start_index, 0);
        assert_eq!(chapters[0].end_index, 1);
    }

    #[test]
    fn test_generate_chapters_zero_pages_per_chapter() {
        let chapters = generate_chapters(10, 0, "test");
        assert!(!chapters.is_empty());
    }

    #[test]
    #[ignore = "requires Pdfium library, skipped in CI"]
    fn test_get_pdf_metadata_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        fs::write(&file_path, b"").unwrap();

        let metadata = get_pdf_metadata(file_path.to_str().unwrap().to_string()).unwrap();
        assert_eq!(metadata.page_count, 0);
        assert!(metadata.title.is_none());
        assert!(metadata.author.is_none());
    }

    // #[test]
    // #[ignore = "requires Pdfium library, skipped in CI"]
    // fn test_get_pdf_page_count_empty_file() {
    //     let temp_dir = TempDir::new().unwrap();
    //     let file_path = temp_dir.path().join("empty.pdf");
    //     fs::write(&file_path, b"").unwrap();

    //     let count = get_pdf_page_count(file_path.to_str().unwrap().to_string());
    //     assert_eq!(count, 0);
    // }

    #[test]
    #[ignore = "requires real PDF file, skipped in CI"]
    fn test_parse_pdf_integration() {
        let test_pdf_path = std::env::var("TEST_PDF_PATH").unwrap_or_else(|_| "".to_string());
        if test_pdf_path.is_empty() {
            eprintln!("skipping integration test: TEST_PDF_PATH not set");
            return;
        }

        let result = parse_pdf(test_pdf_path);
        assert!(result.is_ok(), "PDF integration test failed: {:?}", result);
        let parse_result = result.unwrap();
        assert!(!parse_result.book_info.title.is_empty());
        assert!(!parse_result.chapters.is_empty());
    }
}
