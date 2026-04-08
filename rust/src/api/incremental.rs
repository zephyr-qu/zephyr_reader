//! Incremental parsing API

use crate::api::security::validate_file_path;
use crate::catch_panic;
use crate::ffi::{ChapterInfo, ParserError};
use crate::parser::incremental::IncrementalParser;
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;

pub use crate::api::ApiResult;
pub use crate::ffi::LocalBookInfo;

static INCREMENTAL_PARSER: OnceCell<Mutex<IncrementalParser>> = OnceCell::new();

#[frb(sync)]
pub fn init_incremental_parser() -> ApiResult<()> {
    catch_panic! {
        {
            let parser = IncrementalParser::new();
            INCREMENTAL_PARSER
                .set(Mutex::new(parser))
                .map_err(|_| ParserError::Other("Incremental parser already initialized".to_string()))?;
            tracing::info!("Incremental parser initialized");
            Ok(())
        }
    }
}

#[frb(sync)]
pub fn parse_local_book_incremental(file_path: String) -> ApiResult<LocalBookInfo> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;
            let file_size = std::fs::metadata(&validated_path)?.len() as i64;

            // 使用核心解析器（增量解析器需要与 BookParser 配合使用）
            let parse_result = crate::api::core::parse_book(validated_path.clone())?;

            let chapters: Vec<ChapterInfo> = parse_result.chapters;
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
    }
}

#[frb(sync)]
pub fn clear_incremental_parser_cache() -> ApiResult<()> {
    tracing::info!("Incremental parser cache clear requested");
    Ok(())
}

#[frb(sync)]
pub fn get_incremental_parser_stats() -> crate::parser::CacheStats {
    crate::parser::CacheStats {
        file_count: 0,
        chapter_count: 0,
        total_memory_estimate: 0,
    }
}
