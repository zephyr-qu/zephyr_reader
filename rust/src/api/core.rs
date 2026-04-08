//! Core parsing API
//!
//! Provides unified file parsing entry point, supporting TXT, EPUB, PDF formats.
//! Automatically selects the appropriate parser based on file extension via ParserRegistry.

use crate::api::security::validate_file_path;
use crate::catch_panic;
use crate::parser::traits::ThreadSafeParserRegistry;
use crate::parser::{create_epub_parser, create_pdf_parser, create_txt_parser};
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::RwLock;
use std::path::PathBuf;

pub use crate::api::ApiResult;
pub use crate::ffi::{PageContent, ParseResult, TypesetConfig};
pub use crate::parser::BookMetadata;

static PARSER_REGISTRY: OnceCell<ThreadSafeParserRegistry> = OnceCell::new();

/// 允许的基目录（线程安全，支持修改）
pub static ALLOWED_BASE_DIR: RwLock<Option<PathBuf>> = RwLock::new(None);

fn init_parser_registry() -> ThreadSafeParserRegistry {
    let registry = ThreadSafeParserRegistry::new();
    if let Err(e) = registry.register(create_txt_parser()) {
        tracing::warn!("Failed to register TXT parser: {}", e);
    }
    if let Err(e) = registry.register(create_epub_parser()) {
        tracing::warn!("Failed to register EPUB parser: {}", e);
    }
    if let Err(e) = registry.register(create_pdf_parser()) {
        tracing::warn!("Failed to register PDF parser: {}", e);
    }
    tracing::info!("Parser registry initialized");
    registry
}

pub fn get_registry() -> &'static ThreadSafeParserRegistry {
    PARSER_REGISTRY.get_or_init(init_parser_registry)
}

/// 辅助函数：根据文件路径获取对应的 parser
fn get_parser_for_file(
    validated_path: &str,
) -> ApiResult<std::sync::Arc<dyn crate::parser::traits::BookParser>> {
    let extension = std::path::Path::new(validated_path)
        .extension()
        .and_then(|ext| ext.to_str())
        .ok_or_else(|| {
            crate::ffi::ParserError::UnsupportedFormat("Cannot identify file extension".to_string())
        })?;

    let registry = get_registry();
    registry.get_parser(extension).ok_or_else(|| {
        crate::ffi::ParserError::UnsupportedFormat(format!(
            "Unsupported file format: {}",
            extension
        ))
    })
}

#[frb(sync)]
/// 解析书籍文件
///
/// 支持 TXT、EPUB、PDF 格式，自动识别文件类型并提取章节信息。
///
/// # 参数
/// * `file_path` - 文件的完整路径
///
/// # 返回值
/// * `Ok(ParseResult)` - 解析成功，包含书籍元数据和章节列表
/// * `Err(ParserError)` - 解析失败（文件不存在、格式不支持等）
pub fn parse_book(file_path: String) -> ApiResult<ParseResult> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            let registry = get_registry();
            registry.parse_file(&validated_path)
        }
    }
}

#[frb(sync)]
/// 提取书籍元数据
///
/// 快速提取书籍的标题、作者、章节数等信息，不解析完整内容。
///
/// # 参数
/// * `file_path` - 文件的完整路径
///
/// # 返回值
/// * `Ok(BookMetadata)` - 元数据提取成功
/// * `Err(ParserError)` - 提取失败
pub fn extract_metadata(file_path: String) -> ApiResult<BookMetadata> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            let parser = get_parser_for_file(&validated_path)?;
            parser.extract_metadata(&validated_path)
        }
    }
}

#[frb(sync)]
/// 提取指定章节的内容
///
/// 根据章节 ID 提取完整的章节文本内容。
///
/// # 参数
/// * `file_path` - 文件的完整路径
/// * `chapter_id` - 章节 ID（从 0 开始）
///
/// # 返回值
/// * `Ok(String)` - 章节内容
/// * `Err(ParserError)` - 提取失败（章节不存在等）
pub fn extract_chapter(file_path: String, chapter_id: i32) -> ApiResult<String> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            let parser = get_parser_for_file(&validated_path)?;
            parser.extract_chapter(&validated_path, chapter_id)
        }
    }
}

#[frb(sync)]
/// 获取 TXT 章节内容（带排版和分页）
///
/// 专门用于 TXT 文件，提取指定章节并进行排版处理后分页。
/// 与 `extract_chapter` 不同，此函数返回分页后的页面列表。
///
/// # 参数
/// * `file_path` - TXT 文件的完整路径
/// * `chapter_index` - 章节索引（从 0 开始）
/// * `config` - 排版配置（字体大小、行距、页面尺寸等）
///
/// # 返回值
/// * `Ok(Vec<PageContent>)` - 分页后的页面列表
/// * `Err(ParserError)` - 提取失败（章节不存在等）
pub fn get_txt_chapter_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> ApiResult<Vec<PageContent>> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            crate::parser::txt::parse::get_chapter_content(&validated_path, chapter_index, &config)
        }
    }
}

#[frb(sync)]
/// 获取支持的文件格式列表
///
/// 返回当前支持的文件格式扩展名列表（如 "txt", "epub", "pdf"）。
pub fn get_supported_formats() -> Vec<String> {
    let registry = get_registry();
    registry
        .supported_formats()
        .iter()
        .map(|s| s.to_string())
        .collect()
}

