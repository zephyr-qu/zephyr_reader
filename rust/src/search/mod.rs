//! 全文搜索引擎模块
//! 基于 SQLite FTS5 实现书籍内容搜索
//! 集成 jieba-rs 中文分词支持

mod engine;
pub use engine::*;
