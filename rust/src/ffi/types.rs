//! FFI 数据类型定义
//! 与 Flutter 侧对齐的数据结构

use crate::ffi::error::TypesetConfigError;
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::hash::{Hash, Hasher};

/// 解析配置
///
/// 用于控制解析器的行为，包括并行处理、缓存等选项。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb]
pub struct ParseConfig {
    /// 是否启用并行解析（多章节同时处理）
    pub enable_parallel: bool,
    /// 并行处理的线程数（0 表示使用 CPU 核心数）
    pub parallel_threads: usize,
    /// 是否启用缓存
    pub enable_cache: bool,
    /// 缓存最大条目数
    pub cache_max_entries: usize,
}

impl Default for ParseConfig {
    fn default() -> Self {
        Self {
            enable_parallel: true,
            parallel_threads: 0, // 0 表示使用 CPU 核心数
            enable_cache: true,
            cache_max_entries: 100,
        }
    }
}

impl ParseConfig {
    /// 获取实际的线程数
    ///
    /// 如果配置为 0，返回 CPU 核心数；否则返回配置值。
    pub fn get_thread_count(&self) -> usize {
        if self.parallel_threads == 0 {
            std::thread::available_parallelism()
                .map(|p| p.get())
                .unwrap_or(4)
        } else {
            self.parallel_threads.clamp(1, 16)
        }
    }

    /// 验证配置并修复无效值
    pub fn validate_and_fix(&mut self) {
        self.parallel_threads = self.parallel_threads.clamp(0, 16);
        self.cache_max_entries = self.cache_max_entries.clamp(1, 10000);
    }
}

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
    Pdf,
}

/// 文本语言类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Hash)]
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
    /// 是否启用英文连字符
    pub enable_hyphenation: bool,
    /// 连字符语言（如 "en-us", "en-gb"）
    pub hyphenation_language: Option<String>,
}

impl Default for TypesetConfig {
    /// 创建默认排版配置
    ///
    /// 默认值：
    /// - 页面尺寸：1080 x 1920 像素（标准手机屏幕）
    /// - 字体大小：18 像素
    /// - 行间距：1.5
    /// - 首行缩进：2 字符
    /// - 连字符：禁用
    fn default() -> Self {
        Self {
            page_width: 1080,
            page_height: 1920,
            font_size: 18,
            line_spacing: 1.5,
            letter_spacing: 0.0,
            paragraph_spacing: 1.0,
            first_line_indent: 2,
            language: LanguageType::Auto,
            enable_hyphenation: false,
            hyphenation_language: None,
        }
    }
}

impl Hash for TypesetConfig {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.page_width.hash(state);
        self.page_height.hash(state);
        self.font_size.hash(state);
        // f32 需要转换为比特位进行哈希
        self.line_spacing.to_bits().hash(state);
        self.letter_spacing.to_bits().hash(state);
        self.paragraph_spacing.to_bits().hash(state);
        self.first_line_indent.hash(state);
        self.language.hash(state);
        self.enable_hyphenation.hash(state);
        // Option<String> 也需要哈希
        self.hyphenation_language.hash(state);
    }
}

/// 排版配置修复报告
///
/// 包含修复后的配置和所有修正项的描述
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct TypesetConfigFixReport {
    /// 修复后的配置
    pub fixed_config: TypesetConfig,
    /// 修正项描述列表
    pub fixes: Vec<String>,
}

