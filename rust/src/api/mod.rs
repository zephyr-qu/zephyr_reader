//! Rust 核心引擎 API
use flutter_rust_bridge::frb;
pub mod backup;
pub mod bilingual;
pub mod core;
pub mod cover;
pub mod data;
pub mod dictionary;
pub mod epub;
pub mod md;
pub mod search;
pub mod typeset;
pub mod vocab_marker;

// 导出各模块的结构体
pub use bilingual::{AlignedSegment, BilingualAlignment};
pub use core::{ChapterContent, parse_book};
pub use epub::{EpubImageInfo, ImageFormat};
pub use typeset::typeset_text;

pub use crate::dictionary::{DictEntry, DictSearchResult};
use crate::domain::AppError;
pub use dictionary::{
    close_dictionary, extract_audio, init_dictionary, lookup_mdict, segment_text, suggest_mdict,
};
pub use search::*;

pub use bilingual::{
    BilingualHighlightPair, align_bilingual_content, create_bilingual_highlight_pair,
    delete_bilingual_highlight_pair, get_bilingual_highlight_pairs, simple_bilingual_align,
};

/// 测试 Rust 引擎连接是否正常。
///
/// 返回成功连接信息，用于 Dart 侧启动时验证 FFI 通道可用性。
#[frb(sync)]
pub fn test_connection() -> Result<String, AppError> {


    Ok("Rust core engine connected successfully".to_string())
}
