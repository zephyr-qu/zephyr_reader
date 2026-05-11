//! EPUB 目录提取
//! 从 NCX 或 Nav 文档中提取章节信息，支持多级目录

use super::unzip::EpubFile;
use crate::storage::models::Chapter;
use std::collections::HashMap;

/// 从 EPUB 中提取章节信息（支持多级目录）
pub fn extract_chapters_from_epub(epub_file: &mut EpubFile) -> Vec<Chapter> {
    let toc = epub_file.toc();
    let spine = epub_file.spine();

    if toc.is_empty() {
        // 如果没有目录，使用 spine 生成简单章节
        return generate_chapters_from_spine(&spine);
    }

    // 构建 href 到索引的映射
    let href_map: HashMap<&str, usize> = spine
        .iter()
        .enumerate()
        .map(|(i, h)| (h.as_str(), i))
        .collect();

    let mut chapters = Vec::new();
    let mut chapter_id = 0i32;

    extract_toc_items(&toc, &href_map, &mut chapters, &mut chapter_id);

    chapters
}

fn extract_toc_items(
    items: &[(String, String)],
    href_map: &HashMap<&str, usize>,
    chapters: &mut Vec<Chapter>,
    chapter_id: &mut i32,
) {
    for (title, href) in items {
        let pure_href = href.split('#').next().unwrap_or(href);

        let index = href_map
            .get(pure_href)
            .copied()
            .unwrap_or(*chapter_id as usize);

        chapters.push(Chapter {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: String::new(),
            title: title.to_string(),
            start_index: index as i64,
            end_index: (index + 1) as i64,
            content_length: 0,
            chapter_index: *chapter_id,
            level: 0,
            content_file: String::new(),
            word_count: 0,
            cached_at: chrono::Utc::now(),
        });

        *chapter_id += 1;
    }
}

/// 从 spine 生成简单章节
fn generate_chapters_from_spine(spine: &[String]) -> Vec<Chapter> {
    spine
        .iter()
        .enumerate()
        .map(|(i, href)| {
            // 从 href 提取章节标题
            let title = extract_title_from_href(href);

            Chapter {
                id: uuid::Uuid::new_v4().to_string(),
                book_id: String::new(),
                title,
                start_index: i as i64,
                end_index: (i + 1) as i64,
                content_length: 0,
                chapter_index: i as i32,
                level: 0,
                content_file: String::new(),
                word_count: 0,
                cached_at: chrono::Utc::now(),
            }
        })
        .collect()
}

/// 从 href 提取标题
fn extract_title_from_href(href: &str) -> String {
    // 去掉路径和扩展名
    let filename = href.split('/').next_back().unwrap_or(href);
    let name = filename.split('.').next().unwrap_or(filename);

    // 尝试驼峰转空格
    let title = camel_to_spaces(name);

    // 首字母大写
    capitalize_first(&title)
}

/// 驼峰转空格
fn camel_to_spaces(s: &str) -> String {
    let mut result = String::new();
    for (i, c) in s.chars().enumerate() {
        if c.is_uppercase() && i > 0 {
            result.push(' ');
        }
        result.push(c);
    }
    result
}

/// 首字母大写
fn capitalize_first(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_camel_to_spaces() {
        assert_eq!(camel_to_spaces("ChapterOne"), "Chapter One");
        assert_eq!(camel_to_spaces("intro"), "intro");
    }

    #[test]
    fn test_capitalize_first() {
        assert_eq!(capitalize_first("hello"), "Hello");
        assert_eq!(capitalize_first("World"), "World");
    }

    #[test]
    fn test_extract_title_from_href() {
        assert_eq!(extract_title_from_href("chapter1.xhtml"), "Chapter1");
        assert_eq!(extract_title_from_href("path/to/intro.html"), "Intro");
    }
}
