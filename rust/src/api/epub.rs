//! EPUB 相关 API
//!
//! 提供 EPUB 特有的功能，如富文本章节解析。
//! 通用解析功能请使用 core::parse_book。


pub(crate) use crate::domain::AppError;
pub use crate::domain::{EpubMetadata, RichParagraph, TypesetConfig};
use crate::utils::security::validate_file_path_async;
use flutter_rust_bridge::frb;

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



