//! EPUB 文件解析
//! 整合 EPUB 解压、元数据提取、章节内容读取

use std::path::Path;
use uuid::Uuid;

use super::toc::extract_chapters_from_epub;
use super::unzip::EpubFile;
use crate::ffi::{
    ApiResult, BookInfo, ChapterInfo, PageContent, ParseResult, ParserError, TypesetConfig,
};
use crate::text_process::typeset;
use flutter_rust_bridge::frb;

/// 解析 EPUB 文件
#[frb(sync)]
pub fn parse_epub(file_path: String) -> ApiResult<ParseResult> {
    log::info!("开始解析 EPUB 文件：{}", file_path);

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(ParserError::file_not_found(&file_path));
    }

    // 打开 EPUB 文件
    let mut epub_file = EpubFile::open(&file_path)?;

    // 提取元数据
    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();

    // 提取目录
    let chapters = extract_chapters_from_epub(&mut epub_file);
    let chapter_count = chapters.len() as i32;

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 计算总字符数（需要读取所有章节）
    let total_chars = estimate_total_chars(&mut epub_file, &chapters);

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

    log::info!(
        "EPUB 解析完成：{} 章节，{} 字符",
        chapter_count,
        total_chars
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}

/// 估算总字符数
fn estimate_total_chars(epub_file: &mut EpubFile, chapters: &[ChapterInfo]) -> i64 {
    let mut total = 0i64;

    // 读取前 10 章估算
    for chapter in chapters.iter().take(10) {
        if let Ok(content) = read_chapter_content(epub_file, chapter) {
            let content_str: String = content;
            total += content_str.chars().count() as i64;
        }
    }

    // 根据已读取的章节估算总数
    if !chapters.is_empty() {
        let read_count = chapters.len().min(10);
        if read_count > 0 {
            total = (total as f64 / read_count as f64 * chapters.len() as f64) as i64;
        }
    }

    total
}

/// 获取章节内容（分页）
pub fn get_chapter_content(
    file_path: &str,
    chapter_id: i32,
    config: &TypesetConfig,
) -> ApiResult<Vec<PageContent>> {
    log::debug!("读取 EPUB 章节 {} 内容：{}", chapter_id, file_path);

    let mut epub_file = EpubFile::open(file_path)?;
    let chapters = extract_chapters_from_epub(&mut epub_file);

    let chapter = chapters
        .iter()
        .find(|c| c.chapter_id == chapter_id)
        .ok_or_else(|| ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id)))?;

    // 读取章节内容
    let content = read_chapter_content(&mut epub_file, chapter)?;

    // 排版处理
    let typeset_content = typeset::typeset_content(content, "auto".to_string(), config.clone())?;

    // 分页
    let pages = paginate_content(&typeset_content, chapter_id, config);

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
fn paginate_content(content: &str, chapter_id: i32, config: &TypesetConfig) -> Vec<PageContent> {
    let lines: Vec<&str> = content.lines().collect();
    let mut pages = Vec::new();

    // 根据页面高度和字体大小估算每页行数
    let lines_per_page =
        (config.page_height as f32 / config.font_size as f32 / config.line_spacing) as usize;
    let lines_per_page = lines_per_page.max(10); // 至少 10 行每页

    for (page_index, chunk) in lines.chunks(lines_per_page).enumerate() {
        let is_last = page_index == lines.len().div_ceil(lines_per_page) - 1;
        pages.push(PageContent {
            chapter_id,
            page_index: page_index as i32,
            content: chunk.join("\n"),
            is_last_page: is_last,
        });
    }

    if pages.is_empty() {
        pages.push(PageContent {
            chapter_id,
            page_index: 0,
            content: content.to_string(),
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
    }
}
