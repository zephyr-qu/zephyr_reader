//! TXT 解析模块
//! 负责 TXT 文件的编码检测、解码、章节提取

pub mod decode;
pub mod parse;

pub use decode::detect_encoding;
pub use parse::parse_txt;
