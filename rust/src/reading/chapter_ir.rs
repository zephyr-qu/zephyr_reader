//! 章节 IR 加载（EPUB spine / TXT 字节界）。

use crate::domain::{AppError, ChapterContentIr};
use crate::storage::models::BookFormat;

use super::chapter_access::{format_from_file_path, get_chapter_bounds};

/// 加载整章 IR（与 `get_chapter_content_rich` / `get_chapter_content_ir` 边界一致）。
pub async fn load_chapter_content_ir(
    validated_path: &str,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    let format = format_from_file_path(validated_path)?;
    let (start, end) = get_chapter_bounds(validated_path, chapter_index).await?;
    let path = validated_path.to_string();

    match format {
        BookFormat::Epub => {
            tokio::task::spawn_blocking(move || {
                crate::parser::epub::get_chapter_content_ir(&path, start, end)
            })
            .await
            .map_err(|e| AppError::TaskPanic {
                task_name: "load_chapter_ir:epub".into(),
                details: e.to_string().into(),
            })?
        }
        BookFormat::Txt => {
            tokio::task::spawn_blocking(move || {
                crate::parser::txt::get_chapter_content_ir(&path, start, end)
            })
            .await
            .map_err(|e| AppError::TaskPanic {
                task_name: "load_chapter_ir:txt".into(),
                details: e.to_string().into(),
            })?
        }
    }
}
