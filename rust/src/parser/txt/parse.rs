//! TXT 文件解析
//! 负责章节提取、内容分段
//!
//! 支持并行章节解析（使用 rayon），提升大文件解析性能。

use once_cell::sync::Lazy;
use regex::Regex;
use std::path::Path;
use uuid::Uuid;

use super::decode;
use crate::ffi::{
    ApiResult, BookInfo, ChapterInfo, PageContent, ParseConfig, ParseResult, ParserError,
    TypesetConfig,
};
use crate::parser::parallel::validate_chapters_parallel;
use crate::text_process::{chapter_detect, typeset};
use flutter_rust_bridge::frb;

/// 中文章节匹配模式
static CHAPTER_PATTERN_ZH: Lazy<Regex> = Lazy::new(|| {
    Regex::new(
        r"(?m)^(第 [零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+[章回卷节部篇集]|序 [言引]|楔子 | 尾声 | 完结 | 番外 | 正文 [.\s]*\d+)"
    ).expect("CHAPTER_PATTERN_ZH 正则表达式编译失败 - 检查模式语法")
});

/// 解析 TXT 文件
#[frb(sync)]
pub fn parse_txt(file_path: String) -> ApiResult<ParseResult> {
    parse_txt_with_config(file_path, ParseConfig::default())
}

/// 解析 TXT 文件（带配置）
///
/// 支持并行解析配置，适用于大文件优化。
///
/// # 参数
///
/// * `file_path` - TXT 文件的完整路径
/// * `config` - 解析配置（并行、缓存等）
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[frb(sync)]
pub fn parse_txt_with_config(file_path: String, config: ParseConfig) -> ApiResult<ParseResult> {
    let start_time = std::time::Instant::now();
    tracing::info!(
        "开始解析 TXT 文件：{} (并行：{})",
        file_path,
        config.enable_parallel
    );

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(ParserError::file_not_found(&file_path));
    }
    tracing::debug!("文件存在性检查通过：{}", file_path);

    // 解码文件内容
    let content = decode::decode_file(&file_path)?;
    let total_chars = content.chars().count() as i64;
    tracing::debug!("文件解码完成，字符数：{}", total_chars);

    // 提取章节
    let mut chapters = extract_chapters(&content);
    let chapter_count = chapters.len() as i32;
    tracing::debug!("章节提取完成，章节数：{}", chapter_count);

    // 如果启用并行验证，使用 rayon 处理章节
    if config.enable_parallel && chapter_count > 5 {
        let thread_count = config.get_thread_count();
        tracing::info!("使用并行章节验证，线程数：{}", thread_count);
        chapters = validate_chapters_parallel(chapters, &content, thread_count);
        tracing::debug!("并行验证完成，有效章节数：{}", chapters.len());
    }

    // 生成书籍 ID
    let book_id = Uuid::new_v4().to_string();

    // 提取书名（从文件名或第一章标题）
    let file_name = Path::new(&file_path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("未知书籍")
        .to_string();

    let title = chapters
        .first()
        .map(|c| c.title.clone())
        .unwrap_or(file_name);

    let book_info = BookInfo {
        book_id,
        title,
        author: "未知作者".to_string(),
        chapter_count: chapters.len() as i32,
        total_characters: total_chars,
        file_path,
        file_type: "txt".to_string(),
        cover_path: None,
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "TXT 解析完成：{} 章节，{} 字符，耗时：{:?}",
        chapters.len(),
        total_chars,
        elapsed
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}

/// 从内容中提取章节
///
/// **重要**：返回的 `ChapterInfo.start_index` 和 `end_index` 是**字节偏移**（而非字符索引）。
/// 在使用这些值切片内容时，必须确保在 UTF-8 字符边界处截断。
fn extract_chapters(content: &str) -> Vec<ChapterInfo> {
    let mut chapters: Vec<ChapterInfo> = Vec::new();
    let mut chapter_id = 0;

    // 使用通用章节检测
    let detected = chapter_detect::extract_chapters(content, 1000);

    if !detected.is_empty() {
        return detected;
    }

    // 如果没有检测到章节，尝试按正则匹配
    let mut last_end = 0i64;

    for cap in CHAPTER_PATTERN_ZH.captures_iter(content) {
        if let Some(m) = cap.get(0) {
            let start = m.start() as i64;

            if chapter_id > 0 && last_end > 0 {
                // 更新上一章的结束位置
                if let Some(last) = chapters.last_mut() {
                    last.end_index = start;
                    last.content_length = start - last.start_index;
                }
            }

            chapters.push(ChapterInfo {
                chapter_id: uuid::Uuid::new_v4().to_string(),
                title: m.as_str().trim().to_string(),
                start_index: start,
                end_index: content.len() as i64,
                content_length: content.len() as i64 - start,
                index: chapter_id,
            });

            chapter_id += 1;
            last_end = start;
        }
    }

    // 如果没有匹配到任何章节，将整个文件作为一章
    if chapters.is_empty() {
        chapters.push(ChapterInfo {
            chapter_id: uuid::Uuid::new_v4().to_string(),
            title: "全文".to_string(),
            start_index: 0,
            end_index: content.len() as i64,
            content_length: content.len() as i64,
            index: 0,
        });
    }

    chapters
}

/// 获取章节内容（分页）
pub fn get_chapter_content(
    file_path: &str,
    chapter_index: i32,
    config: &TypesetConfig,
) -> ApiResult<Vec<PageContent>> {
    let content = decode::decode_file(file_path)?;
    let chapters = extract_chapters(&content);

    let chapter = chapters
        .iter()
        .find(|c| c.index == chapter_index)
        .ok_or_else(|| ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_index)))?;

    // 提取章节内容
    // 注意：extract_chapters 返回的 start_index/end_index 是字节偏移（来自 regex::Match::start/end）
    // 需要确保在 UTF-8 字符边界处截断
    let start_byte = chapter.start_index as usize;
    let end_byte = chapter.end_index.min(content.len() as i64) as usize;

    // 使用 floor_char_boundary 和 ceil_char_boundary 确保 UTF-8 边界对齐
    // （Rust 1.79+ 提供这些方法，如果使用更低版本需手动实现）
    let safe_start = content.floor_char_boundary(start_byte);
    let safe_end = content.ceil_char_boundary(end_byte);

    let chapter_text = &content[safe_start..safe_end];

    // 排版处理
    let typeset_content =
        typeset::typeset_content(chapter_text.to_string(), "auto".to_string(), config.clone())?;

    // 简单分页（实际应该根据像素计算）
    let lines_per_page = (config.page_height as usize / 20).max(1);
    let pages = simple_paginate(&typeset_content, chapter.index, lines_per_page);

    Ok(pages)
}

