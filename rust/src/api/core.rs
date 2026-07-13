use crate::domain::{AppError, ChapterContentIr, TypesetConfig};
use crate::reading::orchestrator::ReadingOrchestrator;
use flutter_rust_bridge::frb;

/// 快速获取章节首段文本（仅读第一个 spine，不做分页）。
#[frb]
pub async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<crate::api::types::FirstSpineResult, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_first_spine_only(file_path, chapter_index)
        .await
}
/// 获取章节前 N 字符（惰性转换，只读取必要的 spine）。
#[frb]
pub async fn get_chapter_partial(
    file_path: String,
    chapter_index: i32,
    max_chars: u64,
) -> Result<String, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_partial(file_path, chapter_index, max_chars)
        .await
}
/// 获取指定章节的原始文本内容。
///
/// `_config` 参数保留以兼容 FRB 生成的代码；分页已迁移至 Flutter 侧，
/// Rust 仅返回原始文本（`ChapterContent::Raw`）。
#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
    _config: Option<TypesetConfig>,
) -> Result<crate::api::types::ChapterContent, AppError> {
    ReadingOrchestrator::global()
        .get_chapter(file_path, chapter_index)
        .await
}
/// 存储 Flutter 预计算的行断点（首屏 / scroll 预加载时填充）。
#[frb(sync)]
pub fn store_line_breaks(
    book_id: String,
    chapter_index: i32,
    config_hash: u64,
    line_breaks: Vec<u32>,
) -> Result<(), AppError> {
    ReadingOrchestrator::global()
        .store_line_breaks(book_id, chapter_index, config_hash, line_breaks)
}
/// Expose `TypesetConfig::config_hash()` to Dart.
#[frb(sync)]
pub fn compute_config_hash(config: TypesetConfig) -> u64 {
    config.config_hash()
}
/// Check if format supports chunked pagination.
#[frb(sync)]
pub fn supports_chunked_pagination(book_id: String) -> bool {
    tokio::runtime::Handle::try_current().is_ok_and(|handle| {
        handle.block_on(async {
            let pool = match crate::storage::storage_pool() {
                Ok(p) => p,
                Err(_) => return false,
            };
            match crate::storage::repos::BookRepository::find_by_id(&pool, &book_id).await {
                Ok(Some(book)) => matches!(book.format, crate::storage::models::BookFormat::Txt | crate::storage::models::BookFormat::Epub),
                _ => false,
            }
        })
    })
}
/// 加载整章 ContentBlock IR + plain 投影（scroll 路径；不创建 session）。
#[frb]
pub async fn get_chapter_content_ir(
    book_id: String,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_content_ir(book_id, chapter_index)
        .await
}
