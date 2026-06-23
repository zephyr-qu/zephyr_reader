//! 领域类型模块 (Domain Types)
//!
//! 按领域拆分为多个子模块：
//! - `typeset`: 排版配置
//! - `rich_text`: 富文本结构
//! - `content_ir`: Phase 2 章节 IR（ContentBlock）
//! - `pagination`: 分页内容
//! - `metadata`: 元数据（EPUB/PDF/解析结果）

// 子模块声明
pub mod block_pagination;
pub mod content_ir;
pub mod metadata;
pub mod pagination;
pub mod rich_text;
pub mod typeset;

// 统一导出所有公共类型
pub use block_pagination::*;
pub use content_ir::*;
pub use metadata::*;
pub use pagination::*;
pub use rich_text::*;
pub use typeset::*;
