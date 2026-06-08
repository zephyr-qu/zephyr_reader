//! 按需内容访问器
//!
//! 定义 `ChapterContentProvider` 和 `PagedContentProvider` 两个核心 trait，
//! 用于封装不同格式书籍的按需内容读取逻辑。
//!
//! 各格式 parser 实现这些 trait，API 层通过 trait object 统一访问，
//! 无需感知底层格式差异。

use crate::domain::AppError;
use crate::storage::models::BookFormat;

/// 章节内容的按需访问器
///
/// 提供基于偏移量的文本范围读取能力，支持按需/分块获取章节内容。
/// `start/end` 的语义因格式而异：
/// - TXT/MD: 字节偏移
/// - EPUB: (spine_index, inner_offset) 编码为 u64
/// - PDF: 不使用此 trait，改用 `PagedContentProvider`
pub trait ChapterContentProvider: Send + Sync {
    /// 获取指定偏移范围内的纯文本
    ///
    /// # 参数
    /// * `start` - 起始偏移量
    /// * `end` - 结束偏移量
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError>;

    /// 获取内容总长度
    fn content_length(&self) -> u64;

    /// 获取书籍格式
    fn format(&self) -> BookFormat;

    /// 是否支持分块排版（新路径）
    ///
    /// 返回 `true` 表示该格式的 Provider 实现了按需分块读取，
    /// API 层可走 `get_paginated_chunk` 路径。
    /// 未完成的格式返回 `false`，走旧的全量读取 + paginate_all 路径。
    fn supports_chunked_pagination(&self) -> bool {
        false
    }

    /// 获取指定偏移范围内的 HTML（仅支持 HTML 输出的格式覆盖此方法）
    ///
    /// 默认返回 `None`，表示不支持 HTML 输出。
    /// MD parser 可覆盖此方法返回 comrak 渲染的 HTML。
    fn read_html_range(&self, _start: u64, _end: u64) -> Option<Result<String, AppError>> {
        None
    }
}

/// 页面内容数据
#[derive(Debug, Clone)]
pub struct PageData {
    pub page_index: u32,
    pub text: String,
}

/// 支持原生分页的格式（如 PDF）的页面级访问器
///
/// TODO: Dart 侧尚未接入 PDF 阅读，此 trait 目前无活调用方
/// PDF 不适合字节范围读取，应走此 trait 独立路径。
pub trait PagedContentProvider: Send + Sync {
    /// 获取指定页面的文本内容
    fn get_page(&self, page_index: u32) -> Result<PageData, AppError>;

    /// 获取总页数
    fn total_pages(&self) -> u32;

    /// 预取相邻页面（默认空实现）
    ///
    /// 由 API 层在用户翻页后调用，传入当前页面索引，
    /// Provider 可异步预取后续页面到缓存。
    fn prefetch(&self, _page_index: u32) {}
}
