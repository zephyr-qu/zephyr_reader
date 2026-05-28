//! Rust 核心引擎 API
use flutter_rust_bridge::frb;
pub mod data;
pub mod bilingual;
pub mod core;
pub mod cover;
pub mod dictionary;
pub mod epub;
pub mod md;
pub mod search;
pub mod typeset;
pub mod backup;
pub mod vocab_marker;


// 导出各模块的结构体
pub use epub::{ImageFormat, EpubImageInfo};
pub use core::{ChapterContent,parse_book};
pub use bilingual::{AlignedSegment, BilingualAlignment};
pub use typeset::typeset_text;

pub use search::*;
pub use dictionary::{
    close_dictionary, extract_audio, init_dictionary, lookup_mdict, segment_text, suggest_mdict,
};
pub use crate::dictionary::{DictEntry, DictSearchResult};

pub use bilingual::{align_bilingual_content, simple_bilingual_align,create_bilingual_highlight_pair, get_bilingual_highlight_pairs,
    delete_bilingual_highlight_pair, BilingualHighlightPair,};



#[frb(sync)]
pub fn test_connection() -> String {
    "Rust core engine connected successfully".to_string()
}
