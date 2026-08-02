// ============================================================
// 文件作用：Zephyr Reader Rust 核心引擎，模块导出入口
//
// 公有子模块：
//   - api / common / domain / infra / parser
// ============================================================

//! Zephyr Reader Rust 核心引擎
//! 高性能双语文本解析引擎

pub mod api;
pub mod common;
pub mod domain;
mod frb_generated;
pub mod infra;
pub mod parser;

