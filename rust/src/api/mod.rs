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
//! - **bilingual**: 双语对齐功能

pub mod bilingual;
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
    clear_all_search_index, delete_book_search_index, index_chapter_content, init_search_engine,
    search_in_book,
};

// 重新导出增量解析 API
pub use incremental::{
    clear_incremental_parser_cache, get_incremental_parser_stats, init_incremental_parser,
    parse_local_book_incremental,
};

// 重新导出双语对齐 API
pub use bilingual::{align_bilingual_content, simple_bilingual_align};

pub use storage::*;
