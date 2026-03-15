//! 解析器模块
//! 包含 TXT 和 EPUB 两种格式的解析实现

pub mod epub;
pub mod txt;

pub use epub::parse_epub;
pub use txt::parse_txt;

// 重新导出给 FRB 使用
pub use epub::parse_epub as frb_parse_epub;
pub use txt::parse_txt as frb_parse_txt;
