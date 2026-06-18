//! Zephyr Reader Rust 核心引擎
//! 高性能双语文本解析引擎

pub mod api;
pub mod dictionary;
pub mod domain;
mod frb_generated;
pub mod init;
pub mod parser;
pub mod reading;
pub mod search;
pub mod storage;
pub mod text;
pub mod utils;
pub mod vocab_marker;