impl TypesetConfig {
    /// 验证配置参数的有效性
    ///
    /// # 返回值
    ///
    /// * `Ok(())` - 配置有效
    /// * `Err(TypesetConfigError)` - 配置无效，包含具体错误信息
    ///
    /// # 验证规则
    ///
    /// - 页面宽度：100 - 10000 像素
    /// - 页面高度：100 - 10000 像素
    /// - 字体大小：8 - 100 像素
    /// - 行间距：0.5 - 5.0
    /// - 字间距：-10.0 - 10.0
    /// - 段落间距：0.0 - 10.0
    /// - 首行缩进：0 - 10 字符
    ///
    /// # 示例
    ///
    /// ```rust
    /// use rust_lib_zephyr_reader::ffi::TypesetConfig;
    ///
    /// let config = TypesetConfig::default();
    /// assert!(config.validate().is_ok());
    ///
    /// let invalid_config = TypesetConfig {
    ///     font_size: 200, // 超出范围
    ///     ..Default::default()
    /// };
    /// assert!(invalid_config.validate().is_err());
    /// ```
    #[frb(sync)]
    pub fn validate(&self) -> Result<(), TypesetConfigError> {
        if self.page_width < 100 || self.page_width > 10000 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "页面宽度必须在 100-10000 像素之间，当前值：{}",
                self.page_width
            )));
        }

        if self.page_height < 100 || self.page_height > 10000 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "页面高度必须在 100-10000 像素之间，当前值：{}",
                self.page_height
            )));
        }

        if self.font_size < 8 || self.font_size > 100 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "字体大小必须在 8-100 像素之间，当前值：{}",
                self.font_size
            )));
        }

        if self.line_spacing < 0.5 || self.line_spacing > 5.0 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "行间距必须在 0.5-5.0 之间，当前值：{}",
                self.line_spacing
            )));
        }

        if self.letter_spacing < -10.0 || self.letter_spacing > 10.0 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "字间距必须在 -10.0 到 10.0 之间，当前值：{}",
                self.letter_spacing
            )));
        }

        if self.paragraph_spacing < 0.0 || self.paragraph_spacing > 10.0 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "段落间距必须在 0.0-10.0 之间，当前值：{}",
                self.paragraph_spacing
            )));
        }

        if self.first_line_indent > 10 {
            return Err(TypesetConfigError::InvalidParameter(format!(
                "首行缩进必须在 0-10 字符之间，当前值：{}",
                self.first_line_indent
            )));
        }

        Ok(())
    }

    /// 验证并修复配置参数到有效范围
    ///
    /// 如果参数超出范围，会自动调整为最接近的有效值。
    ///
    /// # 返回值
    ///
    /// 返回修复后的配置
    #[frb(sync)]
    pub fn validate_and_fix(&self) -> TypesetConfig {
        TypesetConfig {
            page_width: self.page_width.clamp(100, 10000),
            page_height: self.page_height.clamp(100, 10000),
            font_size: self.font_size.clamp(8, 100),
            line_spacing: self.line_spacing.clamp(0.5, 5.0),
            letter_spacing: self.letter_spacing.clamp(-10.0, 10.0),
            paragraph_spacing: self.paragraph_spacing.clamp(0.0, 10.0),
            first_line_indent: self.first_line_indent.clamp(0, 10),
            language: self.language.clone(),
            enable_hyphenation: self.enable_hyphenation,
            hyphenation_language: self.hyphenation_language.clone(),
        }
    }

    /// 验证配置并返回修复报告
    ///
    /// 如果参数超出范围，会自动调整为最接近的有效值，并返回详细的修复报告。
    ///
    /// # 返回值
    ///
    /// 返回 `(TypesetConfig, TypesetConfigFixReport)` 元组，包含：
    /// - 修复后的配置
    /// - 修复报告（包含所有修正项描述）
    ///
    /// # 示例
    ///
    /// ```rust
    /// use rust_lib_zephyr_reader::ffi::TypesetConfig;
    ///
    /// let config = TypesetConfig {
    ///     font_size: 200, // 超出范围
    ///     page_width: 50,  // 低于最小值
    ///     ..Default::default()
    /// };
    ///
    /// let (fixed, report) = config.validate_and_report();
    /// assert_eq!(fixed.font_size, 100); // 被修复为最大值
    /// assert_eq!(fixed.page_width, 100); // 被修复为最小值
    /// assert!(!report.fixes.is_empty()); // 有修复项
    /// ```
    #[frb(sync)]
    pub fn validate_and_report(&self) -> (TypesetConfig, TypesetConfigFixReport) {
        let mut fixes = Vec::new();

        let fixed_config = TypesetConfig {
            page_width: {
                let original = self.page_width;
                let fixed = self.page_width.clamp(100, 10000);
                if original != fixed {
                    fixes.push(format!(
                        "页面宽度：{} -> {} (限制在 100-10000 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            page_height: {
                let original = self.page_height;
                let fixed = self.page_height.clamp(100, 10000);
                if original != fixed {
                    fixes.push(format!(
                        "页面高度：{} -> {} (限制在 100-10000 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            font_size: {
                let original = self.font_size;
                let fixed = self.font_size.clamp(8, 100);
                if original != fixed {
                    fixes.push(format!(
                        "字体大小：{} -> {} (限制在 8-100 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            line_spacing: {
                let original = self.line_spacing;
                let fixed = self.line_spacing.clamp(0.5, 5.0);
                if original != fixed {
                    fixes.push(format!(
                        "行间距：{} -> {} (限制在 0.5-5.0 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            letter_spacing: {
                let original = self.letter_spacing;
                let fixed = self.letter_spacing.clamp(-10.0, 10.0);
                if original != fixed {
                    fixes.push(format!(
                        "字间距：{} -> {} (限制在 -10.0-10.0 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            paragraph_spacing: {
                let original = self.paragraph_spacing;
                let fixed = self.paragraph_spacing.clamp(0.0, 10.0);
                if original != fixed {
                    fixes.push(format!(
                        "段落间距：{} -> {} (限制在 0.0-10.0 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            first_line_indent: {
                let original = self.first_line_indent;
                let fixed = self.first_line_indent.clamp(0, 10);
                if original != fixed {
                    fixes.push(format!(
                        "首行缩进：{} -> {} (限制在 0-10 范围内)",
                        original, fixed
                    ));
                }
                fixed
            },
            language: self.language.clone(),
            enable_hyphenation: self.enable_hyphenation,
            hyphenation_language: self.hyphenation_language.clone(),
        };

        let report = TypesetConfigFixReport {
            fixed_config: fixed_config.clone(),
            fixes,
        };

        (fixed_config, report)
    }
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

/// 本地书籍信息（用于文件选择后展示）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct LocalBookInfo {
    /// 文件路径
    pub file_path: String,
    /// 文件大小（字节）
    pub file_size: i64,
    /// 书籍标题
    pub title: String,
    /// 作者
    pub author: String,
    /// 描述/简介
    pub description: String,
    /// 封面路径
    pub cover_path: Option<String>,
    /// 章节数量
    pub chapter_count: i32,
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

/// EPUB 目录项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubTocItem {
    /// 目录标题
    pub label: String,
    /// 目录链接
    pub href: String,
}

/// EPUB 元数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubMetadata {
    /// 书籍标题
    pub title: String,
    /// 作者
    pub author: String,
    /// 封面路径
    pub cover_path: Option<String>,
    /// 目录
    pub toc: Vec<EpubTocItem>,
    /// 阅读顺序（spine）
    pub spine: Vec<String>,
}

/// PDF 元数据
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[frb(non_opaque)]
pub struct PdfMetadata {
    /// 文档标题
    pub title: Option<String>,
    /// 文档作者
    pub author: Option<String>,
    /// 文档主题
    pub subject: Option<String>,
    /// 创建者（生成 PDF 的软件）
    pub creator: Option<String>,
    /// 页数
    pub page_count: i32,
}

/// 阅读统计数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ReadingStats {
    /// 总阅读时长（秒）
    pub total_reading_time_seconds: i64,
    /// 总阅读字数
    pub total_characters_read: i64,
    /// 阅读书籍数量
    pub books_read_count: i32,
    /// 完成阅读书籍数量
    pub books_completed_count: i32,
    /// 连续阅读天数
    pub consecutive_reading_days: i32,
    /// 今日阅读时长（秒）
    pub today_reading_time_seconds: i64,
    /// 今日阅读字数
    pub today_characters_read: i64,
    /// 平均阅读速度（字/分钟）
    pub average_reading_speed: f32,
}

impl Default for ReadingStats {
    fn default() -> Self {
        Self {
            total_reading_time_seconds: 0,
            total_characters_read: 0,
            books_read_count: 0,
            books_completed_count: 0,
            consecutive_reading_days: 0,
            today_reading_time_seconds: 0,
            today_characters_read: 0,
            average_reading_speed: 0.0,
        }
    }
}

/// 每日阅读记录
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct DailyReadingRecord {
    /// 日期（YYYY-MM-DD 格式）
    pub date: String,
    /// 阅读时长（秒）
    pub reading_time_seconds: i64,
    /// 阅读字数
    pub characters_read: i64,
    /// 阅读章节数
    pub chapters_read: i32,
    /// 阅读页数
    pub pages_read: i32,
}

/// 阅读会话记录（单次连续阅读）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ReadingSession {
    /// 会话 ID
    pub session_id: String,
    /// 书籍 ID
    pub book_id: String,
    /// 章节 ID
    pub chapter_id: i32,
    /// 开始时间戳
    pub start_timestamp: i64,
    /// 结束时间戳
    pub end_timestamp: i64,
    /// 阅读时长（秒）
    pub duration_seconds: i64,
    /// 阅读字数
    pub characters_read: i64,
}

/// 排版缓存中的页面偏移量
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageOffset {
    /// 字符偏移量（在原始内容中的位置）
    pub offset: i64,
    /// 页面长度（字符数）
    pub length: i64,
}

/// 缓存的排版结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct CachedLayout {
    /// 章节 ID
    pub chapter_id: i32,
    /// 排版配置哈希
    pub config_hash: String,
    /// 页面偏移量列表
    pub page_offsets: Vec<PageOffset>,
    /// 总页数
    pub total_pages: i32,
    /// 创建时间戳
    pub created_at: i64,
}

/// 排版缓存查询结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct LayoutCacheResult {
    /// 是否命中缓存
    pub hit: bool,
    /// 缓存的排版结果（如果命中）
    pub cached_layout: Option<CachedLayout>,
}

// ==================== 富文本支持 ====================

/// 富文本片段类型
///
/// 用于表示带有样式的文本片段，支持加粗、斜体等基础样式。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub enum RichTextSpan {
    /// 纯文本
    Plain { text: String },
    /// 粗体
    Bold { text: String },
    /// 斜体
    Italic { text: String },
    /// 粗体 + 斜体
    BoldItalic { text: String },
    /// 下划线
    Underline { text: String },
    /// 删除线
    Strikethrough { text: String },
    /// 行内代码
    Code { text: String },
    /// 超链接
    Link { text: String, url: String },
}

impl RichTextSpan {
    /// 获取文本内容
    pub fn text(&self) -> &str {
        match self {
            Self::Plain { text } => text,
            Self::Bold { text } => text,
            Self::Italic { text } => text,
            Self::BoldItalic { text } => text,
            Self::Underline { text } => text,
            Self::Strikethrough { text } => text,
            Self::Code { text } => text,
            Self::Link { text, .. } => text,
        }
    }

    /// 判断是否为纯文本
    pub fn is_plain(&self) -> bool {
        matches!(self, Self::Plain { .. })
    }
}

/// 富文本段落
///
/// 由多个富文本片段组成的段落，支持首行缩进和标题标记。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct RichParagraph {
    /// 文本片段列表
    pub spans: Vec<RichTextSpan>,
    /// 首行缩进字符数
    pub indent: u8,
    /// 是否为标题
    pub is_heading: bool,
    /// 标题层级（1-6，0 表示非标题）
    pub heading_level: u8,
    /// 段落样式类名（来自 HTML class 属性）
    pub class_name: Option<String>,
}

impl RichParagraph {
    /// 创建纯文本段落
    pub fn plain(text: String, indent: u8) -> Self {
        Self {
            spans: vec![RichTextSpan::Plain { text }],
            indent,
            is_heading: false,
            heading_level: 0,
            class_name: None,
        }
    }

    /// 创建标题段落
    pub fn heading(text: String, level: u8) -> Self {
        Self {
            spans: vec![RichTextSpan::Bold { text }],
            indent: 0,
            is_heading: true,
            heading_level: level,
            class_name: None,
        }
    }

    /// 获取完整文本内容（不含样式）
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text()).collect()
    }
}

/// 富文本章节内容
///
/// 包含完整章节的富文本结构化数据。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct RichChapterContent {
    /// 章节 ID
    pub chapter_id: i32,
    /// 段落列表
    pub paragraphs: Vec<RichParagraph>,
    /// 总字符数（不含样式标记）
    pub total_characters: i64,
}

impl RichChapterContent {
    /// 转换为纯文本
    pub fn to_plain_text(&self) -> String {
        self.paragraphs
            .iter()
            .map(|p| p.full_text())
            .collect::<Vec<_>>()
            .join("\n\n")
    }
}

// ==================== 全文搜索支持 ====================

/// 搜索结果项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct SearchHit {
    /// 章节 ID
    pub chapter_id: i32,
    /// 章节标题
    pub chapter_title: String,
    /// 匹配的文本片段
    pub snippet: String,
    /// 匹配位置（字符偏移）
    pub position: i64,
    /// 相关度评分
    pub score: f32,
}

/// 搜索结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct SearchResults {
    /// 总匹配数
    pub total_hits: i32,
    /// 搜索结果列表
    pub hits: Vec<SearchHit>,
    /// 搜索耗时（毫秒）
    pub elapsed_ms: i64,
}

// ==================== 双语对齐支持 ====================

/// 对齐的双语片段
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct AlignedSegment {
    /// 中文内容
    pub chinese: String,
    /// 英文内容
    pub english: String,
    /// 相似度评分 (0.0 - 1.0)
    pub similarity_score: f32,
    /// 中文在原文中的位置
    pub chinese_position: usize,
    /// 英文在原文中的位置
    pub english_position: usize,
}

/// 双语对齐结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BilingualAlignment {
    /// 对齐的片段列表
    pub segments: Vec<AlignedSegment>,
    /// 未对齐的中文片段
    pub unmatched_chinese: Vec<String>,
    /// 未对齐的英文片段
    pub unmatched_english: Vec<String>,
}

// ==================== EPUB 图片支持 ====================

/// 图片格式枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum ImageFormat {
    /// JPEG
    Jpeg,
    /// PNG
    Png,
    /// GIF
    Gif,
    /// WebP
    Webp,
    /// BMP
    Bmp,
    /// SVG
    Svg,
    /// 未知格式
    Unknown,
}

impl ImageFormat {
    /// 从文件扩展名判断图片格式
    pub fn from_extension(ext: &str) -> Self {
        match ext.to_lowercase().as_str() {
            ".jpg" | ".jpeg" => ImageFormat::Jpeg,
            ".png" => ImageFormat::Png,
            ".gif" => ImageFormat::Gif,
            ".webp" => ImageFormat::Webp,
            ".bmp" => ImageFormat::Bmp,
            ".svg" => ImageFormat::Svg,
            _ => ImageFormat::Unknown,
        }
    }

    /// 获取 MIME 类型
    pub fn mime_type(&self) -> &'static str {
        match self {
            ImageFormat::Jpeg => "image/jpeg",
            ImageFormat::Png => "image/png",
            ImageFormat::Gif => "image/gif",
            ImageFormat::Webp => "image/webp",
            ImageFormat::Bmp => "image/bmp",
            ImageFormat::Svg => "image/svg+xml",
            ImageFormat::Unknown => "application/octet-stream",
        }
    }

    /// 获取文件扩展名
    pub fn extension(&self) -> &'static str {
        match self {
            ImageFormat::Jpeg => "jpg",
            ImageFormat::Png => "png",
            ImageFormat::Gif => "gif",
            ImageFormat::Webp => "webp",
            ImageFormat::Bmp => "bmp",
            ImageFormat::Svg => "svg",
            ImageFormat::Unknown => "bin",
        }
    }
}

/// EPUB 中的图片资源信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubImageInfo {
    /// 图片资源的 href（唯一标识）
    pub href: String,
    /// 文件名
    pub filename: String,
    /// 图片格式
    pub format: ImageFormat,
    /// 文件大小（字节）
    pub size_bytes: i64,
    /// 图片宽度（像素），如果无法解析则为 None
    pub width: Option<i32>,
    /// 图片高度（像素），如果无法解析则为 None
    pub height: Option<i32>,
}

