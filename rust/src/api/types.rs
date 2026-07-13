use flutter_rust_bridge::frb;

use crate::domain::PageContent;

/// 章节内容枚举（`get_chapter` 返回 `Raw` 变体；分页已迁移至 Flutter 侧）。
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
