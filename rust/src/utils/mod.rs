//! 工具模块
//! 包含性能监控、内部工具函数等通用工具

pub mod macros;
pub mod metrics;
pub use metrics::*;

// 宏需要特殊处理，在根 lib.rs 中使用 #[macro_use] 导出
