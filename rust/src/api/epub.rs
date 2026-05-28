//! EPUB 相关 API
//!
//! 提供 EPUB 特有的功能，如富文本章节解析。
//! 通用解析功能请使用 core::parse_book。


use crate::domain::{AppError, EpubMetadata, RichParagraph, TypesetConfig};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use crate::utils::security::validate_file_path_async;

/// 图片格式
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[frb]
pub enum ImageFormat {
    Jpeg,
    Png,
    Gif,
    Webp,
    Bmp,
    Svg,
    Unknown,
}

impl ImageFormat {
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

    pub fn mime_type(&self) -> String {
        match self {
            ImageFormat::Jpeg => "image/jpeg",
            ImageFormat::Png => "image/png",
            ImageFormat::Gif => "image/gif",
            ImageFormat::Webp => "image/webp",
            ImageFormat::Bmp => "image/bmp",
            ImageFormat::Svg => "image/svg+xml",
            ImageFormat::Unknown => "application/octet-stream",
        }.to_string()
    }

    pub fn extension(&self) -> String {
        match self {
            ImageFormat::Jpeg => "jpg",
            ImageFormat::Png => "png",
            ImageFormat::Gif => "gif",
            ImageFormat::Webp => "webp",
            ImageFormat::Bmp => "bmp",
            ImageFormat::Svg => "svg",
            ImageFormat::Unknown => "bin",
        }.to_string()
    }
}

/// EPUB 图片信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubImageInfo {
    pub href: String,
    pub filename: String,
    pub format: ImageFormat,
    pub size_bytes: i64,
    pub width: Option<i32>,
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
#[frb]
pub async fn get_epub_metadata(file_path: String) -> Result<EpubMetadata, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    crate::parser::epub::unzip::get_epub_metadata(&validated_path)
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
#[frb]
pub async fn get_epub_chapter_rich_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<RichParagraph>, AppError> {
    let config = config.validate_and_fix();
    let validated_path = validate_file_path_async(&file_path).await?;
    crate::parser::epub::parse::get_chapter_content_rich_with_typeset(
        &validated_path,
        chapter_index,
        &config,
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
        let result = get_epub_chapter_rich_content(
            "non_existent.epub".into(),
            0,
            TypesetConfig::default(),
        )
        .await;
        assert!(result.is_err());
    }
}

