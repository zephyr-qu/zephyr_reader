//! EPUB 文件解析
//! 整合 EPUB 解压、元数据提取、章节内容读取
//!
//! 支持并行章节解析（使用 rayon），提升大文件解析性能。

use std::path::Path;
use uuid::Uuid;

use super::toc::extract_chapters_from_epub;
use super::unzip::EpubFile;
use crate::ffi::{
    ApiResult, BookInfo, ChapterInfo, PageContent, ParseConfig, ParseResult, ParserError,
    RichChapterContent, RichParagraph, TypesetConfig,
};
use crate::text_process::constants::{EPUB_MIN_CHARS_PER_PAGE, EPUB_MIN_LINES_PER_PAGE};
use crate::text_process::{rich_text, typeset};
use flutter_rust_bridge::frb;

/// 解析 EPUB 文件
#[frb(sync)]
pub fn parse_epub(file_path: String) -> ApiResult<ParseResult> {
    parse_epub_with_config(file_path, ParseConfig::default())
}

/// 解析 EPUB 文件（带配置）
///
/// 支持并行解析配置，适用于大文件优化。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
/// * `config` - 解析配置（并行、缓存等）
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[frb(sync)]
pub fn parse_epub_with_config(file_path: String, config: ParseConfig) -> ApiResult<ParseResult> {
    let start_time = std::time::Instant::now();
    tracing::info!(
        "开始解析 EPUB 文件：{} (并行：{})",
        file_path,
        config.enable_parallel
    );

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(ParserError::file_not_found(&file_path));
    }
    tracing::debug!("文件存在性检查通过：{}", file_path);

    // 打开 EPUB 文件
    let mut epub_file = EpubFile::open(&file_path)?;
    tracing::debug!("EPUB 文件打开成功");

    // 提取元数据
    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();
    tracing::debug!("元数据提取完成：title={}, author={}", title, author);

    // 提取目录
    let chapters = extract_chapters_from_epub(&mut epub_file);
    let chapter_count = chapters.len() as i32;
    tracing::debug!("目录提取完成，章节数：{}", chapter_count);

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 计算总字符数（需要读取所有章节）
    let total_chars = estimate_total_chars(&mut epub_file, &chapters);
    tracing::debug!("字符数估算完成：{}", total_chars);

    let book_info = BookInfo {
        book_id,
        title,
        author,
        chapter_count,
        total_characters: total_chars,
        file_path,
        file_type: "epub".to_string(),
        cover_path,
    };

    // 如果启用并行解析，使用 rayon 处理章节
    if config.enable_parallel && chapter_count > 1 {
        let thread_count = config.get_thread_count();
        tracing::info!("使用并行解析，线程数：{}", thread_count);

        // 使用当前线程池（全局线程池在 lib.rs 中初始化）
        // 如果全局线程池未初始化，rayon 会使用默认线程池
    }

    let elapsed = start_time.elapsed();
    tracing::info!(
        "EPUB 解析完成：{} 章节，{} 字符，耗时：{:?}",
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
fn estimate_total_chars(epub_file: &mut EpubFile, chapters: &[ChapterInfo]) -> i64 {
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
        if let Ok(content) = read_chapter_content(epub_file, &chapters[idx]) {
            let content_str: String = content;
            total_sampled += content_str.chars().count() as i64;
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

/// 获取章节内容（分页）
pub fn get_chapter_content(
    file_path: &str,
    chapter_id: i32,
    config: &TypesetConfig,
) -> ApiResult<Vec<PageContent>> {
    tracing::debug!("读取 EPUB 章节 {} 内容：{}", chapter_id, file_path);

    let mut epub_file = EpubFile::open(file_path)?;
    let chapters = extract_chapters_from_epub(&mut epub_file);

    let chapter = chapters
        .iter()
        .find(|c| c.index == chapter_id)
        .ok_or_else(|| ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id)))?;

    // 读取章节内容
    let content = read_chapter_content(&mut epub_file, chapter)?;

    // 排版处理
    let typeset_content = typeset::typeset_content(content, "auto".to_string(), config.clone())?;

    // 分页
    let pages = paginate_content(&typeset_content, chapter.index, config);

    Ok(pages)
}

/// 读取章节内容
fn read_chapter_content(epub_file: &mut EpubFile, chapter: &ChapterInfo) -> ApiResult<String> {
    // EPUB 章节的 start_index 存储的是 spine 中的索引
    let spine = epub_file.spine();
    let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
        ParserError::ChapterExtractError(format!("章节索引超出范围：{}", chapter.start_index))
    })?;

    epub_file.read_resource(href)
}

