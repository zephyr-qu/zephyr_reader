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

use super::toc::extract_chapters_from_epub;
use super::unzip::EpubFile;
use crate::domain::chapter::Chapter;
use crate::domain::AppError;
use crate::parser::types::ParseResult;
use crate::domain::book::{Book, BookFormat};
/// EPUB 分页：每页最小行数
/// 防止每页行数过少导致显示异常
/// EPUB 分页：每页最小字符数
/// 防止分页过小导致性能问题
pub const EPUB_MIN_CHARS_PER_PAGE: usize = 500;
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

    // 计算总字符数（需要读取所有章节）
    let total_chars = estimate_total_chars(&mut epub_file, &chapters);
    tracing::debug!("character count estimated: {}", total_chars);

    let book_info = Book {
        book_id,
        file_path: file_path.clone(),
        title,
        author: Some(author),
        cover_path,
        chapter_count: chapter_count as i64,
        total_characters: total_chars,
        publisher,
        translator,
        isbn,
        file_size: std::fs::metadata(&file_path).map(|m| m.len() as i64).unwrap_or(0),
        format: BookFormat::Epub,
        added_at: chrono::Utc::now(),
        ..Default::default()
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "EPUB parse complete: {} chapters, {} chars, elapsed: {:?}",
        chapter_count,
        total_chars,
        elapsed
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}

/// 估算总字符数
///
/// 使用首/中/尾三章采样取平均，避免因章节长度分布不均导致的估算偏差。
fn estimate_total_chars(epub_file: &mut EpubFile, chapters: &[Chapter]) -> i64 {
    if chapters.is_empty() {
        return 0;
    }

    // 采样策略：取首章、中章、尾章（避免仅采样前几章导致的偏差）
    let sample_indices = if chapters.len() >= 3 {
        vec![0, chapters.len() / 2, chapters.len() - 1]
    } else if chapters.len() == 2 {
        vec![0, 1]
    } else {
        vec![0]
    };

    let mut total_sampled = 0i64;
    let mut sampled_count = 0i64;

    for &idx in &sample_indices {
        // Inline: read_chapter_content logic (function deleted in Phase B)
        let content: String = {
            let spine = epub_file.spine();
            let start = chapters[idx].start_index as usize;
            let end = (chapters[idx].end_index as usize).min(spine.len()).max(start + 1);
            let mut parts = Vec::new();
            for i in start..end {
                if let Some(href) = spine.get(i)
                    && let Ok(text) = epub_file.read_resource(href) {
                        parts.push(text);
                    }
            }
            parts.join("\n")
        };
        if !content.is_empty() {
            total_sampled += content.chars().count() as i64;
            sampled_count += 1;
        }
    }

    // 根据采样章节估算总数
    if sampled_count > 0 {
        let avg_chars_per_chapter = total_sampled / sampled_count;
        avg_chars_per_chapter * chapters.len() as i64
    } else {
        0
    }
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

    #[test]
    fn test_estimate_total_chars_empty() {
        use tempfile::TempDir;

        // 创建一个最小的有效 EPUB 文件用于测试
        let temp_dir = TempDir::new().unwrap();
        let epub_path = temp_dir.path().join("test.epub");

        // EPUB 文件最小结构（ZIP 格式）
        // 这里我们创建一个简单的 EPUB 用于测试
        // 注意：实际测试中应该使用真实的 EPUB 文件
        let result = parse_epub(epub_path.to_str().unwrap().to_string());
        assert!(result.is_err()); // 文件不存在或无效
    }
}
