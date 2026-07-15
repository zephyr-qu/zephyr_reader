// ============================================================
// 文件作用：IR 到 plain text 投影及校验
//
// 公有类型/函数：
//   - enum PlainProjectionStyle — plain 投影风格（BlockJoined | SourcePreserved）
//   - enum PlainProjectionError — 投影校验失败原因
//   - fn slice_by_char_range() — 按 Unicode 字符索引切片
//   - fn slice_rich_spans() — 裁剪 RichTextSpan 流
//   - fn append_block_separator() — 块间 \n 分隔符
//   - fn project_block_joined() — 从块流重建 plain
//   - struct BlockJoinedPlainBuilder — BlockJoined 增量构建器
//   - fn append_chapter_ir_to_builder() — 合并多 spine IR 到 builder
//   - fn validate_chapter_plain() — 校验章 IR plain 投影（ADR-008 + ADR-001）
//   - impl ChapterContentIr 方法 — 字符读取、搜索、TTS 辅助
//
// 私有函数：
//   - _clone_span_with_text() — 克隆 span 并替换文本
// ============================================================

use std::fmt;

use crate::pipeline::types::{
    ChapterContentIr, ContentBlock, ImageBlock, RichTextSpan, RichTextSpanData, TextBlock,
    TextBlockStyle, IMAGE_PLAIN_CHAR_LEN, IMAGE_PLAIN_PLACEHOLDER,
};

/// plain 投影 / 校验风格。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlainProjectionStyle {
    /// 块拼接（EPUB）：相邻块以单 `\n` 分隔；Image → `\uFFFC`。
    BlockJoined,
    /// 原文保留（TXT）：`plain_text` 为权威来源，块坐标指向其中片段。
    SourcePreserved,
}

/// plain 投影校验失败原因。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlainProjectionError {
    ImagePlaceholderCountMismatch {
        blocks: usize,
        placeholders: usize,
    },
    PlainLengthMismatch {
        expected_len: u32,
        actual_len: u32,
    },
    BlockPlainOutOfRange {
        block_index: usize,
        plain_start: u32,
        plain_len: u32,
        plain_len_total: u32,
    },
    TextBlockContentMismatch {
        block_index: usize,
    },
    TextBlockPlainLenMismatch {
        block_index: usize,
        expected: u32,
        actual: u32,
    },
    ImageBlockPlainLenInvalid {
        block_index: usize,
    },
    ImageBlockPlaceholderMismatch {
        block_index: usize,
        plain_start: u32,
    },
    RebuiltPlainMismatch,
    SourcePreservedHasImageBlocks {
        count: usize,
    },
}

impl fmt::Display for PlainProjectionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ImagePlaceholderCountMismatch {
                blocks,
                placeholders,
            } => {
                write!(f, "image blocks ({blocks}) != FFFC count ({placeholders})")
            }
            Self::PlainLengthMismatch {
                expected_len,
                actual_len,
            } => {
                write!(f, "plain char len {actual_len} != expected {expected_len}")
            }
            Self::BlockPlainOutOfRange {
                block_index,
                plain_start,
                plain_len,
                plain_len_total,
            } => {
                write!(
                    f,
                    "block {block_index} plain [{plain_start}, {}) exceeds plain len {plain_len_total}",
                    plain_start.saturating_add(*plain_len)
                )
            }
            Self::TextBlockContentMismatch { block_index } => {
                write!(f, "text block {block_index} text != plain slice")
            }
            Self::TextBlockPlainLenMismatch {
                block_index,
                expected,
                actual,
            } => {
                write!(
                    f,
                    "text block {block_index} plain_len {actual} != text chars {expected}"
                )
            }
            Self::ImageBlockPlainLenInvalid { block_index } => {
                write!(f, "image block {block_index} plain_len != 1")
            }
            Self::ImageBlockPlaceholderMismatch {
                block_index,
                plain_start,
            } => {
                write!(
                    f,
                    "image block {block_index} plain[{plain_start}] != U+FFFC"
                )
            }
            Self::RebuiltPlainMismatch => write!(f, "block-joined rebuild != plain_text"),
            Self::SourcePreservedHasImageBlocks { count } => {
                write!(
                    f,
                    "source-preserved IR must not contain {count} image block(s)"
                )
            }
        }
    }
}

impl std::error::Error for PlainProjectionError {}

/// 按 Unicode 字符索引切片（与 `charOffset` 语义一致）。
pub fn slice_by_char_range(text: &str, start: u32, len: u32) -> String {
    text.chars()
        .skip(start as usize)
        .take(len as usize)
        .collect()
}

