//! 内容加工管线 — IR 定义、IR 加载、投影、编排、缓存
//!
//! 连接 parser 和 Flutter 渲染层的中间层。
//! 依赖：common/, infra/

pub mod chapter_ir;
pub mod ir_cache;
pub mod orchestration;
pub mod plain_projection;
pub mod types;

pub use plain_projection::*;
pub use types::*;
