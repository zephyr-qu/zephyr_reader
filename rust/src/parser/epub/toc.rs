// ============================================================
// 文件作用：EPUB table of contents extraction，从 NCX/Nav 文档提取章节信息，
//           支持多级 TOC。
//
// 公有类型/函数：
//   - extract_chapters_from_epub() — 从 EPUB 提取章节信息
//
// 私有函数：
//   - extract_toc_items() — 递归提取 TOC 条目
//   - generate_chapters_from_spine() — 无 TOC 时从 spine 生成章节
//   - extract_title_from_href() / camel_to_spaces() / capitalize_first()
// ============================================================

//! EPUB table of contents extraction
//! Extracts chapter information from NCX or Nav documents, supports multi-level TOC

use crate::domain::chapter::Chapter;
use super::archive_reader::EpubFile;

/// Extract chapter information from EPUB (supports multi-level TOC)
pub fn extract_chapters_from_epub(epub_file: &mut EpubFile, book_id: &str) -> Vec<Chapter> {
    let toc = epub_file.toc();
    let spine = epub_file.spine();

    tracing::info!(
        "[extract_chapters_from_epub] spine total: {}, toc total: {}",
        spine.len(),
        toc.len()
    );
    for (i, (label, href, lvl)) in toc.iter().enumerate() {
        tracing::info!(
            "[extract_chapters_from_epub]   toc[{i}]: label={label:?} href={href:?} level={lvl}"
        );
    }

    if toc.is_empty() {
        // If no TOC, generate simple chapters from spine
        let chapters = generate_chapters_from_spine(&spine, book_id);
        tracing::info!(
            "[extract_chapters_from_epub] No TOC, generating {} chapters from spine",
            chapters.len()
        );
        return chapters;
    }

    let mut chapters = Vec::new();
    let mut chapter_id = 0i32;

    extract_toc_items(epub_file, &toc, &mut chapters, &mut chapter_id, book_id);

    tracing::info!(
        "[extract_chapters_from_epub] Parsed {} chapters from TOC",
        chapters.len()
    );
    for ch in &chapters {
        tracing::info!(
            "[extract_chapters_from_epub]   ch[{}]: title={:?}, start_index={}",
            ch.chapter_index,
            ch.title,
            ch.start_index
        );
    }

    chapters
}

/// Maximum spine items per chapter before splitting into sub-chapters.
///
/// Some EPUBs have a flat TOC with one entry covering the entire book.
/// Without splitting, the chapter loads all spine items at once,
/// causing 30+ second freezes. This constant limits each chapter's
/// spine range so no single chapter has too many items.
const MAX_SPINE_ITEMS_PER_CHAPTER: i64 = 20;

fn extract_toc_items(
    epub_file: &EpubFile,
    items: &[(String, String, i32)],
    chapters: &mut Vec<Chapter>,
    chapter_id: &mut i32,
    book_id: &str,
) {
    let spine_len = epub_file.spine().len();
    let mut unmapped_count: usize = 0;
    let unmapped_total = items
        .iter()
        .filter(|(_, href, _)| {
            let pure = href.split('#').next().unwrap_or(href);
            epub_file.find_spine_index_by_toc_href(pure).is_none()
        })
        .count();

    for (title, href, level) in items {
        let pure_href = href.split('#').next().unwrap_or(href);

        let index = epub_file.find_spine_index_by_toc_href(pure_href).unwrap_or_else(|| {
            // Distribute failed entries sequentially across the spine.
            // Previously fell back to 0 unconditionally, causing all failed
            // entries to collapse into the same chapter (and possibly empty).
            let fallback = if unmapped_total > 0 && spine_len > 0 {
                let step = (spine_len as f64 / unmapped_total as f64).ceil() as usize;
                (step * unmapped_count).min(spine_len.saturating_sub(1))
            } else {
                0
            };
            unmapped_count += 1;
            tracing::warn!(
                "[extract_toc_items] cannot map TOC href '{pure_href}' to any spine item. \
                 Falling back to spine index {fallback} (unmapped #{unmapped_count}/{unmapped_total})."
            );
            fallback
        });

        chapters.push(Chapter::new(
            book_id,
            title,
            *chapter_id as i64,
            *level as i64,
            index as i64,
            0,
        ));

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

    // ── 分割超大章节 ──────────────────────────────────────────
    // 如果有章节覆盖的 spine 过多（如整本书只有一个 TOC 条目），
    // 按 MAX_SPINE_ITEMS_PER_CHAPTER 拆分成多个子章节。
    // 这确保后续阅读时的初始化时间可控。
    let mut split: Vec<Chapter> = Vec::with_capacity(chapters.len());
    for ch in chapters.drain(..) {
        let range = ch.end_index - ch.start_index;
        if range > MAX_SPINE_ITEMS_PER_CHAPTER {
            let num = (range + MAX_SPINE_ITEMS_PER_CHAPTER - 1) / MAX_SPINE_ITEMS_PER_CHAPTER;
            tracing::info!(
                "[extract_toc_items] splitting oversized chapter idx={} title={:?} \
                 ({} spines → {} sub-chapters)",
                ch.chapter_index,
                ch.title,
                range,
                num,
            );
            for i in 0..num {
                let cs = ch.start_index + i * MAX_SPINE_ITEMS_PER_CHAPTER;
                let ce = (cs + MAX_SPINE_ITEMS_PER_CHAPTER).min(ch.end_index);
                // First sub-chapter keeps the original chapter_index so the DB
                // reference stays valid. Subsequent sub-chapters get new indices.
                let sub_index = if i == 0 {
                    ch.chapter_index
                } else {
                    let idx = *chapter_id as i64;
                    *chapter_id += 1;
                    idx
                };
                let sub_title = format!("{} ({}/{})", ch.title, i + 1, num);
                split.push(Chapter::new(
                    &ch.book_id,
                    &sub_title,
                    sub_index,
                    ch.level,
                    cs,
                    ce,
                ));
            }
        } else {
            split.push(ch);
        }
    }
    *chapters = split;
}

/// 从 spine 生成简单章节
fn generate_chapters_from_spine(spine: &[String], book_id: &str) -> Vec<Chapter> {
    spine
        .iter()
        .enumerate()
        .map(|(i, href)| {
            // 从 href 提取章节标题
            let title = extract_title_from_href(href);

            Chapter::new(book_id, &title, i as i64, 0, i as i64, (i + 1) as i64)
            //  {
            //     id: uuid::Uuid::new_v4().to_string(),
            //     book_id: book_id.to_string(),
            //     title,
            //     start_index: i as i64,
            //     end_index: (i + 1) as i64,
            //     // content_length: 0,
            //     chapter_index: i as i64,
            //     level: 0,
            //     word_count: 0,
            //     cached_at: chrono::Utc::now(),
            // }
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