/// 将 [`RichTextSpan`] 流按块内字符范围裁剪（分页切片用）。
pub fn slice_rich_spans(spans: &[RichTextSpan], start: u32, len: u32) -> Vec<RichTextSpan> {
    if len == 0 || spans.is_empty() {
        return Vec::new();
    }
    let end = start.saturating_add(len);
    let mut cursor = 0u32;
    let mut out = Vec::new();

    for span in spans {
        let full = span.text();
        let span_len = full.chars().count() as u32;
        let span_start = cursor;
        let span_end = cursor.saturating_add(span_len);
        cursor = span_end;

        if span_end <= start || span_start >= end {
            continue;
        }

        let overlap_start = start.saturating_sub(span_start);
        let overlap_end = end.saturating_sub(span_start).min(span_len);
        let slice_len = overlap_end.saturating_sub(overlap_start);
        if slice_len == 0 {
            continue;
        }
        let text = slice_by_char_range(full, overlap_start, slice_len);
        out.push(clone_span_with_text(span, text));
    }
    out
}

fn clone_span_with_text(span: &RichTextSpan, text: String) -> RichTextSpan {
    match span {
        RichTextSpan::Styled(style, _) => RichTextSpan::Styled(*style, RichTextSpanData { text }),
        RichTextSpan::Link { data: _, url } => RichTextSpan::Link {
            data: RichTextSpanData { text },
            url: url.clone(),
        },
    }
}

/// 块级 `\n` 分隔符（ADR-007 单换行）。
pub fn append_block_separator(plain: &mut String, plain_cursor: &mut u32) {
    if plain.is_empty() || plain.ends_with('\n') {
        return;
    }
    plain.push('\n');
    *plain_cursor += 1;
}

/// 从块流按 BlockJoined 规则重建 plain。
pub fn project_block_joined(blocks: &[ContentBlock]) -> String {
    let mut plain = String::new();
    let mut cursor = 0u32;

    for block in blocks {
        match block {
            ContentBlock::Text(t) => {
                append_block_separator(&mut plain, &mut cursor);
                plain.push_str(&t.text);
                cursor += t.text.chars().count() as u32;
            }
            ContentBlock::Image(_) => {
                append_block_separator(&mut plain, &mut cursor);
                plain.push(IMAGE_PLAIN_PLACEHOLDER);
                cursor += 1;
            }
        }
    }

    plain
}

/// BlockJoined 增量构建器（EPUB HTML → IR 使用）。
#[derive(Debug, Default)]
pub struct BlockJoinedPlainBuilder {
    blocks: Vec<ContentBlock>,
    plain: String,
    cursor: u32,
}

impl BlockJoinedPlainBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn push_text(&mut self, text: String, style: TextBlockStyle) {
        self.push_text_spans(text, style, Vec::new());
    }

    pub fn push_text_spans(
        &mut self,
        text: String,
        style: TextBlockStyle,
        spans: Vec<RichTextSpan>,
    ) {
        if text.trim().is_empty() {
            return;
        }
        append_block_separator(&mut self.plain, &mut self.cursor);
        let start = self.cursor;
        self.plain.push_str(&text);
        self.cursor += text.chars().count() as u32;
        let block = if spans.is_empty() {
            TextBlock::new(start, text, style)
        } else {
            TextBlock::with_spans(start, spans, style)
        };
        self.blocks.push(ContentBlock::Text(block));
    }

    pub fn push_image(&mut self, asset_id: String, alt: Option<String>) {
        append_block_separator(&mut self.plain, &mut self.cursor);
        let start = self.cursor;
        self.plain.push(IMAGE_PLAIN_PLACEHOLDER);
        self.cursor += 1;
        self.blocks
            .push(ContentBlock::Image(ImageBlock::new(start, asset_id, alt)));
    }

    pub fn image_block_count(&self) -> usize {
        self.blocks
            .iter()
            .filter(|b| matches!(b, ContentBlock::Image(_)))
            .count()
    }

    pub fn finish(self) -> ChapterContentIr {
        ChapterContentIr::new(self.blocks, self.plain)
    }
}

/// 将已有章 IR 的块追加进 builder（multi-spine 合并用）。
pub fn append_chapter_ir_to_builder(builder: &mut BlockJoinedPlainBuilder, ir: ChapterContentIr) {
    for block in ir.blocks {
        match block {
            ContentBlock::Text(t) => builder.push_text_spans(t.text, t.style, t.spans),
            ContentBlock::Image(img) => builder.push_image(img.asset_id, img.alt),
        }
    }
}