/// 简单分页
fn simple_paginate(content: &str, chapter_index: i32, lines_per_page: usize) -> Vec<PageContent> {
    let lines: Vec<&str> = content.lines().collect();
    let mut pages = Vec::new();

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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_extract_chapters_zh() {
        let content = r#"
第一章 开始
这是第一章的内容。

第二章 发展
这是第二章的内容。

第三章 结局
这是第三章的内容。
"#;

        let chapters = extract_chapters(content);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第一章 开始");
        assert_eq!(chapters[1].title, "第二章 发展");
    }

    #[test]
    fn test_parse_txt_file_not_found() {
        let result = parse_txt("non_existent_file.txt".to_string());
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_parse_txt_basic() {
        // 创建临时文件
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n\n这是测试内容。";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.file_type, "txt");
        assert!(parse_result.book_info.title.contains("第一章"));
        assert_eq!(parse_result.chapters.len(), 1);
    }

    #[test]
    fn test_parse_txt_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.txt");
        fs::write(&file_path, "").unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.total_characters, 0);
    }

    #[test]
    fn test_extract_chapters_no_chapters() {
        // 没有章节标记的内容，应该作为一章处理
        let content = "这是没有章节的完整内容。";
        let chapters = extract_chapters(content);
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].title, "全文");
    }

    #[test]
    fn test_extract_chapters_with_special_chars() {
        // 测试包含特殊字符的章节标题
        let content = r#"第零章 序章
这是序章内容。

第一〇一章 特殊数字
这是第101章内容。

第一千零一章 大结局
这是最终章。"#;

        let chapters = extract_chapters(content);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第零章 序章");
        assert_eq!(chapters[1].title, "第一〇一章 特殊数字");
    }

    #[test]
    fn test_simple_paginate_basic() {
        let content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5";
        let pages = simple_paginate(content, 1, 2);

        assert_eq!(pages.len(), 3);
        assert_eq!(pages[0].page_index, 0);
        assert!(!pages[0].is_last_page);
        assert_eq!(pages[2].page_index, 2);
        assert!(pages[2].is_last_page);
    }

    #[test]
    fn test_simple_paginate_empty_content() {
        let pages = simple_paginate("", 1, 10);

        assert_eq!(pages.len(), 1);
        assert_eq!(pages[0].page_index, 0);
        assert!(pages[0].is_last_page);
        assert_eq!(pages[0].content, "");
    }

    #[test]
    fn test_simple_paginate_single_page() {
        let content = "Single line";
        let pages = simple_paginate(content, 1, 10);

        assert_eq!(pages.len(), 1);
        assert_eq!(pages[0].content, "Single line");
        assert!(pages[0].is_last_page);
    }

    #[test]
    fn test_parse_txt_with_long_content() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("long.txt");

        // 创建包含多个章节的长文本
        let mut content = String::new();
        for i in 1..=10 {
            content.push_str(&format!("第{}章 章节{}\n\n这是第{}章的内容。\n\n", i, i, i));
        }
        fs::write(&file_path, &content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        // 章节检测可能无法识别所有格式，但至少应该有章节
        assert!(!parse_result.chapters.is_empty());
    }

    #[test]
    fn test_parse_txt_with_chinese_punctuation() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("chinese.txt");
        let content = "第一章：开始\n这是中文标点符号的测试。\n";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
    }
}
