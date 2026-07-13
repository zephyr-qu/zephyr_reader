//! EPUB 相关 API
//!
//! 提供 EPUB 特有的功能，如富文本章节解析。
//! 通用解析功能请使用 reader::parse_book。

use crate::domain::{AppError, EpubMetadata, RichParagraph, TypesetConfig};
use crate::utils::security::validate_file_path;
use lru::LruCache;
use std::num::NonZeroUsize;
use std::sync::{LazyLock, Mutex};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

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

/// 快速获取 EPUB 元数据
///
/// 无需完整解析 EPUB 文件即可获取书名、作者、封面、目录等信息。
/// 适用于文件列表预览、导入前预览等场景。
///
/// # 参数
/// * `file_path` - EPUB 文件路径
///
/// # 返回值
/// * `Ok(EpubMetadata)` - 元数据（包含标题、作者、封面、目录、阅读顺序）
/// * `Err(AppError)` - 解析失败（文件不存在、格式错误等）
// Reserved: FRB binding exists (frb_generated.rs), kept for binary compatibility.
// Currently unused — imports go through parseBook.
#[frb]
pub async fn get_epub_metadata(file_path: String) -> Result<EpubMetadata, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let metadata = crate::parser::epub::unzip::get_epub_metadata(&validated_path)?;
    Ok(metadata)
}

/// 获取 EPUB 章节富文本内容（带排版）
///
/// 解析 EPUB 章节为富文本格式，并应用排版配置（首行缩进、标点优化等）。
///
/// # 参数
/// * `file_path` - EPUB 文件路径
/// * `chapter_index` - 章节索引
/// * `config` - 排版配置
///
/// # 返回值
/// * `Ok(Vec<RichParagraph>)` - 排版后的富文本段落
/// * `Err(AppError)` - 解析失败
const RICH_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(8) {
    Some(v) => v,
    None => unreachable!(),
};

type RichCacheKey = (String, i32, u64);

static RICH_CONTENT_CACHE: LazyLock<Mutex<LruCache<RichCacheKey, Vec<RichParagraph>>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(RICH_CACHE_CAPACITY)));

#[frb]
pub async fn get_epub_chapter_rich_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<RichParagraph>, AppError> {
    let config = config.validate_and_fix();
    let validated_path = validate_file_path(&file_path)?;
    let cache_key = (validated_path.clone(), chapter_index, config.config_hash());

    // 检查 LRU 缓存
    {
        let mut cache = RICH_CONTENT_CACHE.lock().unwrap();
        if let Some(cached) = cache.get(&cache_key) {
            return Ok(cached.clone());
        }
    }

    let (start_idx, end_idx) =
        crate::reading::chapter_access::get_chapter_bounds(&validated_path, chapter_index).await?;

    let result = crate::parser::epub::parse::get_chapter_content_rich_with_typeset(
        &validated_path,
        start_idx,
        end_idx,
        &config,
    )?;

    // 写入 LRU 缓存
    {
        let mut cache = RICH_CONTENT_CACHE.lock().unwrap();
        cache.put(cache_key, result.clone());
    }

    Ok(result)
}

/// M4.2：按 manifest `asset_id` 解码 EPUB 图片，缩放至 [max_width_px]。
///
/// 返回 JPEG/PNG 字节，供 Flutter `Image.memory` 使用（与 scroll 富文本路径一致）。
#[frb(sync)]
pub fn get_processed_epub_image_bytes(
    file_path: String,
    asset_id: String,
    max_width_px: i32,
) -> Result<Vec<u8>, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let max_width = max_width_px.max(1) as u32;
    crate::parser::epub::processed_image::get_processed_epub_image_bytes(
        &validated_path,
        &asset_id,
        max_width,
    )
}

/// M4.2：按 manifest `asset_id` 解码 EPUB 图片，缩放至 [max_width_px] 并缓存到本地。
///
/// 返回 JPEG/PNG 文件绝对路径，供 Flutter `Image.file` 使用。
#[frb(sync)]
pub fn get_processed_epub_image(
    file_path: String,
    asset_id: String,
    max_width_px: i32,
) -> Result<String, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let max_width = max_width_px.max(1) as u32;
    crate::parser::epub::processed_image::get_processed_epub_image(
        &validated_path,
        &asset_id,
        max_width,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_epub_metadata_file_not_found() {
        let result = get_epub_metadata("non_existent.epub".into()).await;
        assert!(result.is_err());
        assert!(matches!(result, Err(AppError::FileNotFound { .. })));
    }

    #[tokio::test]
    async fn test_get_epub_chapter_rich_content_file_not_found() {
        let result =
            get_epub_chapter_rich_content("non_existent.epub".into(), 0, TypesetConfig::default())
                .await;
        assert!(result.is_err());
    }
}
