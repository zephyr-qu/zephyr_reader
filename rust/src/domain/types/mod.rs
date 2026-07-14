// ============================================================
// 文件作用：领域类型模块声明和统一重新导出
//
// 公有模块：
//   - block_pagination — 块分页描述符
//   - content_ir — 章节中间表示（ContentBlock 流）
//   - metadata — EPUB 等元数据结构
//   - pagination — 分页内容结构
//   - plain_projection — IR 到 plain text 的投影
//   - rich_text — 富文本结构（段落、样式段、链接）
//   - typeset — 排版配置
// ============================================================

// 子模块声明
pub mod block_pagination;
pub mod content_ir;
pub mod pagination;
pub mod plain_projection;
pub mod rich_text;
pub mod typeset;

// 统一导出所有公共类型
pub use block_pagination::*;
pub use content_ir::*;
pub use pagination::*;
pub use plain_projection::*;
pub use rich_text::*;
pub use typeset::*;
