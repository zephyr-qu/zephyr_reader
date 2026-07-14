use crate::domain::{AppError, ChapterContentIr};
use crate::reading::orchestrator::ReadingOrchestrator;
use flutter_rust_bridge::frb;

// ============================================================
// 文件作用：章节读取 API — 获取原始文本、IR、存储行断点。
//
// 公有函数：
//   - get_chapter() — 获取指定章节原始文本
//   - store_line_breaks() — 存储 Flutter 行断点
//   - get_chapter_content_ir() — 加载整章 ContentBlock IR
// ============================================================

/// 获取指定章节的原始文本内容。
/// 分页已迁移至 Flutter 侧，Rust 仅返回原始文本。
#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
) -> Result<String, AppError> {
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
