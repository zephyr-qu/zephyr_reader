// ============================================================
// 文件作用：定义 ChapterContentProvider trait，封装 EPUB/TXT 按需内容读取。
//
// 公有类型/函数：
//   - ChapterContentProvider — 章节内容的按需访问器 trait
//     - read_text_range() — 读取指定字节范围文本
//     - content_length() — 获取内容总长度
//     - format() — 获取格式
//     - read_html_range() — 读取 HTML 范围（可选）
// ============================================================

//! 按需内容访问器
//!
//! 定义 `ChapterContentProvider` trait，用于封装 EPUB/TXT 的按需内容读取。

use crate::domain::book::BookFormat;
use crate::domain::AppError;

/// 章节内容的按需访问器
///
/// `start/end` 的语义因格式而异：
/// - TXT: 字节偏移
/// - EPUB: provider 已按 spine 范围限定，`content_length` 为章内总字节数
pub trait ChapterContentProvider: Send + Sync {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError>;

    fn content_length(&self) -> u64;

    fn format(&self) -> BookFormat;

    fn read_html_range(&self, _start: u64, _end: u64) -> Option<Result<String, AppError>> {
        None
    }
}
