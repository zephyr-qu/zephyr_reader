//! Markdown 相关 API
//!
//! 提供 Markdown 特有的功能，如富文本章节解析。
//! 通用解析功能请使用 core::parse_book。

use crate::domain::{AppError, RichParagraph};
use crate::parser::registry::parser_for_file;
use crate::text::rich_text;
use crate::utils::security::validate_file_path;
use flutter_rust_bridge::frb;

/// 获取 Markdown 章节富文本内容
///
/// 解析 Markdown 章节为富文本格式（粗体、斜体、代码、链接等）。
/// 内部使用 comrak 将 Markdown 转换为 HTML，再通过 HTML→RichParagraph 管道处理。
///
/// # 参数
/// * `file_path` - Markdown 文件路径
/// * `chapter_index` - 章节索引
///
/// # 返回值
/// * `Ok(Vec<RichParagraph>)` - 富文本段落列表
/// * `Err(AppError)` - 解析失败
#[frb]
pub async fn get_md_chapter_rich_content(
    file_path: String,
    chapter_index: i32,
) -> Result<Vec<RichParagraph>, AppError> {
    tracing::info!("[md] get_md_chapter_rich_content: file_path={}, chapter_index={}", file_path, chapter_index);
    let validated_path = validate_file_path(&file_path)?;

    let parser = parser_for_file(&validated_path)?;
    let html = parser
        .extract_chapter(&validated_path, chapter_index)
        .await?;

    rich_text::parse_html_to_rich_text(&html)
}
