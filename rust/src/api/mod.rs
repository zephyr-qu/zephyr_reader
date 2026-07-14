//! Rust 核心引擎 API
pub mod backup;
pub mod bilingual;
pub mod reader;
pub mod cover;
pub mod data;
pub mod import;
pub mod dictionary;
pub mod epub;
pub mod search;
pub mod vocab_marker;

// 导出各模块的结构体
pub use bilingual::{AlignedSegment, BilingualAlignment};
pub use import::parse_book;
pub use epub::{EpubImageInfo, ImageFormat};

pub use crate::dictionary::{DictEntry, DictSearchResult};
pub use dictionary::{
    close_dictionary, extract_audio, init_dictionary, lookup_mdict, segment_text, suggest_mdict,
};
pub use search::*;

pub use bilingual::{
    BilingualHighlightPair, align_bilingual_content, create_bilingual_highlight_pair,
    delete_bilingual_highlight_pair, get_bilingual_highlight_pairs,
};

use crate::domain::AppError;

// ============================================================
// 文件作用：核心引擎 API 入口 — 子模块聚合与公共类型重导出。
//
// 公有函数：
//   - test_connection() — 连接测试（保留二进制兼容性）
//
// 重导出的子模块：
//   backup, bilingual, reader, cover, data, import, dictionary,
//   epub, search, vocab_marker
// ============================================================

// Reserved: FRB binding exists for binary compatibility (frb_generated.rs).
pub fn test_connection() -> Result<String, AppError> {
    Ok("Rust reader engine connected successfully".to_string())
}
