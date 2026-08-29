// ============================================================
// 文件作用：EPUB 文件解析 — 整合 EPUB 解压、元数据提取、章节内容读取。
//
// 公有类型/函数：
//   - parse_epub() — 解析 EPUB 文件，返回 ParseResult
//
// 私有函数：
//   - estimate_total_chars() — 使用首/中/尾三章采样估算总字符数
// ============================================================

//! EPUB 文件解析
//! 整合 EPUB 解压、元数据提取、章节内容读取
use std::path::Path;

use uuid::Uuid;

use super::archive_reader::EpubFile;
use super::toc::extract_chapters_from_epub;
use crate::domain::AppError;
use crate::domain::book::{Book, BookFormat};
use crate::parser::types::ParseResult;
/// 解析 EPUB 文件
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(AppError)` - 解析失败
pub fn parse_epub(file_path: String) -> Result<ParseResult, AppError> {
    let start_time = std::time::Instant::now();
    tracing::info!("start parsing EPUB file: {}", file_path);

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(AppError::FileNotFound { path: file_path });
    }
    tracing::debug!("file existence check passed: {}", file_path);

    // 打开 EPUB 文件
    let mut epub_file = EpubFile::open(&file_path)?;
    tracing::debug!("EPUB file opened successfully");

    // 提取元数据
    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();
    let publisher = epub_file.publisher();
    let translator = epub_file.translator();
    let isbn = epub_file.identifier();
    tracing::debug!("metadata extracted: title={}, author={}", title, author);

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 提取目录
    let chapters = extract_chapters_from_epub(&mut epub_file, &book_id);
    let chapter_count = chapters.len() as i32;
    tracing::debug!("TOC extracted, chapters: {}", chapter_count);


    let book_info = Book {
        book_id,
        file_path: file_path.clone(),
        title,
        author: Some(author),
        cover_path,
        chapter_count: chapter_count as i64,
        publisher,
        translator,
        isbn,
        file_size: std::fs::metadata(&file_path)
            .map(|m| m.len() as i64)
            .unwrap_or(0),
        format: BookFormat::Epub,
        added_at: chrono::Utc::now(),
        ..Default::default()
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "EPUB parse complete: {} chapters, elapsed: {:?}",
        chapter_count,
        elapsed
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epub_not_found() {
        let result = parse_epub("non_existent.epub".to_string());
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

}
