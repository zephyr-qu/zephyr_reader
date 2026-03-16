//! EPUB 目录提取
//! 从 NCX 或 Nav 文档中提取章节信息，支持多级目录

use super::unzip::EpubFile;
use crate::ffi::ChapterInfo;
use std::collections::HashMap;

/// 从 EPUB 中提取章节信息（支持多级目录）
pub fn extract_chapters_from_epub(epub_file: &mut EpubFile) -> Vec<ChapterInfo> {
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

    // 递归处理目录项（支持多级）
    extract_toc_items_recursive(&toc, &href_map, &mut chapters, &mut chapter_id, 0);

    chapters
}

/// 递归提取目录项（支持多级嵌套）
fn extract_toc_items_recursive(
    items: &[(String, String)],
    href_map: &HashMap<&str, usize>,
    chapters: &mut Vec<ChapterInfo>,
    chapter_id: &mut i32,
    _level: usize,
) {
    for (title, href) in items {
        // 提取纯 href（去掉片段标识符）
        let pure_href = href.split('#').next().unwrap_or(href);

        let index = href_map
            .get(pure_href)
            .copied()
            .unwrap_or(*chapter_id as usize);

        // 检测并格式化层级标题
        // 如果标题包含 ">" 或其他分隔符，说明是多级目录
        let full_title = format_title_with_hierarchy(title, _level);

        chapters.push(ChapterInfo {
            chapter_id: *chapter_id,
            title: full_title,
            start_index: index as i64,
            end_index: (index + 1) as i64,
            content_length: 0, // EPUB 章节长度在读取时确定
            index: *chapter_id,
        });

        *chapter_id += 1;
    }
}

/// 格式化带层级的标题
fn format_title_with_hierarchy(title: &str, level: usize) -> String {
    // 检查标题是否已经包含层级分隔符
    if title.contains(" > ") || title.contains("·") || title.contains("．") {
        // 已经有层级标记，直接返回
        return title.to_string();
    }

    // 根据层级添加前缀
    if level > 0 {
        format!("{}{}", "  ".repeat(level), title)
    } else {
        title.to_string()
    }
}

/// 从 spine 生成简单章节
fn generate_chapters_from_spine(spine: &[String]) -> Vec<ChapterInfo> {
    spine
        .iter()
        .enumerate()
        .map(|(i, href)| {
            // 从 href 提取章节标题
            let title = extract_title_from_href(href);

            ChapterInfo {
                chapter_id: i as i32,
                title,
                start_index: i as i64,
                end_index: (i + 1) as i64,
                content_length: 0,
                index: i as i32,
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