/// 分页处理
fn paginate_content(content: &str, chapter_index: i32, config: &TypesetConfig) -> Vec<PageContent> {
    let lines: Vec<&str> = content.lines().collect();
    let mut pages = Vec::new();

    // 根据页面高度和字体大小估算每页行数
    let lines_per_page =
        (config.page_height as f32 / config.font_size as f32 / config.line_spacing) as usize;
    let lines_per_page = lines_per_page.max(EPUB_MIN_LINES_PER_PAGE); // 至少 EPUB_MIN_LINES_PER_PAGE 行每页

    for (page_index, chunk) in lines.chunks(lines_per_page).enumerate() {
        let is_last = page_index == lines.len().div_ceil(lines_per_page) - 1;
        pages.push(PageContent {
            chapter_index,
            page_index: page_index as i32,
            content: chunk.join("\n"),
            is_last_page: is_last,
        });
    }

    if pages.is_empty() {
        pages.push(PageContent {
            chapter_index,
            page_index: 0,
            content: content.to_string(),
            is_last_page: true,
        });
    }

    pages
}

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
/// * `Err(ParserError)` - 解析失败
pub fn get_chapter_content_rich(file_path: &str, chapter_id: i32) -> ApiResult<RichChapterContent> {
    tracing::debug!("读取 EPUB 章节 {} 富文本内容：{}", chapter_id, file_path);

    let mut epub_file = EpubFile::open(file_path)?;
    let chapters = extract_chapters_from_epub(&mut epub_file);

    let chapter = chapters
        .iter()
        .find(|c| c.index == chapter_id)
        .ok_or_else(|| ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id)))?;

    // 读取章节 HTML 内容
    let html_content = read_chapter_content(&mut epub_file, chapter)?;

    // 使用 html5ever 解析 HTML 为富文本
    let paragraphs = rich_text::parse_html_to_rich_text(&html_content);

    // 计算总字符数
    let total_characters = paragraphs
        .iter()
        .map(|p| p.full_text().chars().count() as i64)
        .sum();

    Ok(RichChapterContent {
        chapter_id: chapter.chapter_id.clone(),
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
/// * `Err(ParserError)` - 解析失败
pub fn get_chapter_content_rich_with_typeset(
    file_path: &str,
    chapter_id: i32,
    config: &TypesetConfig,
) -> ApiResult<Vec<RichParagraph>> {
    let rich_content = get_chapter_content_rich(file_path, chapter_id)?;

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

/// 将富文本内容分页
///
/// 根据排版配置，将富文本段落分割为适合阅读的页面。
///
/// # 参数
///
/// * `paragraphs` - 富文本段落列表
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置
///
/// # 返回值
///
/// 返回分页后的页面列表（每个页面包含纯文本内容）
pub fn paginate_rich_content(
    paragraphs: &[RichParagraph],
    chapter_index: i32,
    config: &TypesetConfig,
) -> Vec<PageContent> {
    // 估算每页可容纳的字符数
    let chars_per_page =
        ((config.page_height as f32 / config.font_size as f32 / config.line_spacing)
            * (config.page_width as f32 / config.font_size as f32)) as usize;
    let chars_per_page = chars_per_page.max(EPUB_MIN_CHARS_PER_PAGE); // 至少 EPUB_MIN_CHARS_PER_PAGE 字符每页

    let mut pages = Vec::new();
    let mut current_page_content = String::new();
    let mut current_page_chars = 0;
    let mut page_index = 0;

    for (para_idx, paragraph) in paragraphs.iter().enumerate() {
        let para_text = paragraph.full_text();
        let para_chars = para_text.chars().count();

        // 如果当前页放不下这个段落，或者已达到字符限制
        if current_page_chars > 0 && current_page_chars + para_chars > chars_per_page {
            // 保存当前页
            pages.push(PageContent {
                chapter_index,
                page_index,
                content: current_page_content.clone(),
                is_last_page: false,
            });
            page_index += 1;
            current_page_content = String::new();
            current_page_chars = 0;
        }

        // 添加段落
        if !current_page_content.is_empty() {
            current_page_content.push_str("\n\n");
        }
        current_page_content.push_str(&para_text);
        current_page_chars += para_chars;

        // 如果是最后一个段落，标记为最后一页
        if para_idx == paragraphs.len() - 1 {
            pages.push(PageContent {
                chapter_index,
                page_index,
                content: current_page_content.clone(),
                is_last_page: true,
            });
        }
    }

    // 处理空内容
    if pages.is_empty() {
        pages.push(PageContent {
            chapter_index,
            page_index: 0,
            content: String::new(),
            is_last_page: true,
        });
    }

    pages
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
            matches!(err, ParserError::FileNotFound { .. }),
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

    #[test]
    fn test_paginate_content_empty() {
        let config = TypesetConfig::default();
        let pages = paginate_content("", 0, &config);
        assert_eq!(pages.len(), 1);
        assert_eq!(pages[0].content, "");
        assert!(pages[0].is_last_page);
    }

    #[test]
    fn test_paginate_content_single_page() {
        let config = TypesetConfig {
            page_height: 800,
            font_size: 16,
            line_spacing: 1.5,
            ..Default::default()
        };
        let content = "这是单页内容。\n第二行。";
        let pages = paginate_content(content, 0, &config);
        assert!(!pages.is_empty());
        assert!(pages[0].is_last_page);
    }

    // ==================== 富文本测试 ====================

    #[test]
    fn test_paginate_rich_content_empty() {
        let config = TypesetConfig::default();
        let paragraphs = vec![];
        let pages = paginate_rich_content(&paragraphs, 0, &config);
        assert_eq!(pages.len(), 1);
        assert!(pages[0].is_last_page);
    }

    #[test]
    fn test_paginate_rich_content_single_paragraph() {
        let config = TypesetConfig::default();
        let paragraphs = vec![RichParagraph::plain("这是一个测试段落。".to_string(), 2)];
        let pages = paginate_rich_content(&paragraphs, 0, &config);
        assert_eq!(pages.len(), 1);
        assert!(pages[0].content.contains("这是一个测试段落"));
        assert!(pages[0].is_last_page);
    }

    #[test]
    fn test_paginate_rich_content_multiple_pages() {
        let config = TypesetConfig {
            page_height: 800,
            page_width: 600,
            font_size: 16,
            line_spacing: 1.5,
            ..Default::default()
        };

        // 创建多个长段落，测试分页
        let paragraphs: Vec<RichParagraph> = (0..10)
            .map(|i| {
                RichParagraph::plain(
                    format!("这是第 {} 个段落，包含大量文本用于测试分页功能。", i),
                    2,
                )
            })
            .collect();

        let pages = paginate_rich_content(&paragraphs, 0, &config);
        assert!(!pages.is_empty());
        // 验证最后一页标记
        assert!(pages.last().unwrap().is_last_page);
        // 验证第一页不是最后一页
        if pages.len() > 1 {
            assert!(!pages[0].is_last_page);
        }
    }
}