/// 校验章 IR 的 plain 投影（ADR-008 + ADR-001）。
pub fn validate_chapter_plain(
    ir: &ChapterContentIr,
    style: PlainProjectionStyle,
) -> Result<(), PlainProjectionError> {
    let plain_len = ir.plain_text.chars().count() as u32;

    if ir.image_block_count() != ir.image_placeholder_count() {
        return Err(PlainProjectionError::ImagePlaceholderCountMismatch {
            blocks: ir.image_block_count(),
            placeholders: ir.image_placeholder_count(),
        });
    }

    if style == PlainProjectionStyle::SourcePreserved && ir.image_block_count() > 0 {
        return Err(PlainProjectionError::SourcePreservedHasImageBlocks {
            count: ir.image_block_count(),
        });
    }

    if style == PlainProjectionStyle::BlockJoined {
        let rebuilt = project_block_joined(&ir.blocks);
        if rebuilt != ir.plain_text {
            return Err(PlainProjectionError::RebuiltPlainMismatch);
        }
    }

    for (i, block) in ir.blocks.iter().enumerate() {
        let range = block.plain_range();
        if range.end_exclusive() > plain_len {
            return Err(PlainProjectionError::BlockPlainOutOfRange {
                block_index: i,
                plain_start: range.plain_start,
                plain_len: range.plain_len,
                plain_len_total: plain_len,
            });
        }

        match block {
            ContentBlock::Text(t) => {
                let expected_len = t.text.chars().count() as u32;
                if t.plain.plain_len != expected_len {
                    return Err(PlainProjectionError::TextBlockPlainLenMismatch {
                        block_index: i,
                        expected: expected_len,
                        actual: t.plain.plain_len,
                    });
                }
                let slice = slice_by_char_range(&ir.plain_text, range.plain_start, range.plain_len);
                if slice != t.text {
                    return Err(PlainProjectionError::TextBlockContentMismatch { block_index: i });
                }
                if !t.spans.is_empty() {
                    let joined: String = t.spans.iter().map(|s| s.text()).collect();
                    if joined != t.text {
                        return Err(PlainProjectionError::TextBlockContentMismatch {
                            block_index: i,
                        });
                    }
                }
            }
            ContentBlock::Image(img) => {
                if img.plain.plain_len != IMAGE_PLAIN_CHAR_LEN || !img.validate_plain() {
                    return Err(PlainProjectionError::ImageBlockPlainLenInvalid { block_index: i });
                }
                let ch = slice_by_char_range(&ir.plain_text, range.plain_start, 1);
                if ch != IMAGE_PLAIN_PLACEHOLDER.to_string() {
                    return Err(PlainProjectionError::ImageBlockPlaceholderMismatch {
                        block_index: i,
                        plain_start: range.plain_start,
                    });
                }
            }
        }
    }

    Ok(())
}

impl ChapterContentIr {
    /// 章级 plain 字符数（`charOffset` 上界）。
    pub fn plain_char_count(&self) -> u32 {
        self.plain_text.chars().count() as u32
    }

    /// 读取 plain 中某字符（越界返回 `None`）。
    pub fn char_at_offset(&self, char_offset: u32) -> Option<char> {
        self.plain_text.chars().nth(char_offset as usize)
    }

    /// plain 切片 `[start, start+len)`（字符索引）。
    pub fn plain_slice(&self, start: u32, len: u32) -> String {
        slice_by_char_range(&self.plain_text, start, len)
    }

    /// 校验 plain 投影。
    pub fn validate_plain(&self, style: PlainProjectionStyle) -> Result<(), PlainProjectionError> {
        validate_chapter_plain(self, style)
    }

    /// `charOffset` 落在哪个块（半开区间 `[plain_start, plain_start+plain_len)`）。
    pub fn block_index_at_offset(&self, char_offset: u32) -> Option<usize> {
        self.blocks.iter().position(|b| {
            let r = b.plain_range();
            char_offset >= r.plain_start && char_offset < r.end_exclusive()
        })
    }

    /// `charOffset` 是否落在 Image 占位符 `\uFFFC` 上。
    pub fn is_image_placeholder_offset(&self, char_offset: u32) -> bool {
        self.char_at_offset(char_offset) == Some(IMAGE_PLAIN_PLACEHOLDER)
    }

    /// 按 `plain_start` 精确匹配 Image 块（TTS / 书签恢复用）。
    pub fn image_block_at_offset(&self, char_offset: u32) -> Option<&ImageBlock> {
        self.blocks.iter().find_map(|b| match b {
            ContentBlock::Image(img) if img.plain.plain_start == char_offset => Some(img),
            _ => None,
        })
    }

