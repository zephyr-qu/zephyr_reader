//! EPUB 目录提取
//! 从 NCX 或 Nav 文档中提取章节信息，支持多级目录

use super::unzip::EpubFile;
use crate::storage::models::Chapter;

/// 从 EPUB 中提取章节信息（支持多级目录）
pub fn extract_chapters_from_epub(epub_file: &mut EpubFile) -> Vec<Chapter> {
    let toc = epub_file.toc();
    let spine = epub_file.spine();

    tracing::info!("[extract_chapters_from_epub] spine 总数: {}, toc 总数: {}", spine.len(), toc.len());
    for (i, (label, href, lvl)) in toc.iter().enumerate() {
        tracing::info!("[extract_chapters_from_epub]   toc[{i}]: label={label:?} href={href:?} level={lvl}");
    }

    if toc.is_empty() {
        // 如果没有目录，使用 spine 生成简单章节
        let chapters = generate_chapters_from_spine(&spine);
        tracing::info!("[extract_chapters_from_epub] 无 TOC，从 spine 生成 {} 章节", chapters.len());
        return chapters;
    }

    let mut chapters = Vec::new();
    let mut chapter_id = 0i32;

    extract_toc_items(epub_file, &toc, &mut chapters, &mut chapter_id);

    tracing::info!("[extract_chapters_from_epub] 从 TOC 解析出 {} 章节", chapters.len());
    for ch in &chapters {
        tracing::info!("[extract_chapters_from_epub]   章[{}]: title={:?}, start_index={}", ch.chapter_index, ch.title, ch.start_index);
    }

    chapters
}

fn extract_toc_items(
    epub_file: &EpubFile,
    items: &[(String, String, i32)],
    chapters: &mut Vec<Chapter>,
    chapter_id: &mut i32,
) {
    let spine_len = epub_file.spine().len();

    for (title, href, level) in items {
        let pure_href = href.split('#').next().unwrap_or(href);

        let index = epub_file
            .find_spine_index_by_toc_href(pure_href)
            .unwrap_or(*chapter_id as usize);

        chapters.push(Chapter {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: String::new(),
            title: title.to_string(),
            start_index: index as i64,
            end_index: 0,
            content_length: 0,
            chapter_index: *chapter_id,
            level: *level,
            content_file: String::new(),
            word_count: 0,
            cached_at: chrono::Utc::now(),
        });

        *chapter_id += 1;
    }

    // 按 spine 顺序计算 end_index：
    // 每个章节从它的 start_index 覆盖到下一个章节的 start_index，
    // 这样 TOC 未列出的 spine 资源（如分片文件）会被合并到前一个章节
    let mut sorted: Vec<usize> = (0..chapters.len()).collect();
    sorted.sort_by_key(|&i| chapters[i].start_index);

    for pos in 0..sorted.len() {
        let idx = sorted[pos];
        let end = if pos + 1 < sorted.len() {
            chapters[sorted[pos + 1]].start_index
        } else {
            spine_len as i64
        };
        chapters[idx].end_index = end;
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