#[frb(sync)]
/// 检查是否支持指定格式
///
/// # 参数
/// * `format` - 文件格式扩展名（如 "txt", "epub"）
///
/// # 返回值
/// `true` 如果格式受支持，`false` 否则
pub fn supports_format(format: String) -> bool {
    let registry = get_registry();
    registry.supports_format(&format)
}

#[frb(sync)]
/// 对文本进行排版处理
///
/// 根据配置对文本进行智能排版，包括中文/英文换行、首行缩进等。
///
/// # 参数
/// * `content` - 原始文本内容
/// * `language` - 语言类型（"zh", "en", "auto"）
/// * `config` - 排版配置（字体大小、行距、页面尺寸等）
///
/// # 返回值
/// * `Ok(String)` - 排版后的文本
/// * `Err(ParserError)` - 排版失败
pub fn typeset_text(content: String, language: String, config: TypesetConfig) -> ApiResult<String> {
    crate::text_process::typeset::typeset_content(content, language, config)
}

#[frb(sync)]
/// 获取文件大小
///
/// # 参数
/// * `file_path` - 文件的完整路径
///
/// # 返回值
/// * `Ok(i64)` - 文件大小（字节）
/// * `Err(ParserError)` - 获取失败（文件不存在等）
pub fn get_file_size(file_path: String) -> ApiResult<i64> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            let metadata = std::fs::metadata(&validated_path)?;
            Ok(metadata.len() as i64)
        }
    }
}

#[frb(sync)]
/// 读取文件块
///
/// 支持大文件分块读取，避免内存溢出。
///
/// # 参数
/// * `file_path` - 文件的完整路径
/// * `start_pos` - 起始位置（字节偏移）
/// * `chunk_size` - 读取大小（字节）
///
/// # 返回值
/// * `Ok(String)` - 文件块内容
/// * `Err(ParserError)` - 读取失败
pub fn read_file_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            crate::stream::file_stream::read_chunk(validated_path, start_pos, chunk_size)
        }
    }
}

/// 创建流式分页器
///
/// 返回一个 `PageStreamer` 实例，支持按需获取页面内容，
/// 避免一次性加载全部内容到内存，适用于大文件阅读场景。
///
/// # 参数
///
/// * `content` - 原始文本内容
/// * `config` - 排版配置（页面尺寸、字体大小等）
///
/// # 返回值
///
/// 返回配置好的 `PageStreamer` 实例
#[frb(sync)]
pub fn create_page_streamer(content: String, config: TypesetConfig) -> crate::stream::PageStreamer {
    crate::stream::PageStreamer::new(content, config)
}

/// 对全部内容进行分页处理
///
/// 将完整文本内容按照配置分页，返回所有页面列表。
/// 适用于需要预加载全部页面的场景（如小文件或离线缓存）。
///
/// # 参数
///
/// * `content` - 原始文本内容
/// * `chapter_id` - 章节 ID（用于标识页面所属章节）
/// * `config` - 排版配置（页面尺寸、字体大小等）
///
/// # 返回值
///
/// 返回分页后的页面列表
#[frb(sync)]
pub fn paginate_all_content(
    content: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> Vec<PageContent> {
    crate::stream::page_stream::paginate_all(content, chapter_id, config)
}

#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::EnvFilter;
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .init();

    // 初始化 Rayon 全局线程池
    crate::init_rayon_pool();

    // 初始化解析器注册表
    crate::get_registry();

    tracing::info!("Rust core engine initialized");
}

#[frb(sync)]
pub fn test_connection() -> String {
    "Rust core engine connected successfully".to_string()
}

#[frb(sync)]
/// 设置允许访问的基础目录
///
/// 设置后，所有文件操作都会被限制在该目录内，防止路径遍历攻击。
/// 使用 RwLock 实现，支持多次调用更新目录。
///
/// # 参数
/// * `base_dir` - 基础目录的完整路径
///
/// # 返回值
/// * `Ok(())` - 设置成功
/// * `Err(ParserError)` - 设置失败（目录不存在等）
pub fn set_allowed_base_dir(base_dir: String) -> ApiResult<()> {
    let path = std::path::Path::new(&base_dir);
    if !path.exists() {
        return Err(crate::ffi::ParserError::ConfigError(format!(
            "Directory does not exist: {}",
            base_dir
        )));
    }
    if !path.is_dir() {
        return Err(crate::ffi::ParserError::ConfigError(format!(
            "Not a directory: {}",
            base_dir
        )));
    }

    // 规范化路径
    let canonical = path.canonicalize().map_err(|e| {
        crate::ffi::ParserError::ConfigError(format!("Failed to canonicalize path: {}", e))
    })?;

    // 使用 RwLock 允许更新
    let mut guard = ALLOWED_BASE_DIR.write();
    *guard = Some(canonical);

    tracing::info!("Set allowed base dir: {}", base_dir);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_supported_formats() {
        let formats = get_supported_formats();
        assert!(!formats.is_empty());
    }

    #[test]
    fn test_supports_format() {
        assert!(
            supports_format("txt".to_string())
                || supports_format("epub".to_string())
                || supports_format("pdf".to_string())
        );
        assert!(!supports_format("unknown".to_string()));
    }
}
