//! 内置词库匹配引擎
//!
//! 扫描文本匹配内置词库（CET-4/6、IELTS、TOEFL）。

pub mod vocab;
pub mod vocab_scanner;
pub mod wordlists;

pub use vocab_scanner::*;
pub use wordlists::*;
