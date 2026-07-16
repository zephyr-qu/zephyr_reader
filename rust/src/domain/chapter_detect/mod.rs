//! TXT 章节检测配置模块
//!
//! 提供用户可自定义的正则规则集，按命名 scope 分组管理。
//! 检测优先级：用户自定义规则（DB）→ 内置通用规则 → 整文件单章。

pub mod constants;
pub mod models;
pub mod repo;
pub mod detector;

pub use models::*;
pub use detector::*;
