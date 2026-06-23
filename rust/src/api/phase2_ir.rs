//! Phase 2 IR / 块分页 — FRB 类型导出锚点（M0.3）。
//!
//! 生产路径在 M3 前不得调用；仅用于 `flutter_rust_bridge_codegen` 生成 Dart 绑定。

use flutter_rust_bridge::frb;

use crate::domain::{
    AppError, BlockPageDescriptor, BlockPaginateResult, BlockPlainRange, ChapterContentIr,
    ContentBlock, ImageBlock, ImageBlockLayout, PageImageLayout, TextBlock, TextBlockStyle,
};

/// 空块分页结果（占位）。
#[frb(sync)]
pub fn phase2_ir_empty_paginate_result() -> BlockPaginateResult {
    BlockPaginateResult::new(vec![], 0, false)
}

/// 样例块流（覆盖 Text + Image 变体）。
#[frb(sync)]
pub fn phase2_ir_sample_blocks() -> Vec<ContentBlock> {
    vec![
        ContentBlock::Text(TextBlock::new(
            0,
            "sample".into(),
            TextBlockStyle::default(),
        )),
        ContentBlock::Image(ImageBlock::new(6, "sample_asset".into(), None)),
    ]
}

/// 样例页描述符（覆盖 `ImageBlockLayout`）。
#[frb(sync)]
pub fn phase2_ir_sample_page_descriptor() -> BlockPageDescriptor {
    BlockPageDescriptor::new(0, 0, 2, BlockPlainRange::new(0, 7), false).with_image_layouts(
        vec![PageImageLayout {
            block_index: 1,
            layout: ImageBlockLayout::InlineContain,
        }],
    )
}

/// 空章 IR（占位）。
#[frb(sync)]
pub fn phase2_ir_empty_chapter() -> ChapterContentIr {
    ChapterContentIr::new(vec![], String::new())
}

/// HTML 片段 → 章 IR（M1.1 测试锚点；生产路径见 `get_chapter_content_ir`）。
#[frb(sync)]
pub fn phase2_ir_html_to_chapter(html: String) -> Result<ChapterContentIr, AppError> {
    crate::parser::epub::html_to_chapter_ir(&html)
}
