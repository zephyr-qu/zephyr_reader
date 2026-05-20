//! 解析器模块
//! 管理 EPUB、PDF、TXT 等多种格式的解析

pub mod cover_extractor;
pub mod epub;
pub mod pdf;
pub mod registry;
pub mod txt;

pub use cover_extractor::get_cover_registry;
pub use epub::create_epub_parser;
pub use pdf::create_pdf_parser;
pub use txt::create_txt_parser;