/// EPUB 图片列表
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubImageList {
    /// 图片总数
    pub total_count: i32,
    /// 图片信息列表
    pub images: Vec<EpubImageInfo>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_typeset_config_validate_and_report_no_fixes() {
        let config = TypesetConfig::default();
        let (fixed, report) = config.validate_and_report();

        assert_eq!(fixed.page_width, config.page_width);
        assert_eq!(fixed.font_size, config.font_size);
        assert!(report.fixes.is_empty());
    }

    #[test]
    fn test_typeset_config_validate_and_report_with_fixes() {
        let config = TypesetConfig {
            font_size: 200,    // 超出范围
            page_width: 50,    // 低于最小值
            line_spacing: 6.0, // 超出范围
            ..Default::default()
        };

        let (fixed, report) = config.validate_and_report();

        // 验证修复后的值
        assert_eq!(fixed.font_size, 100); // 被修复为最大值
        assert_eq!(fixed.page_width, 100); // 被修复为最小值
        assert_eq!(fixed.line_spacing, 5.0); // 被修复为最大值

        // 验证修复报告
        assert_eq!(report.fixes.len(), 3);
        assert!(report.fixes.iter().any(|f| f.contains("字体大小")));
        assert!(report.fixes.iter().any(|f| f.contains("页面宽度")));
        assert!(report.fixes.iter().any(|f| f.contains("行间距")));
    }

    #[test]
    fn test_typeset_config_validate_invalid() {
        let config = TypesetConfig {
            font_size: 200, // 超出范围
            ..Default::default()
        };

        let result = config.validate();
        assert!(result.is_err());
    }

    #[test]
    fn test_typeset_config_fix_report_structure() {
        let config = TypesetConfig::default();
        let (fixed, report) = config.validate_and_report();

        // 验证报告结构
        assert_eq!(report.fixed_config.page_width, fixed.page_width);
        assert_eq!(report.fixed_config.font_size, fixed.font_size);
    }

    #[test]
    fn test_image_format_from_extension() {
        assert_eq!(ImageFormat::from_extension(".jpg"), ImageFormat::Jpeg);
        assert_eq!(ImageFormat::from_extension(".jpeg"), ImageFormat::Jpeg);
        assert_eq!(ImageFormat::from_extension(".png"), ImageFormat::Png);
        assert_eq!(ImageFormat::from_extension(".gif"), ImageFormat::Gif);
        assert_eq!(ImageFormat::from_extension(".webp"), ImageFormat::Webp);
        assert_eq!(ImageFormat::from_extension(".bmp"), ImageFormat::Bmp);
        assert_eq!(ImageFormat::from_extension(".svg"), ImageFormat::Svg);
        assert_eq!(ImageFormat::from_extension("unknown"), ImageFormat::Unknown);
    }

    #[test]
    fn test_image_format_mime_type() {
        assert_eq!(ImageFormat::Jpeg.mime_type(), "image/jpeg");
        assert_eq!(ImageFormat::Png.mime_type(), "image/png");
        assert_eq!(ImageFormat::Gif.mime_type(), "image/gif");
        assert_eq!(ImageFormat::Webp.mime_type(), "image/webp");
        assert_eq!(ImageFormat::Bmp.mime_type(), "image/bmp");
        assert_eq!(ImageFormat::Svg.mime_type(), "image/svg+xml");
        assert_eq!(ImageFormat::Unknown.mime_type(), "application/octet-stream");
    }
}
