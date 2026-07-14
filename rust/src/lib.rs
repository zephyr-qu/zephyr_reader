// ============================================================
// 文件作用：Zephyr Reader Rust 核心引擎，模块导出入口
//
// 公有子模块：
//   - api / domain / parser / reading / search
//   - storage / text / utils / dictionary / vocab_marker
//   - init (应用初始化)
// ============================================================

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
