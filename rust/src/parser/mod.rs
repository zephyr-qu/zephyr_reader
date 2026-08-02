// ============================================================
// 文件作用：解析器模块，管理 EPUB 格式解析的 Parser 枚举统一封装。
//
// 公有类型/函数：
//   - Parser — 解析器枚举（Epub）
//   - Parser::name() — 获取解析器名称
//   - Parser::supported_formats() — 获取支持的格式列表
//   - Parser::parse() — 解析文件
//   - get_cover_registry() — 获取封面提取器注册表
//
// 子模块：
//   - epub, registry, types
// ============================================================

//! 解析器模块
//! 管理 EPUB 格式解析（单引擎：Readium + 内置 EPUB 解析用于导入/封面/目录）

pub mod epub;
pub mod registry;
pub mod types;

/// 获取封面提取器注册表。
pub use crate::domain::cover::engine::get_cover_registry;

/// 初始化解析器模块（日志、注册表等）
pub fn init_parser() {
    get_cover_registry();
    tracing::info!("Parser and cover extractor registries initialized");
}

// 公共类型通过 types 模块统一导出
pub use types::*;
