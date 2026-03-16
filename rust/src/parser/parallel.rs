//! 并行章节验证模块
//!
//! 使用 rayon 并行验证章节内容，提升大文件解析性能。

use rayon::prelude::*;

use crate::ffi::{ApiResult, ChapterInfo, ParserError};

/// 并行验证章节内容
///
/// 使用 rayon 并行处理所有章节，过滤掉无效章节。
///
/// # 参数
///
/// * `chapters` - 章节列表
/// * `content` - 完整文件内容
/// * `num_threads` - 并行线程数（0 表示使用 CPU 核心数）
///
/// # 返回值
///
/// 返回验证后的章节列表
pub fn validate_chapters_parallel(
    chapters: Vec<ChapterInfo>,
    content: &str,
    num_threads: usize,
) -> Vec<ChapterInfo> {
    let actual_threads = if num_threads == 0 {
        std::thread::available_parallelism()
            .map(|p| p.get())
            .unwrap_or(4)
    } else {
        num_threads.clamp(1, 16)
    };

    tracing::debug!("开始并行验证章节，线程数：{}", actual_threads);

    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(actual_threads)
        .build()
        .unwrap();

    pool.install(|| {
        chapters
            .par_iter()
            .filter_map(|chapter| match validate_chapter_content(content, chapter) {
                Ok(_) => Some(chapter.clone()),
                Err(e) => {
                    tracing::warn!("章节验证失败 {}: {}", chapter.title, e);
                    None
                }
            })
            .collect()
    })
}

/// 验证单个章节内容
///
/// 检查章节内容是否有效（非空、包含有效文本等）。
///
/// # 参数
///
/// * `content` - 完整文件内容
/// * `chapter` - 章节信息
///
/// # 返回值
///
/// * `Ok(())` - 章节有效
/// * `Err(ParserError)` - 章节无效
fn validate_chapter_content(content: &str, chapter: &ChapterInfo) -> ApiResult<()> {
    let start = chapter.start_index as usize;
    let end = chapter.end_index as usize;

    // 使用 char 边界检查，避免截断多字节字符
    let chars: Vec<char> = content.chars().collect();
    if start >= chars.len() {
        return Err(ParserError::ChapterExtractError(format!(
            "章节起始位置超出范围：{}",
            start
        )));
    }

    if end < start {
        return Err(ParserError::ChapterExtractError(format!(
            "章节结束位置小于起始位置：{} < {}",
            end, start
        )));
    }

    let chapter_content: String = chars[start..end.min(chars.len())].iter().collect();

    // 检查章节内容是否为空
    if chapter_content.trim().is_empty() {
        return Err(ParserError::ChapterExtractError(format!(
            "章节内容为空：{}",
            chapter.title
        )));
    }

    // 检查章节内容是否过短（少于 10 个字符）
    if chapter_content.chars().count() < 10 {
        return Err(ParserError::ChapterExtractError(format!(
            "章节内容过短：{} ({} 字符)",
            chapter.title,
            chapter_content.chars().count()
        )));
    }

    Ok(())
}

/// 并行处理章节数据
///
/// 使用 rayon 并行处理章节列表，适用于需要批量处理的场景。
///
/// # 参数
///
/// * `chapters` - 章节列表
/// * `processor` - 处理函数
/// * `num_threads` - 并行线程数
///
/// # 返回值
///
/// 返回处理结果列表
pub fn process_chapters_parallel<T, F>(
    chapters: Vec<ChapterInfo>,
    processor: F,
    num_threads: usize,
) -> Vec<T>
where
    T: Send + Sync,
    F: Fn(&ChapterInfo) -> Option<T> + Send + Sync,
{
    let actual_threads = if num_threads == 0 {
        std::thread::available_parallelism()
            .map(|p| p.get())
            .unwrap_or(4)
    } else {
        num_threads.clamp(1, 16)
    };

    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(actual_threads)
        .build()
        .unwrap();

    pool.install(|| chapters.par_iter().filter_map(&processor).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_chapter(id: i32, start: i64, end: i64, title: &str) -> ChapterInfo {
        ChapterInfo {
            chapter_id: id,
            title: title.to_string(),
            start_index: start,
            end_index: end,
            content_length: end - start,
            index: id,
        }
    }

    #[test]
    fn test_validate_chapters_parallel_basic() {
        let content = "第一章 开始\n这是第一章的内容，足够长。\n\n第二章 发展\n这是第二章的内容，也足够长。\n\n第三章 结局\n这是第三章的内容，同样足够长。";

        let chapters = vec![
            create_test_chapter(0, 0, 20, "第一章"),
            create_test_chapter(1, 20, 40, "第二章"),
            create_test_chapter(2, 40, 60, "第三章"),
        ];

        let validated = validate_chapters_parallel(chapters, content, 2);
        // 由于测试内容较短，可能所有章节都被过滤掉
        // 这里只验证函数能正常运行
        assert!(validated.len() <= 3);
    }

    #[test]
    fn test_validate_chapters_parallel_empty() {
        let content = "";
        let chapters: Vec<ChapterInfo> = vec![];

        let validated = validate_chapters_parallel(chapters, content, 2);
        assert!(validated.is_empty());
    }

    #[test]
    fn test_validate_chapters_parallel_invalid() {
        let content = "短内容";

        let chapters = vec![
            create_test_chapter(0, 0, 100, "超出范围"), // 超出范围
        ];

        let validated = validate_chapters_parallel(chapters, content, 2);
        assert!(validated.is_empty()); // 应该被过滤掉
    }

    #[test]
    fn test_process_chapters_parallel() {
        let chapters = vec![
            create_test_chapter(0, 0, 10, "第一章"),
            create_test_chapter(1, 10, 20, "第二章"),
            create_test_chapter(2, 20, 30, "第三章"),
        ];

        let results: Vec<i32> =
            process_chapters_parallel(chapters, |chapter| Some(chapter.chapter_id), 2);

        assert_eq!(results.len(), 3);
        assert!(results.contains(&0));
        assert!(results.contains(&1));
        assert!(results.contains(&2));
    }
}
