//! PDF 解析模块
//! 负责 PDF 文件的解压、结构解析、文本提取

pub mod images;
pub mod metadata;
pub mod parse;
pub mod text;

pub use images::extract_pdf_cover;
pub use images::extract_pdf_cover_bytes;
pub use images::get_page_images;
pub use parse::async_parse_pdf_file;
pub use parse::get_pdf_metadata;
pub use parse::get_pdf_page_count;
pub use parse::parse_pdf;
pub use text::get_chapter_text;
pub use text::get_pdf_page_text;
