//! Markdown 解析模块
//! 负责 Markdown 文件的元数据提取、章节解析、按需内容提供

pub mod metadata;
pub mod parse;
pub mod provider;

pub use provider::MdContentProvider;
