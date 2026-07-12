use flutter_rust_bridge::frb;

use crate::domain::types::pagination::PaginateResult;
use crate::domain::PageContent;

/// 章节内容枚举
#[derive(Debug, Clone)]
#[frb(dart_metadata=("freezed"))]
pub enum ChapterContent {
    Raw(String),
    Pages(Vec<PageContent>),
}

/// 首段 spine 快速提取结果
#[derive(Debug, Clone)]
#[frb]
pub struct FirstSpineResult {
    pub text: String,
}

/// ADR-016：FRB 类型存根 — 引用 `PaginateResult` 使 `PageDescriptor` / `ChapterPaginationMode` 跨 FFI 边界可用。
#[doc(hidden)]
#[frb]
pub fn _types_keepalive_paginate_result() -> PaginateResult {
    PaginateResult {
        descriptors: vec![],
        config_hash: 0,
        is_partial: false,
        mode: crate::domain::types::pagination::ChapterPaginationMode::PlainText,
    }
}
