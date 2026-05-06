//! 解析器模块
//! 包含 TXT、EPUB 和 PDF 三种格式的解析实现
//!
//! 支持插件化架构，通过 `traits` 模块定义统一的解析器接口。
//! 支持增量解析，通过 `incremental` 模块实现文件变更检测。
//! 支持并行解析，通过 `parallel` 模块实现多线程章节验证。
//!
//! # 插件化架构
//!
//! 提供具体的解析器实现：
//! - `TxtParser`: TXT 文件格式解析
//! - `EpubParser`: EPUB 文件格式解析
//! - `PdfParser`: PDF 文件格式解析

pub mod cover_extractor;
pub mod epub;
pub mod epub_parser;
pub mod incremental;
pub mod parallel;
pub mod pdf;
pub mod pdf_parser;
pub mod traits;
pub mod txt;
pub mod txt_parser;

pub use epub::parse_epub;
pub use pdf::parse_pdf;
pub use txt::parse_txt;

// 导出插件化架构
pub use traits::{BookMetadata, BookParser, ParserRegistry, ThreadSafeParserRegistry};

// 导出具体解析器实现
pub use epub_parser::{create_epub_parser, EpubParser};
pub use pdf_parser::{create_pdf_parser, PdfParser};
pub use txt_parser::{create_txt_parser, TxtParser};

// 导出增量解析
pub use incremental::{CacheStats, FileMetadata, IncrementalParseResult, IncrementalParser};

// 导出并行解析
pub use parallel::{process_chapters_parallel, validate_chapters_parallel};

// 导出封面提取器
pub use cover_extractor::{
    get_cover_registry, CoverExtractor, CoverExtractorRegistry, EpubCoverExtractor,
    PdfCoverExtractor, ThreadSafeCoverRegistry, TxtCoverExtractor,
};
