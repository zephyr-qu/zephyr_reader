//! Rust 核心引擎 API — 薄层：参数校验 → 调用 service → 返回

use flutter_rust_bridge::frb;

pub mod bilingual;
pub mod bilingual_highlight;
pub mod book;
pub mod cover;
pub mod dictionary;
pub mod epub;
pub mod file;
pub mod search;
pub mod storage;
pub mod typeset;
pub mod vocabulary;

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

pub use dictionary::{
    init_dictionary, lookup_word, fuzzy_search_dictionary, search_dictionary_definitions,
    get_dictionary_info, segment_text, DictEntry, DictInfo,
};

pub use vocabulary::{
    add_vocabulary_word, get_vocabulary_words, search_vocabulary, update_vocabulary_status,
    delete_vocabulary_word, get_vocabulary_stats, VocabEntry, VocabStats,
};

pub use bilingual::{align_bilingual_content, simple_bilingual_align};

pub use bilingual_highlight::{
    create_bilingual_highlight_pair, get_bilingual_highlight_pairs,
    delete_bilingual_highlight_pair, BilingualHighlightPair,
};

pub use storage::*;

#[frb(sync)]
pub fn test_connection() -> String {
    "Rust core engine connected successfully".to_string()
}
