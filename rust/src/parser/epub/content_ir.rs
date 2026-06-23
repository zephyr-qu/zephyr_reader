//! EPUB HTML → Phase 2 章节 IR（M1.1）
//!
//! 复用 `parse_html_to_rich_text` 保持 DOM 顺序与 scroll 路径一致；
//! plain 投影遵循 ADR-008（每 Image 块一个 `\uFFFC`）。

use crate::domain::{
    AppError, ChapterContentIr, ContentBlock, ImageBlock, RichParagraph, TextBlock,
    TextBlockStyle, IMAGE_PLAIN_PLACEHOLDER,
};
use crate::text::rich_text;

use super::provider::EpubContentProvider;
use crate::parser::provider::ChapterContentProvider;

/// 与 `get_chapter_content_rich` 相同：单章 HTML 超过此值则跳过 html5ever。
const MAX_HTML_SIZE: usize = 100 * 1024;

/// 规范化 EPUB 内资源 id（manifest href / img src）。
fn normalize_asset_id(src: &str) -> String {
    src.trim().replace('\\', "/")
}

fn rich_paragraph_style(p: &RichParagraph) -> TextBlockStyle {
    TextBlockStyle {
        is_heading: p.is_heading,
        heading_level: p.heading_level,
    }
}

/// 在写入下一块前插入块级 `\n`（ADR-007 单换行）。
fn append_block_separator(plain: &mut String, plain_cursor: &mut u32) {
    if plain.is_empty() || plain.ends_with('\n') {
        return;
    }
    plain.push('\n');
    *plain_cursor += 1;
}

/// 将富文本段落流转为章 IR + plain 投影。
pub fn chapter_ir_from_rich_paragraphs(paragraphs: &[RichParagraph]) -> ChapterContentIr {
    let mut blocks = Vec::new();
    let mut plain = String::new();
    let mut plain_cursor = 0u32;

    for p in paragraphs {
        if p.is_image {
            append_block_separator(&mut plain, &mut plain_cursor);
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
            let block = ImageBlock::new(plain_cursor, src, alt);
            plain.push(IMAGE_PLAIN_PLACEHOLDER);
            plain_cursor += 1;
            blocks.push(ContentBlock::Image(block));
            continue;
        }

        let text = p.full_text();
        if text.trim().is_empty() {
            continue;
        }

        append_block_separator(&mut plain, &mut plain_cursor);
        let start = plain_cursor;
        let block = TextBlock::new(start, text.clone(), rich_paragraph_style(p));
        plain.push_str(&text);
        plain_cursor += text.chars().count() as u32;
        blocks.push(ContentBlock::Text(block));
    }

    ChapterContentIr::new(blocks, plain)
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

    html_to_chapter_ir(&html_content)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::IMAGE_PLAIN_CHAR_LEN;

    fn assert_ir_invariants(ir: &ChapterContentIr) {
        assert_eq!(
            ir.image_block_count(),
            ir.image_placeholder_count(),
            "ADR-008: FFFC count must match Image blocks"
        );

        let mut expected_plain = String::new();
        let mut expected_cursor = 0u32;
        for block in &ir.blocks {
            match block {
                ContentBlock::Text(t) => {
                    append_block_separator(&mut expected_plain, &mut expected_cursor);
                    assert_eq!(t.plain.plain_start, expected_cursor);
                    assert_eq!(t.plain.plain_len, t.text.chars().count() as u32);
                    expected_plain.push_str(&t.text);
                    expected_cursor += t.plain.plain_len;
                }
                ContentBlock::Image(img) => {
                    append_block_separator(&mut expected_plain, &mut expected_cursor);
                    assert_eq!(img.plain.plain_start, expected_cursor);
                    assert_eq!(img.plain.plain_len, IMAGE_PLAIN_CHAR_LEN);
                    assert!(img.validate_plain());
                    expected_plain.push(IMAGE_PLAIN_PLACEHOLDER);
                    expected_cursor += 1;
                }
            }
        }
        assert_eq!(ir.plain_text, expected_plain);
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
