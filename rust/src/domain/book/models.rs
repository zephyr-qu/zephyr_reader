use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 图片格式
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum ImageFormat {
    /// JPEG 格式
    Jpeg,
    /// PNG 格式
    Png,
    /// GIF 格式
    Gif,
    /// WebP 格式
    Webp,
    /// BMP 格式
    Bmp,
    /// SVG 格式
    Svg,
    /// 未知格式
    Unknown,
}

impl ImageFormat {
    /// 根据文件扩展名识别图片格式
    ///
    /// # 参数
    /// - `ext`: 文件扩展名（可含前导点号，如 `.jpg` 或 `jpg`）
    ///
    /// # 返回值
    /// 返回匹配的 ImageFormat，无法识别时返回 `Unknown`
    pub fn from_extension(ext: &str) -> Self {
        let ext = ext.strip_prefix('.').unwrap_or(ext);
        match ext.to_lowercase().as_str() {
            "jpg" | "jpeg" => ImageFormat::Jpeg,
            "png" => ImageFormat::Png,
            "gif" => ImageFormat::Gif,
            "webp" => ImageFormat::Webp,
            "bmp" => ImageFormat::Bmp,
            "svg" => ImageFormat::Svg,
            _ => ImageFormat::Unknown,
        }
    }

    /// 获取图片格式对应的 MIME 类型字符串
    pub fn mime_type(&self) -> String {
        match self {
            ImageFormat::Jpeg => "image/jpeg",
            ImageFormat::Png => "image/png",
            ImageFormat::Gif => "image/gif",
            ImageFormat::Webp => "image/webp",
            ImageFormat::Bmp => "image/bmp",
            ImageFormat::Svg => "image/svg+xml",
            ImageFormat::Unknown => "application/octet-stream",
        }
        .to_string()
    }
    /// 获取图片格式对应的标准文件扩展名（不含点号）
    pub fn extension(&self) -> String {
        match self {
            ImageFormat::Jpeg => "jpg",
            ImageFormat::Png => "png",
            ImageFormat::Gif => "gif",
            ImageFormat::Webp => "webp",
            ImageFormat::Bmp => "bmp",
            ImageFormat::Svg => "svg",
            ImageFormat::Unknown => "bin",
        }
        .to_string()
    }
}

/// EPUB 图片信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubImageInfo {
    /// 图片在 EPUB 中的相对路径（href）
    pub href: String,
    /// 图片文件名
    pub filename: String,
    /// 图片格式
    pub format: ImageFormat,
    /// 图片文件大小（字节）
    pub size_bytes: i64,
    /// 图片宽度（像素，可选）
    pub width: Option<i32>,
    /// 图片高度（像素，可选）
    pub height: Option<i32>,
}

/// 书籍元数据
#[derive(Debug, Clone, Serialize, Deserialize, Default, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Book {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub file_path: String,
    pub file_hash: Option<String>,
    pub file_size: i64,
    pub file_mtime: Option<i64>,
    pub title: String,
    pub author: Option<String>,
    pub cover_path: Option<String>,
    pub chapter_count: i64,
    pub total_characters: i64,
    #[sqlx(try_from = "String")]
    pub format: BookFormat,
    pub added_at: DateTime<Utc>,
    pub last_opened_at: Option<DateTime<Utc>>,
    #[sqlx(try_from = "String")]
    pub status: BookStatus,
    pub is_pinned: bool,
    #[sqlx(default)]
    pub description: Option<String>,
    #[sqlx(default)]
    pub publisher: Option<String>,
    #[sqlx(default)]
    pub translator: Option<String>,
    #[sqlx(default)]
    pub isbn: Option<String>,
}

/// 书籍标题摘要（轻量查询用）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct BookTitle {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub title: String,
}
impl Book {
    /// 添加新书籍（导入时调用）
    ///
    /// - `added_at` 自动设为当前时间
    /// - `last_opened_at` 初始为 `None`（尚未打开）
    /// - `status` 默认为 `Planned`（待读）
    /// - 可选元数据（author/description 等）由调用方按需传入
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        file_path: String,
        file_size: i64,
        title: String,
        format: BookFormat,
        chapter_count: i64,
        total_characters: i64,
        file_hash: Option<String>,
        file_mtime: Option<i64>,
        author: Option<String>,
        cover_path: Option<String>,
        description: Option<String>,
        publisher: Option<String>,
        translator: Option<String>,
        isbn: Option<String>,
    ) -> Self {
        Self {
            book_id: Uuid::new_v4().to_string(),
            file_path,
            file_hash,
            file_size,
            file_mtime,
            title: title.to_string(),
            author,
            cover_path,
            chapter_count,
            total_characters,
            format,
            added_at: Utc::now(),
            last_opened_at: None,
            status: BookStatus::Planned,
            is_pinned: false,
            description,
            publisher,
            translator,
            isbn,
        }
    }
}

/// 书籍文件格式
///
/// 数据库中存储为小写文本。仅支持 txt 和 epub。
#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Hash,
    Default,
    Serialize,
    Deserialize,
    strum::AsRefStr,
    strum::EnumString,
)]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum BookFormat {
    #[default]
    #[strum(serialize = "txt", serialize = "text")]
    Txt,
    Epub,
}

//
impl TryFrom<String> for BookFormat {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}

/// 书籍阅读状态
#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Default,
    Serialize,
    Deserialize,
    strum::AsRefStr,
    strum::EnumString,
)]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum BookStatus {
    Reading,
    Completed,
    Dropped,
    #[default]
    Planned,
}

//
impl TryFrom<String> for BookStatus {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}

/// 书架展示用书籍摘要（含进度）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct BookshelfBook {
    #[sqlx(rename = "id")]
    pub book_id: String,
    pub file_path: String,
    pub title: String,
    pub author: Option<String>,
    pub cover_path: Option<String>,
    pub is_pinned: bool,
    #[sqlx(try_from = "String")]
    pub status: BookStatus,
    pub chapter_count: i64,
    pub last_opened_at: Option<DateTime<Utc>>,
    pub added_at: DateTime<Utc>,
    pub progress: Option<f32>,
}
