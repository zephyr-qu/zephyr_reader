//! Rust 核心引擎 API
//!
//! 本模块提供了 Zephyr Reader Rust 引擎的所有公共接口函数，
//! 通过 flutter_rust_bridge 暴露给 Flutter 侧调用。
//!
//! # 模块结构
//!
//! - **core**: 核心解析、排版和流式分页功能
//! - **cover**: 封面提取
//! - **epub**: EPUB 解析功能
//! - **incremental**: 增量解析缓存
//! - **search**: 全文搜索
//! - **security**: 路径安全验证
//! - **storage**: 数据库和文件存储操作

pub mod core;
pub mod cover;
pub mod epub;
pub mod incremental;
pub mod search;
pub mod security;
pub mod storage;

// 重新导出常用类型
pub use crate::ffi::*;

// 重新导出核心 API
pub use core::{
    extract_chapter, extract_metadata, get_file_size, get_supported_formats, init_app,
    paginate_all_content, parse_book, read_file_chunk, set_allowed_base_dir, supports_format,
    test_connection, typeset_text,
};

// 重新导出封面 API
pub use cover::{extract_book_cover, supports_cover_extraction};

// 重新导出搜索 API
pub use search::{
    clear_all_search_index, index_chapter_content, init_search_engine, search_in_book,
};

// 重新导出增量解析 API
pub use incremental::{
    clear_incremental_parser_cache, get_incremental_parser_stats, init_incremental_parser,
    parse_local_book_incremental,
};

// 重新导出存储 API
// pub use storage::{
//     assign_category_to_book, clear_all_sync_records, clear_categories_for_book, clear_layout_cache,
//     clear_reading_progress, clear_sync_conflicts, create_bookmark, delete_book, delete_bookmark,
//     delete_bookmarks_by_book, delete_category, delete_chapters_by_book, delete_search_index,
//     delete_sessions_by_book, delete_sync_record, export_bookmarks, get_all_books, get_all_categories,
//     get_book, get_bookmark, get_bookmark_stats, get_bookmarks, get_books_by_status,
//     get_categories_for_book, get_category, get_chapter_by_index, get_chapters_by_book,
//     get_global_reading_stats, get_layout_cache, get_pending_sync_records, get_pinned_books,
//     get_reading_progress, get_reading_sessions, get_reading_stats_range, get_recent_sessions,
//     get_recently_read_books, get_sessions_by_date_range, get_sync_conflicts, get_today_reading_stats,
//     import_bookmarks, record_reading_session, remove_category_from_book,
//     save_book, save_bookmark, save_bookmarks_batch, save_category, save_chapters, save_layout_cache,
//     save_reading_progress, save_sync_record, search_books, search_content, set_categories_for_book,
//     sync_bookmarks, update_bookmark, update_reading_progress, update_reading_progress_partial,
//     update_sync_status, cleanup_expired_layout_cache
// };
pub use storage::*;
