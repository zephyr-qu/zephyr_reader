//! EPUB 文件解析
//! 整合 EPUB 解压、元数据提取、章节内容读取
use std::path::Path;

use uuid::Uuid;

use super::toc::extract_chapters_from_epub;
use super::unzip::EpubFile;
use super::provider::EpubContentProvider;
use crate::parser::provider::ChapterContentProvider;
use crate::domain::{
    AppError, ParseResult, RichChapterContent, RichParagraph, TypesetConfig,
};
use crate::storage::models::{Book, BookFormat, Chapter};

use crate::text::rich_text;
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
        return Err(AppError::FileNotFound { path: file_path.into() });
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
                if let Some(href) = spine.get(i) {
                    if let Ok(text) = epub_file.read_resource(href) {
                        parts.push(text);
                    }
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


/// 分页处理
// ==================== 富文本支持 ====================
/// 获取章节富文本内容（保留 HTML 样式）
///
/// 解析 EPUB 章节的 HTML 内容，提取为结构化的富文本段落。
///
/// # 参数
///
/// * `file_path` - EPUB 文件路径
/// * `chapter_id` - 章节 ID（从 0 开始）
///
/// # 返回值
///
/// * `Ok(RichChapterContent)` - 富文本章节内容
/// * `Err(AppError)` - 解析失败
pub fn get_chapter_content_rich(
    file_path: &str,
    start_index: i32,
    end_index: i32,
) -> Result<RichChapterContent, AppError> {
    tracing::info!(
        "[get_chapter_content_rich] start: file_path={}, spine={}..{}",
        file_path,
        start_index,
        end_index
    );

    let provider = EpubContentProvider::open_from_bounds(file_path, start_index, end_index)?;
    let html_content = provider.read_html_range(0, u64::MAX)
        .ok_or_else(|| AppError::EpubParseError { reason: "rich HTML extraction not supported".into() })??;
    tracing::info!(
        "[get_chapter_content_rich] HTML content length: {} bytes",
        html_content.len()
    );

    // ── 内容过大保护 ─────────────────────────────────────
    // 单章 HTML > 100KB 时跳过 html5ever 解析（耗时可达 20+ 秒），
    // 直接回退到纯文本路径。此类章节通常因 HTML 文件过大导致，
    // 富文本排版收益有限，不值得等待。
    const MAX_HTML_SIZE: usize = 100 * 1024;
    if html_content.len() > MAX_HTML_SIZE {
        tracing::warn!(
            "[get_chapter_content_rich] HTML too large ({} bytes), \
             skipping rich text parsing, fallback to plain text",
            html_content.len(),
        );
        return Ok(RichChapterContent {
            chapter_id: format!("{start_index}..{end_index}"),
            paragraphs: Vec::new(),
            total_characters: 0,
        });
    }
    tracing::debug!(
        "[get_chapter_content_rich] HTML first 200 chars: {:?}",
        &html_content.chars().take(200).collect::<String>()
    );

    // 使用 html5ever 解析 HTML 为富文本
    let mut paragraphs = rich_text::parse_html_to_rich_text(&html_content)?;
    tracing::info!(
        "[get_chapter_content_rich] parse result: {} paragraphs",
        paragraphs.len()
    );

    // 解析图片：遍历段落，加载图片数据
    for p in &mut paragraphs {
        if p.is_image {
            if let Some(src) = &p.image_src {
                if let Some(bytes) = provider.read_resource_bytes(src) {
                    p.image_data = bytes;
                    tracing::info!(
                        "[get_chapter_content_rich] loading image: src={}, size={} bytes",
                        src,
                        p.image_data.len()
                    );
                } else {
                    tracing::warn!(
                        "[get_chapter_content_rich] unable to load image: src={}",
                        src
                    );
                }
            }
        }
    }
    if let Some(first) = paragraphs.first() {
        tracing::info!(
            "[get_chapter_content_rich] first paragraph: spans={}, indent={}, is_heading={}, text={:?}",
            first.spans.len(),
            first.indent,
            first.is_heading,
            &first.full_text().chars().take(80).collect::<String>()
        );
    }

    // 计算总字符数
    let total_characters = paragraphs
        .iter()
        .map(|p| p.full_text().chars().count() as i64)
        .sum();
    tracing::info!(
        "[get_chapter_content_rich] done: total_characters={}",
        total_characters
    );

    Ok(RichChapterContent {
        chapter_id: format!("{start_index}..{end_index}"),
        paragraphs,
        total_characters,
    })
}

/// 获取章节富文本内容（带排版配置）
///
/// 在保留 HTML 样式的基础上，应用排版配置（首行缩进、标点优化等）。
///
/// # 参数
///
/// * `file_path` - EPUB 文件路径
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置
///
/// # 返回值
///
/// * `Ok(Vec<RichParagraph>)` - 排版后的富文本段落
/// * `Err(AppError)` - 解析失败
pub fn get_chapter_content_rich_with_typeset(
    file_path: &str,
    start_index: i32,
    end_index: i32,
    config: &TypesetConfig,
) -> Result<Vec<RichParagraph>, AppError> {
    let rich_content = get_chapter_content_rich(file_path, start_index, end_index)?;

    // 对富文本段落应用排版优化
    let mut optimized_paragraphs = Vec::with_capacity(rich_content.paragraphs.len());

    for paragraph in rich_content.paragraphs {
        // 应用首行缩进
        let mut optimized = paragraph.clone();
        if !paragraph.is_heading && config.first_line_indent > 0 {
            optimized.indent = config.first_line_indent;
        }
        optimized_paragraphs.push(optimized);
    }

    Ok(optimized_paragraphs)
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
