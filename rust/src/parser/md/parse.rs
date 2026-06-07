//! Markdown (.md) file parser
//! Uses comrak to render GFM-compliant Markdown (tables, footnotes, task lists, etc.)
//! Splits content into chapters by H2 headings (##)

use std::path::Path;

use comrak::options::{Extension, ListStyleType, Parse, Plugins, Render};
use comrak::{Arena, Options, format_html_with_plugins, parse_document};
use flutter_rust_bridge::frb;
use tokio::fs;

use super::metadata;
use crate::domain::{AppError, ParseResult};
use crate::parser::book_parser::BookMetadata;
use crate::storage::models::{Book, BookFormat, BookStatus, Chapter};

const MAX_FILE_SIZE: u64 = 50 * 1024 * 1024;
const MD_PARSER_NAME: &str = "md";

/// Markdown 文件解析器
#[derive(Clone, Copy)]
#[frb(opaque)]
pub struct MdParser;

impl MdParser {
    /// 创建新的 Markdown 解析器
    pub fn new() -> Self {
        Self
    }

    /// 获取解析器名称
    pub fn name(&self) -> &'static str {
        MD_PARSER_NAME
    }

    /// 获取支持的格式列表
    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["md", "markdown", "mdown", "mkdn"]
    }

    /// 解析 MD 文件
    ///
    /// 读取文件内容，提取 YAML frontmatter 中的标题/作者信息，
    /// 按 H2（##）标题分割章节。
    ///
    /// # 参数
    ///
    /// * `file_path` - Markdown 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析结果（含书籍信息和章节列表）
    /// * `Err(AppError)` - 解析失败
    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let content = fs::read_to_string(file_path)
            .await
            .map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;

        let file_size = content.len() as u64;
        if file_size > MAX_FILE_SIZE {
            return Err(AppError::security_error(
                format!(
                    "Markdown file too large: {} bytes (max {})",
                    file_size, MAX_FILE_SIZE
                ),
                file_path,
            ));
        }

        let title = metadata::extract_title(&content).unwrap_or_else(|| {
            Path::new(file_path)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("Untitled")
                .to_string()
        });

        let author = metadata::extract_author(&content).unwrap_or_default();
        let book_id = uuid::Uuid::new_v4().to_string();
        let chapters = extract_chapters(&content, &book_id);

        Ok(ParseResult {
            book_info: Book {
                book_id,
                file_path: file_path.to_string(),
                file_hash: None,
                file_size: file_size as i64,
                file_mtime: None,
                title,
                author: Some(author),
                description: None,
                cover_path: None,
                publisher: None,
                translator: None,
                isbn: None,
                chapter_count: chapters.len() as i64,
                total_characters: content.len() as i64,
                format: BookFormat::Md,
                added_at: chrono::Utc::now(),
                last_opened_at: None,
                status: BookStatus::Reading,
                is_pinned: false,
            },
            chapters,
        })
    }

    /// 提取 MD 文件元数据
    ///
    /// 从 YAML frontmatter 或 H1 标题中提取书名和作者信息。
    ///
    /// # 参数
    ///
    /// * `file_path` - Markdown 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(BookMetadata)` - 书籍元数据
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let content = fs::read_to_string(file_path)
            .await
            .map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;

        let title = metadata::extract_title(&content).unwrap_or_else(|| {
            Path::new(file_path)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("Untitled")
                .to_string()
        });

        let author = metadata::extract_author(&content).unwrap_or_default();
        let chapters = extract_chapters_raw(&content);

        Ok(BookMetadata {
            title,
            author,
            description: None,
            cover_path: None,
            publisher: None,
            translator: None,
            isbn: None,
            publish_year: None,
            language: None,
            chapter_count: chapters.len() as i64,
            total_characters: content.len() as i64,
        })
    }

    /// 提取指定章节内容（HTML 格式）
    ///
    /// 使用 comrak 将章节 Markdown 渲染为 HTML。
    ///
    /// # 参数
    ///
    /// * `file_path` - Markdown 文件路径
    /// * `chapter_index` - 章节索引（从 0 开始）
    ///
    /// # 返回值
    ///
    /// * `Ok(String)` - 章节 HTML 内容
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_chapter(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<String, AppError> {
        let content = fs::read_to_string(file_path)
            .await
            .map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;

        let chapters = extract_chapters_raw(&content);
        let idx = chapter_index as usize;
        if idx >= chapters.len() {
            return Err(AppError::invalid_input(format!(
                "Chapter index {} out of range (total: {})",
                chapter_index,
                chapters.len()
            )));
        }

        let (_, chapter_text) = &chapters[idx];
        let html = markdown_to_html(chapter_text);
        Ok(html)
    }
}

