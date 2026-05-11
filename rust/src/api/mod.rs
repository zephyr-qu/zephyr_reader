//! Rust 核心引擎 API — 薄层：参数校验 → 调用 service → 返回

use flutter_rust_bridge::frb;

pub mod bilingual;
pub mod book;
pub mod file;
pub mod cover;
pub mod epub;
pub mod search;
pub mod storage;
pub mod typeset;

pub use book::{
    create_page_streamer, extract_metadata, get_chapter, get_supported_formats, init_app,
    paginate_all_content, parse_book, supports_format, ChapterContent,
};

pub use file::{get_file_size, read_file_chunk};

pub use typeset::typeset_text;

pub use search::{
    clear_all_search_index, delete_book_search_index, index_chapter_content, init_search_engine,
    search_in_book,
};

pub use bilingual::{align_bilingual_content, simple_bilingual_align};

pub use storage::*;

#[frb(sync)]
pub fn test_connection() -> String {
    "Rust core engine connected successfully".to_string()
}
