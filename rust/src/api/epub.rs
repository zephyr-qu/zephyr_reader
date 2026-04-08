//! EPUB 相关 API
//!
//! 提供 EPUB 特有的功能，如富文本章节解析。
//! 通用解析功能请使用 core::parse_book。

use crate::api::security::validate_file_path;
use crate::catch_panic;
use crate::ffi::{
    ApiResult, EpubMetadata, PageContent, RichChapterContent, RichParagraph, TypesetConfig,
};
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
/// * `Err(ParserError)` - 解析失败（文件不存在、格式错误等）
#[frb(sync)]
pub fn get_epub_metadata(file_path: String) -> ApiResult<EpubMetadata> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            crate::parser::epub::unzip::get_epub_metadata(&validated_path)
        }
    }
}

/// 解析 EPUB 章节（富文本）
///
/// 解析 EPUB 章节内容为富文本格式，保留 HTML 标签用于显示。
///
/// **注意**: 这是一个 EPUB 特有的功能，用于需要保留 HTML 格式的场景。
/// 普通文本解析请使用 `core::extract_chapter`。
#[frb(sync)]
pub fn parse_epub_chapter_rich(
    file_path: String,
    chapter_index: i32,
) -> ApiResult<RichChapterContent> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;

            // 使用新的富文本解析
            crate::parser::epub::parse::get_chapter_content_rich(&validated_path, chapter_index)
        }
    }
}

/// 获取 EPUB 章节内容（使用排版配置）
///
/// **注意**: 这是一个 EPUB 特有的功能。
/// 通用章节内容获取请使用 `core::extract_chapter`。
#[frb(sync)]
pub fn get_epub_chapter_content(
    file_path: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> ApiResult<Vec<PageContent>> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;

            let pages =
                crate::parser::epub::parse::get_chapter_content(&validated_path, chapter_id, &config)?;

            Ok(pages)
        }
    }
}

/// 获取 EPUB 章节富文本内容（带排版）
///
/// 解析 EPUB 章节为富文本格式，并应用排版配置（首行缩进、标点优化等）。
///
/// # 参数
/// * `file_path` - EPUB 文件路径
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置
///
/// # 返回值
/// * `Ok(Vec<RichParagraph>)` - 排版后的富文本段落
/// * `Err(ParserError)` - 解析失败
#[frb(sync)]
pub fn get_epub_chapter_rich_content(
    file_path: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> ApiResult<Vec<RichParagraph>> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;

            crate::parser::epub::parse::get_chapter_content_rich_with_typeset(
                &validated_path,
                chapter_id,
                &config,
            )
        }
    }
}

/// 将 EPUB 章节富文本分页
///
/// 将富文本段落分割为适合阅读的页面。
///
/// # 参数
/// * `paragraphs` - 富文本段落列表
/// * `chapter_index` - 章节索引
/// * `config` - 排版配置
///
/// # 返回值
/// * `Vec<PageContent>` - 分页后的页面列表
#[frb(sync)]
pub fn paginate_epub_rich_content(
    paragraphs: Vec<RichParagraph>,
    chapter_index: i32,
    config: TypesetConfig,
) -> Vec<PageContent> {
    crate::parser::epub::parse::paginate_rich_content(&paragraphs, chapter_index, &config)
}

/// 检查文件是否为 EPUB 格式
#[frb(sync)]
pub fn is_epub_file(file_path: String) -> bool {
    std::path::Path::new(&file_path)
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.eq_ignore_ascii_case("epub"))
        .unwrap_or(false)
}