fn extract_chapters(content: &str, book_id: &str) -> Vec<Chapter> {
    let raw = extract_chapters_raw(content);
    raw.iter()
        .enumerate()
        .map(|(i, (title, text))| Chapter::new(book_id, title, i as i64, 0, 0, text.len() as i64))
        .collect()
}

fn extract_chapters_raw(content: &str) -> Vec<(String, String)> {
    let mut chapters: Vec<(String, String)> = Vec::new();
    let mut current_title = String::from("前言");
    let mut current_lines: Vec<&str> = Vec::new();

    let body_start = if content.trim().starts_with("---") {
        content[3..].find("\n---").map(|pos| pos + 3 + 3)
    } else {
        Some(0)
    };

    let body_start = body_start.unwrap_or(0);

    for line in content[body_start..].lines() {
        let trimmed = line.trim();
        if let Some(heading) = trimmed.strip_prefix("## ") {
            if !current_lines.is_empty() {
                chapters.push((current_title.clone(), current_lines.join("\n")));
                current_lines.clear();
            }
            current_title = heading.trim().to_string();
        } else {
            current_lines.push(line);
        }
    }

    if !current_lines.is_empty() || chapters.is_empty() {
        chapters.push((current_title.clone(), current_lines.join("\n")));
    }

    chapters
}

fn markdown_to_html(text: &str) -> String {
    let arena = Arena::new();
    let options = Options {
        render: Render {
            github_pre_lang: true,
            full_info_string: true,
            list_style: ListStyleType::Dash,
            ..Default::default()
        },
        extension: Extension {
            strikethrough: true,
            tagfilter: true,
            table: true,
            autolink: true,
            tasklist: true,
            superscript: true,
            header_id_prefix: None,
            footnotes: true,
            description_lists: true,
            front_matter_delimiter: None,
            multiline_block_quotes: true,
            math_dollars: false,
            math_code: false,
            ..Default::default()
        },
        parse: Parse {
            smart: true,
            default_info_string: None,
            relaxed_tasklist_matching: true,
            broken_link_callback: None,
            relaxed_autolinks: false,
            escaped_char_spans: false,
            ignore_setext: false,
            leave_footnote_definitions: false,
            sourcepos_chars: false,
            tasklist_in_table: false,
        },
    };

    let root = parse_document(&arena, text, &options);
    let mut html = String::new();
    format_html_with_plugins(root, &options, &mut html, &Plugins::default()).ok();
    html
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_frontmatter_title() {
        let content = r#"---
title: "Test Book"
author: "Author Name"
---

Content here.
"#;
        assert_eq!(
            metadata::extract_title(content),
            Some("Test Book".to_string())
        );
        assert_eq!(
            metadata::extract_author(content),
            Some("Author Name".to_string())
        );
    }

    #[test]
    fn test_extract_h1_title() {
        let content = "# My Book\n\nSome content.";
        assert_eq!(
            metadata::extract_title(content),
            Some("My Book".to_string())
        );
    }

    #[test]
    fn test_chapter_splitting() {
        let content = "Intro text.\n\n## Chapter 1\n\nContent of chapter 1.\n\n## Chapter 2\n\nContent of chapter 2.";
        let chapters = extract_chapters_raw(&content);
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].0, "前言");
        assert_eq!(chapters[1].0, "Chapter 1");
        assert_eq!(chapters[2].0, "Chapter 2");
    }

    #[test]
    fn test_markdown_to_html() {
        let html = markdown_to_html("**bold** and *italic*");
        assert!(html.contains("<strong>"));
        assert!(html.contains("<em>"));
    }

    #[test]
    fn test_table_rendering() {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |";
        let html = markdown_to_html(md);
        assert!(html.contains("<table>"));
    }
}
