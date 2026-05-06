//! Incremental parsing API

use crate::api::security::validate_file_path;
use crate::ffi::{ChapterInfo, ParserError};
use crate::parser::incremental::IncrementalParser;
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;

pub use crate::api::ApiResult;
pub use crate::ffi::LocalBookInfo;

static INCREMENTAL_PARSER: OnceCell<Mutex<IncrementalParser>> = OnceCell::new();

fn get_parser() -> ApiResult<&'static Mutex<IncrementalParser>> {
    INCREMENTAL_PARSER
        .get()
        .ok_or_else(|| ParserError::InternalError("Incremental parser not initialized. Call init_incremental_parser() first.".to_string()))
}

fn get_parser_for_file(
    validated_path: &str,
) -> ApiResult<std::sync::Arc<dyn crate::parser::BookParser>> {
    let extension = std::path::Path::new(validated_path)
        .extension()
        .and_then(|ext| ext.to_str())
        .ok_or_else(|| {
            ParserError::UnsupportedFormat("Cannot identify file extension".to_string())
        })?;
    let registry = crate::api::core::get_registry();
    registry.get_parser(extension).ok_or_else(|| {
        ParserError::UnsupportedFormat(format!("Unsupported file format: {}", extension))
    })
}

#[frb(sync)]
pub fn init_incremental_parser() -> ApiResult<()> {
    let parser = IncrementalParser::new();
    INCREMENTAL_PARSER
        .set(Mutex::new(parser))
        .map_err(|_| ParserError::Other("Incremental parser already initialized".to_string()))?;
    tracing::info!("Incremental parser initialized");
    Ok(())
}

/// 增量解析书籍
///
/// 如果文件已缓存且未变更，直接返回缓存结果；
/// 否则重新解析并更新缓存。
#[frb(sync)]
pub fn parse_local_book_incremental(file_path: String) -> ApiResult<LocalBookInfo> {
    let validated_path = validate_file_path(&file_path)?;
    let file_size = std::fs::metadata(&validated_path)?.len() as i64;
    let parser = get_parser_for_file(&validated_path)?;

    let mut incremental = get_parser()?.lock();
    let result = incremental.parse_incremental(&validated_path, &*parser)?;

    let parse_result = result.parse_result;
    let chapters: Vec<ChapterInfo> = parse_result.chapters;

    tracing::info!(
        "Incremental parse: file={}, chapters={}, full_reparse={}",
        validated_path,
        chapters.len(),
        result.full_reparse_required
    );

    Ok(LocalBookInfo {
        file_path: validated_path,
        file_size,
        title: parse_result.book_info.title,
        author: parse_result.book_info.author,
        description: String::new(),
        cover_path: parse_result.book_info.cover_path,
        chapter_count: parse_result.book_info.chapter_count,
        chapters,
    })
}

/// 清除增量解析缓存
#[frb(sync)]
pub fn clear_incremental_parser_cache() -> ApiResult<()> {
    get_parser()?.lock().clear_all();
    tracing::info!("Incremental parser cache cleared");
    Ok(())
}

/// 获取增量解析缓存统计信息
#[frb(sync)]
pub fn get_incremental_parser_stats() -> ApiResult<crate::parser::CacheStats> {
    let parser = get_parser()?;
    Ok(parser.lock().get_cache_stats())
}
