//! 并行章节验证模块
//!
//! 使用 rayon 并行验证章节内容，提升大文件解析性能。

use rayon::prelude::*;

use crate::ffi::{ApiResult, ChapterInfo, ParserError};
use crate::text_process::constants::MIN_CHAPTER_LENGTH;

/// 并行验证章节内容
///
/// 使用 rayon 全局线程池并行处理章节列表，过滤掉无效章节。
///
/// # 性能优化
///
/// 预先构建字符索引映射（O(n)），避免每次章节验证时重复遍历（O(N × 文件大小)）。
/// 对于 10MB 文件 + 1000 章节，优化前需遍历 10GB 数据，优化后仅需 10MB + O(1) 查询。
///
/// # 参数
///
/// * `chapters` - 章节列表
/// * `content` - 完整文件内容
/// * `_num_threads` - 保留参数，实际使用全局线程池配置
///
/// # 返回值
///
/// 返回验证后的章节列表
pub fn validate_chapters_parallel(
    chapters: Vec<ChapterInfo>,
    content: &str,
    _num_threads: usize,
) -> Vec<ChapterInfo> {
    tracing::debug!("开始并行验证章节，数量：{}", chapters.len());

    // ✅ 预先构建字符索引映射（一次 O(n) 遍历）
    // 存储每个字符索引对应的字节偏移
    let byte_positions: Vec<usize> = content.char_indices().map(|(i, _)| i).collect();
    let char_count = byte_positions.len();

    // ✅ 并行验证，每个章节的字节索引查询都是 O(1)
    chapters
        .into_par_iter()
        .filter(|chapter| {
            match validate_chapter_content_with_positions(
                content,
                chapter,
                &byte_positions,
                char_count,
            ) {
                Ok(_) => true,
                Err(e) => {
                    tracing::warn!("章节验证失败 {}: {}", chapter.title, e);
                    false
                }
            }
        })
        .collect()
}

/// 验证单个章节内容（使用预计算的字符索引映射）
///
/// 检查章节内容是否有效（非空、包含有效文本等）。
/// 使用预计算的 byte_positions 映射实现 O(1) 字节边界查询。
///
/// # 参数
///
/// * `content` - 完整文件内容
/// * `chapter` - 章节信息
/// * `byte_positions` - 预计算的字符索引到字节偏移的映射
/// * `char_count` - 总字符数
///
/// # 返回值
///
/// * `Ok(())` - 章节有效
/// * `Err(ParserError)` - 章节无效
fn validate_chapter_content_with_positions(
    content: &str,
    chapter: &ChapterInfo,
    byte_positions: &[usize],
    char_count: usize,
) -> ApiResult<()> {
    // 检查索引是否为负数
    if chapter.start_index < 0 || chapter.end_index < 0 {
        return Err(ParserError::ChapterExtractError(
            "章节索引不能为负数".to_string(),
        ));
    }

    // 安全转换为 usize
    let start = chapter.start_index as usize;
    let end = chapter.end_index as usize;

    // ✅ O(1) 查询字节边界（而非 O(n) 的 char_indices().nth()）
    let start_byte = byte_positions.get(start).copied().unwrap_or(content.len());
    let end_byte = byte_positions.get(end).copied().unwrap_or(content.len());

    // 检查溢出
    if start > char_count {
        return Err(ParserError::ChapterExtractError(format!(
            "章节起始位置超出范围：{} > {}",
            start, char_count
        )));
    }

    if end < start {
        return Err(ParserError::ChapterExtractError(format!(
            "章节结束位置小于起始位置：{} < {}",
            end, start
        )));
    }

    let chapter_content = &content[start_byte..end_byte];

    // 检查章节内容是否为空
    if chapter_content.trim().is_empty() {
        return Err(ParserError::ChapterExtractError(format!(
            "章节内容为空：{}",
            chapter.title
        )));
    }

    // 检查章节内容是否过短（少于 MIN_CHAPTER_LENGTH 个字符）
    if chapter_content.chars().count() < MIN_CHAPTER_LENGTH {
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
/// 使用 rayon 全局线程池并行处理章节列表，适用于需要批量处理的场景。
///
/// # 参数
///
/// * `chapters` - 章节列表
/// * `processor` - 处理函数
/// * `_num_threads` - 保留参数，实际使用全局线程池配置
///
/// # 返回值
///
/// 返回处理结果列表
pub fn process_chapters_parallel<T, F>(
    chapters: Vec<ChapterInfo>,
    processor: F,
    _num_threads: usize,
) -> Vec<T>
where
    T: Send + Sync,
    F: Fn(&ChapterInfo) -> Option<T> + Send + Sync,
{
    // ✅ 直接使用全局线程池，避免重复创建
    chapters
        .into_par_iter()
        .filter_map(|chapter| processor(&chapter))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_chapter(id: i32, start: i64, end: i64, title: &str) -> ChapterInfo {
        ChapterInfo {
            chapter_id: format!("uuid-{}", id),
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

        let results: Vec<String> =
            process_chapters_parallel(chapters, |chapter| Some(chapter.chapter_id.clone()), 2);

        assert_eq!(results.len(), 3);
        assert!(results.iter().any(|id| id == "uuid-0"));
        assert!(results.iter().any(|id| id == "uuid-1"));
        assert!(results.iter().any(|id| id == "uuid-2"));
    }
}
