//! 领域类型模块 (Domain Types)
//!
//! 按领域拆分为多个子模块：
//! - `typeset`: 排版配置
//! - `rich_text`: 富文本结构
//! - `pagination`: 分页内容
//! - `metadata`: 元数据（EPUB/PDF/解析结果）

// 子模块声明
pub mod metadata;
pub mod pagination;
pub mod rich_text;
pub mod typeset;

// 统一导出所有公共类型
pub use metadata::*;
pub use pagination::*;
pub use rich_text::*;
pub use typeset::*;
