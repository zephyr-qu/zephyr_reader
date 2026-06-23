//! EPUB HTML → Phase 2 章节 IR（M1.1）
//!
//! 复用 `parse_html_to_rich_text` 保持 DOM 顺序与 scroll 路径一致；
//! plain 投影见 `domain::BlockJoinedPlainBuilder`（ADR-008）。

use super::asset_registry::{canonicalize_chapter_image_assets, normalize_asset_id};
use crate::domain::{
    AppError, BlockJoinedPlainBuilder, ChapterContentIr, RichParagraph, TextBlockStyle,
};
use crate::text::rich_text;

use super::provider::EpubContentProvider;
use crate::parser::provider::ChapterContentProvider;

/// 与 `get_chapter_content_rich` 相同：单章 HTML 超过此值则跳过 html5ever。
const MAX_HTML_SIZE: usize = 100 * 1024;

fn rich_paragraph_style(p: &RichParagraph) -> TextBlockStyle {
    TextBlockStyle {
        is_heading: p.is_heading,
        heading_level: p.heading_level,
    }
}

/// 将富文本段落流转为章 IR + plain 投影。
pub fn chapter_ir_from_rich_paragraphs(paragraphs: &[RichParagraph]) -> ChapterContentIr {
    let mut builder = BlockJoinedPlainBuilder::new();

    for p in paragraphs {
        if p.is_image {
            let src = p
                .image_src
                .as_deref()
                .map(normalize_asset_id)
                .unwrap_or_default();
            let alt = p
                .image_alt
                .as_ref()
                .map(|s| s.trim())
                .filter(|s| !s.is_empty())
                .map(str::to_string);
            builder.push_image(src, alt);
            continue;
        }

        let text = p.full_text();
        if text.trim().is_empty() {
            continue;
        }
        builder.push_text(text, rich_paragraph_style(p));
    }

    builder.finish()
}

/// HTML 片段 → 章 IR（单元测试 / 无 EPUB 文件场景）。
pub fn html_to_chapter_ir(html: &str) -> Result<ChapterContentIr, AppError> {
    let paragraphs = rich_text::parse_html_to_rich_text(html)?;
    Ok(chapter_ir_from_rich_paragraphs(&paragraphs))
}

/// 获取 EPUB 章节 IR（spine 范围与 `get_chapter_content_rich` 一致）。
pub fn get_chapter_content_ir(
    file_path: &str,
    start_index: i32,
    end_index: i32,
) -> Result<ChapterContentIr, AppError> {
    tracing::info!(
        "[get_chapter_content_ir] start: file_path={}, spine={}..{}",
        file_path,
        start_index,
        end_index
    );

    let provider = EpubContentProvider::open_from_bounds(file_path, start_index, end_index)?;
    let html_content = provider
        .read_html_range(0, u64::MAX)
        .ok_or_else(|| AppError::EpubParseError {
            reason: "IR HTML extraction not supported".into(),
        })??;

    if html_content.len() > MAX_HTML_SIZE {
        tracing::warn!(
            "[get_chapter_content_ir] HTML too large ({} bytes), returning empty IR",
            html_content.len(),
        );
        return Ok(ChapterContentIr::new(vec![], String::new()));
    }

    let registry = provider.asset_registry();
    let chapter_href = provider.primary_spine_href();
    let mut ir = html_to_chapter_ir(&html_content)?;
    canonicalize_chapter_image_assets(&mut ir, &registry, chapter_href);
    Ok(ir)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{ContentBlock, PlainProjectionStyle, IMAGE_PLAIN_PLACEHOLDER};

    fn assert_ir_invariants(ir: &ChapterContentIr) {
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .expect("EPUB IR must satisfy BlockJoined plain projection");
    }

    #[test]
    fn html_text_only_produces_text_blocks() {
        let ir = html_to_chapter_ir("<p>Hello</p><p>World</p>").unwrap();
        assert_eq!(ir.block_count(), 2);
        assert_eq!(ir.image_block_count(), 0);
        assert_eq!(ir.plain_text, "Hello\nWorld");
        assert_ir_invariants(&ir);
    }

    #[test]
    fn html_text_and_image_dom_order() {
        let ir =
            html_to_chapter_ir("<p>before</p><img src=\"images/pic.jpg\" alt=\"cover\"/><p>after</p>")
                .unwrap();
        assert_eq!(ir.block_count(), 3);
        assert_eq!(ir.image_block_count(), 1);
        assert_eq!(
            ir.plain_text,
            format!("before\n{IMAGE_PLAIN_PLACEHOLDER}\nafter")
        );

        let image = match &ir.blocks[1] {
            ContentBlock::Image(b) => b,
            other => panic!("expected Image block, got {other:?}"),
        };
        assert_eq!(image.asset_id, "images/pic.jpg");
        assert_eq!(image.alt.as_deref(), Some("cover"));
        assert_eq!(image.plain.plain_start, 7);
        assert!(ir.is_image_placeholder_offset(7));
        assert_eq!(ir.tts_alt_at_offset(7), Some("cover"));
        assert_ir_invariants(&ir);
    }

    #[test]
    fn html_heading_style_preserved() {
        let ir = html_to_chapter_ir("<h2>Title</h2>").unwrap();
        assert_eq!(ir.block_count(), 1);
        let ContentBlock::Text(t) = &ir.blocks[0] else {
            panic!("expected Text block");
        };
        assert!(t.style.is_heading);
        assert_eq!(t.style.heading_level, 2);
        assert_ir_invariants(&ir);
    }

    #[test]
    fn plain_offsets_monotonic() {
        let ir = html_to_chapter_ir(
            "<p>one</p><img src=\"a.png\" alt=\"\"/><p>two</p><img src=\"b.png\"/>",
        )
        .unwrap();
        let mut prev_end = 0u32;
        for block in &ir.blocks {
            let range = block.plain_range();
            assert!(range.plain_start >= prev_end);
            prev_end = range.end_exclusive();
        }
        assert_ir_invariants(&ir);
    }

    #[test]
    fn empty_html_returns_empty_ir() {
        let ir = html_to_chapter_ir("").unwrap();
        assert!(ir.blocks.is_empty());
        assert!(ir.plain_text.is_empty());
    }
}
