//! Rust 核心引擎 API — 薄层：参数校验 → 调用 service → 返回

use flutter_rust_bridge::frb;

/// 宏：获取 storage pool 并执行操作
/// 减少 `ensure_storage() → pool() → 操作 → 错误转换` 重复样板
#[macro_export]
macro_rules! async_storage {
    ($op:expr) => {{
        let pool = $crate::storage::ensure_storage()
            .map_err(|e| $crate::domain::AppError::database_error(e.to_string()))?
            .pool()
            .map_err(|e| $crate::domain::AppError::database_error(e.to_string()))?;
        $op(&pool).await
            .map_err(|e| $crate::domain::AppError::database_error(e.to_string()))
    }};
}

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

pub use storage::{
    init_storage, get_all_books, save_book, delete_book,
    search_books, get_book, get_books_by_status, get_pinned_books,
    get_recently_read_books, get_books_paginated, get_book_count,
    update_book_status, update_book_pin,
    get_chapters_by_book, save_chapters, delete_chapters_by_book, get_chapter_by_index,
    get_reading_progress, save_reading_progress, clear_reading_progress,
    get_bookmarks, create_bookmark, delete_bookmark, get_bookmark,
    delete_bookmarks_by_book, import_bookmarks, sync_bookmarks, get_bookmark_stats,
    record_reading_session, get_reading_sessions, get_sessions_by_date_range,
    get_recent_sessions, delete_sessions_by_book,
    get_today_reading_stats, get_reading_stats_range, get_global_reading_stats,
    update_daily_stats,
    get_all_categories, save_category, delete_category, get_category,
    get_categories_for_book, assign_category_to_book, remove_category_from_book,
    set_categories_for_book, clear_categories_for_book,
    create_note, update_note, get_notes, get_notes_in_chapter, delete_note,
    delete_notes_by_book, get_note_stats,
    export_database, restore_database,
    BookCategory, Book, BookStatus, Bookmark, Chapter, GlobalStats,
    Note, NoteType, ReadingProgress, ReadingSession, ReadingStats, NoteStats,
};

#[frb(sync)]
pub fn test_connection() -> String {
    "Rust core engine connected successfully".to_string()
}
