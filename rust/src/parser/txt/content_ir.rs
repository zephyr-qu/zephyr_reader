//! TXT 章节 → Phase 2 IR（M1.2）
//!
//! 按空行分段（与 `PageStreamer` 段落语义一致）；`plain_text` 与
//! `TxtContentProvider::read_text_range` 章内字节/字符内容 **完全一致**。

use crate::domain::{
    AppError, ChapterContentIr, ContentBlock, TextBlock, TextBlockStyle,
    slice_by_char_range,
};
#[cfg(test)]
use crate::domain::PlainProjectionStyle;

use super::provider::TxtContentProvider;
use crate::parser::provider::ChapterContentProvider;

/// 空行分隔的段落 char 范围 `(plain_start, plain_len)`（Unicode 标量索引）。
fn paragraph_char_ranges(text: &str) -> Vec<(u32, u32)> {
    let mut ranges = Vec::new();
    let mut para_start: Option<u32> = None;
    let mut char_idx = 0u32;

    for line in text.split_inclusive('\n') {
        let line_len = line.chars().count() as u32;
        let trimmed = line.trim_end_matches(['\r', '\n']);

        if trimmed.is_empty() {
            if let Some(start) = para_start.take() {
                ranges.push((start, char_idx - start));
            }
        } else if para_start.is_none() {
            para_start = Some(char_idx);
        }
        char_idx += line_len;
    }

    if let Some(start) = para_start.take() {
        ranges.push((start, char_idx - start));
    }

    ranges
}

/// 章内纯文本 → IR（`plain_text` 等于输入原文）。
pub fn txt_to_chapter_ir(chapter_text: &str) -> ChapterContentIr {
    let mut blocks = Vec::new();

    for (start, len) in paragraph_char_ranges(chapter_text) {
        let text = slice_by_char_range(chapter_text, start, len);
        if text.trim().is_empty() {
            continue;
        }
        blocks.push(ContentBlock::Text(TextBlock::new(
            start,
            text,
            TextBlockStyle::default(),
        )));
    }

    ChapterContentIr::new(blocks, chapter_text.to_string())
}

/// 按章字节界读取 TXT 并生成 IR（`start_byte`/`end_byte` 与 DB chapter bounds 一致）。
pub fn get_chapter_content_ir(
    file_path: &str,
    start_byte: i32,
    end_byte: i32,
) -> Result<ChapterContentIr, AppError> {
    tracing::info!(
        "[get_chapter_content_ir:txt] file_path={}, bytes={}..{}",
        file_path,
        start_byte,
        end_byte
    );

    let provider = TxtContentProvider::open(file_path)?;
    let start = start_byte.max(0) as u64;
    let end = end_byte.max(0) as u64;
    let text = provider.read_text_range(start, end)?;
    Ok(txt_to_chapter_ir(&text))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_ir_invariants(ir: &ChapterContentIr) {
        ir.validate_plain(PlainProjectionStyle::SourcePreserved)
            .expect("TXT IR must satisfy SourcePreserved plain projection");
    }

    #[test]
    fn single_paragraph_chapter() {
        let ir = txt_to_chapter_ir("Hello world");
        assert_eq!(ir.block_count(), 1);
        assert_eq!(ir.plain_text, "Hello world");
        assert_ir_invariants(&ir);
    }

    #[test]
    fn blank_line_splits_paragraphs() {
        let raw = "First line\n\nSecond line";
        let ir = txt_to_chapter_ir(raw);
        assert_eq!(ir.block_count(), 2);
        assert_eq!(ir.plain_text, raw);
        assert_eq!(ir.blocks[0].plain_start(), 0);
        assert_eq!(ir.blocks[1].plain_start(), 12);
        assert_ir_invariants(&ir);
    }

    #[test]
    fn multiline_paragraph_single_block() {
        let raw = "Line one\nLine two\n\nNext para";
        let ir = txt_to_chapter_ir(raw);
        assert_eq!(ir.block_count(), 2);
        assert_eq!(ir.plain_text, raw);
        let ContentBlock::Text(first) = &ir.blocks[0] else {
            panic!("expected Text");
        };
        assert!(first.text.contains("Line one"));
        assert!(first.text.contains("Line two"));
        assert_ir_invariants(&ir);
    }

    #[test]
    fn empty_chapter() {
        let ir = txt_to_chapter_ir("");
        assert!(ir.blocks.is_empty());
        assert!(ir.plain_text.is_empty());
    }

    #[test]
    fn plain_offsets_monotonic() {
        let ir = txt_to_chapter_ir("A\n\nB\n\nC");
        let mut prev_end = 0u32;
        for block in &ir.blocks {
            let range = block.plain_range();
            assert!(range.plain_start >= prev_end);
            prev_end = range.end_exclusive();
        }
        assert_ir_invariants(&ir);
    }

    #[test]
    fn gap_between_paragraphs_not_in_any_block() {
        let ir = txt_to_chapter_ir("A\n\nB");
        assert_eq!(ir.block_index_at_offset(0), Some(0));
        assert_eq!(ir.block_index_at_offset(2), None);
        assert_eq!(ir.block_index_at_offset(3), Some(1));
    }
}
