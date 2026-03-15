//! FFI 数据类型定义
//! 与 Flutter 侧对齐的数据结构

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 书籍信息结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BookInfo {
    /// 书籍唯一标识
    pub book_id: String,
    /// 书籍标题
    pub title: String,
    /// 作者
    pub author: String,
    /// 章节数量
    pub chapter_count: i32,
    /// 总字符数
    pub total_characters: i64,
    /// 文件路径
    pub file_path: String,
    /// 文件类型 (txt/epub)
    pub file_type: String,
    /// 封面图片路径（EPUB 特有）
    pub cover_path: Option<String>,
}

/// 章节信息结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ChapterInfo {
    /// 章节唯一标识
    pub chapter_id: i32,
    /// 章节标题
    pub title: String,
    /// 章节在文件中的起始位置
    pub start_index: i64,
    /// 章节在文件中的结束位置
    pub end_index: i64,
    /// 章节内容长度
    pub content_length: i64,
    /// 章节序号
    pub index: i32,
}

/// 分页内容结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageContent {
    /// 章节 ID
    pub chapter_id: i32,
    /// 页码
    pub page_index: i32,
    /// 页面内容
    pub content: String,
    /// 是否为最后一页
    pub is_last_page: bool,
}

// 排版后的文本块（暂未使用）
// #[derive(Debug, Clone, Serialize, Deserialize)]
// #[frb(non_opaque)]
// pub struct TypesetBlock {
//     /// 文本内容
//     pub text: String,
//     /// 是否为标题
//     pub is_heading: bool,
//     /// 标题层级 (1-6)
//     pub heading_level: u8,
//     /// 段落缩进（字符数）
//     pub indent: u8,
// }

/// 文件类型枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum FileType {
    Txt,
    Epub,
}

/// 文本语言类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum LanguageType {
    /// 中文
    Chinese,
    /// 英文
    English,
    /// 混合
    Mixed,
    /// 自动检测
    Auto,
}

/// 排版配置
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct TypesetConfig {
    /// 页面宽度（像素）
    pub page_width: i32,
    /// 页面高度（像素）
    pub page_height: i32,
    /// 字体大小（像素）
    pub font_size: i32,
    /// 行间距
    pub line_spacing: f32,
    /// 字间距
    pub letter_spacing: f32,
    /// 段落间距
    pub paragraph_spacing: f32,
    /// 首行缩进字符数
    pub first_line_indent: u8,
    /// 语言类型
    pub language: LanguageType,
}

/// 解析结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ParseResult {
    /// 书籍信息
    pub book_info: BookInfo,
    /// 章节列表
    pub chapters: Vec<ChapterInfo>,
}

/// 阅读进度信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ReadingProgress {
    /// 当前章节 ID
    pub chapter_id: i32,
    /// 当前页码
    pub page_index: i32,
    /// 总页数
    pub total_pages: i32,
    /// 进度百分比（0.0 - 1.0）
    pub progress: f32,
    /// 已阅读时间（秒）
    pub reading_time_seconds: i64,
    /// 最后阅读时间戳（Unix 时间戳）
    pub last_read_timestamp: i64,
}

impl Default for ReadingProgress {
    fn default() -> Self {
        Self {
            chapter_id: 0,
            page_index: 0,
            total_pages: 0,
            progress: 0.0,
            reading_time_seconds: 0,
            last_read_timestamp: 0,
        }
    }
}

/// 书签信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct Bookmark {
    /// 书签唯一标识
    pub bookmark_id: String,
    /// 书籍 ID
    pub book_id: String,
    /// 章节 ID
    pub chapter_id: i32,
    /// 页码
    pub page_index: i32,
    /// 书签标题（用户自定义或自动生成）
    pub title: String,
    /// 创建时间戳（Unix 时间戳）
    pub created_timestamp: i64,
    /// 备注
    pub note: Option<String>,
}