    /// TTS：占位符处返回 `alt`；否则返回 `None`（由调用方朗读 Text 切片）。
    pub fn tts_alt_at_offset(&self, char_offset: u32) -> Option<&str> {
        self.image_block_at_offset(char_offset)
            .and_then(|img| img.alt.as_deref())
            .filter(|alt| !alt.is_empty())
    }

    /// 搜索用：跳过 `\uFFFC` 的可匹配字符数（位置仍用原 `charOffset`）。
    pub fn searchable_char_count(&self) -> u32 {
        self.plain_text
            .chars()
            .filter(|&c| c != IMAGE_PLAIN_PLACEHOLDER)
            .count() as u32
    }

    /// 搜索用：某 `charOffset` 是否参与 token 匹配（ADR-008：忽略 `\uFFFC`）。
    pub fn is_searchable_offset(&self, char_offset: u32) -> bool {
        self.char_at_offset(char_offset)
            .is_some_and(|c| c != IMAGE_PLAIN_PLACEHOLDER)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pipeline::{
        ContentBlock, TextBlock, TextBlockStyle,
        IMAGE_PLAIN_PLACEHOLDER,
    };

    #[test]
    fn block_joined_builder_matches_manual_epub() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello".into(), TextBlockStyle::default());
        b.push_text("World".into(), TextBlockStyle::default());
        let ir = b.finish();
        assert_eq!(ir.plain_text, "Hello\nWorld");
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
    }

    #[test]
    fn block_joined_with_image_adr008() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("before".into(), TextBlockStyle::default());
        b.push_image("pic.jpg".into(), Some("cover".into()));
        b.push_text("after".into(), TextBlockStyle::default());
        let ir = b.finish();
        assert_eq!(
            ir.plain_text,
            format!("before\n{IMAGE_PLAIN_PLACEHOLDER}\nafter")
        );
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
        assert!(ir.is_image_placeholder_offset(7));
        assert_eq!(ir.tts_alt_at_offset(7), Some("cover"));
        assert!(!ir.is_searchable_offset(7));
        assert!(ir.is_searchable_offset(0));
    }

    #[test]
    fn source_preserved_txt_validation() {
        let ir = ChapterContentIr::new(
            vec![
                ContentBlock::Text(TextBlock::new(
                    0,
                    "First\n".into(),
                    TextBlockStyle::default(),
                )),
                ContentBlock::Text(TextBlock::new(
                    7,
                    "Second".into(),
                    TextBlockStyle::default(),
                )),
            ],
            "First\n\nSecond".to_string(),
        );
        ir.validate_plain(PlainProjectionStyle::SourcePreserved)
            .unwrap();
        assert_eq!(ir.block_index_at_offset(0), Some(0));
        assert_eq!(ir.block_index_at_offset(6), None);
        assert_eq!(ir.block_index_at_offset(7), Some(1));
    }

    #[test]
    fn validate_rejects_mismatched_plain() {
        let ir = ChapterContentIr::new(
            vec![ContentBlock::Text(TextBlock::new(
                0,
                "Hi".into(),
                TextBlockStyle::default(),
            ))],
            "Ho".into(),
        );
        assert_eq!(
            ir.validate_plain(PlainProjectionStyle::BlockJoined),
            Err(PlainProjectionError::RebuiltPlainMismatch)
        );
    }

    #[test]
    fn project_block_joined_empty() {
        assert!(project_block_joined(&[]).is_empty());
    }

    #[test]
    fn slice_rich_spans_preserves_style() {
        use crate::pipeline::{RichTextSpan, RichTextSpanData, SpanStyle};

        let spans = vec![
            RichTextSpan::Styled(
                SpanStyle::Plain,
                RichTextSpanData {
                    text: "Hello ".into(),
                },
            ),
            RichTextSpan::Styled(
                SpanStyle::Bold,
                RichTextSpanData {
                    text: "bold".into(),
                },
            ),
            RichTextSpan::Styled(
                SpanStyle::Plain,
                RichTextSpanData {
                    text: " world".into(),
                },
            ),
        ];
        let sliced = slice_rich_spans(&spans, 6, 4);
        assert_eq!(sliced.len(), 1);
        assert!(matches!(
            sliced[0],
            RichTextSpan::Styled(SpanStyle::Bold, _)
        ));
        assert_eq!(sliced[0].text(), "bold");
    }

    #[test]
    fn frb_sample_blocks_match_block_joined() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("sample".into(), TextBlockStyle::default());
        // b.push_image("sample_asset".into(), None);
        let ir = b.finish();
        assert_eq!(ir.plain_text, format!("sample\n{IMAGE_PLAIN_PLACEHOLDER}"));
        assert_eq!(ir.blocks[1].plain_range().plain_start, 7);
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
    }
}
