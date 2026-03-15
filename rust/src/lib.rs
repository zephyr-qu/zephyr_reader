//! Zephyr Reader Rust 核心引擎
//! 高性能双语文本解析引擎

pub mod api;
pub mod ffi;
pub mod parser;
pub mod stream;
pub mod text_process;
pub mod utils;

// FRB 生成的代码（仅在 frb_expand 时包含）
#[cfg(not(frb_expand))]
mod frb_generated;
