// ============================================================
// 文件作用：IR 到 plain text 投影及校验
//
// 公有类型/函数：
//   - enum PlainProjectionStyle — plain 投影风格
//   - enum PlainProjectionError — 投影校验失败原因
//   - fn slice_by_char_range() — 按 Unicode 字符索引切片
//   - fn slice_inline_runs() — 裁剪 ReaderInlineRun 流
//   - fn append_block_separator() — 块间 \n 分隔符
//   - fn project_block_joined() — 从块流重建 plain
//   - struct BlockJoinedPlainBuilder — BlockJoined 增量构建器
//   - fn append_chapter_ir_to_builder() — 合并多 spine IR 到 builder
//   - fn validate_chapter_plain() — 校验章 IR plain 投影
//   - impl ReaderChapterIr 方法 — 字符读取、搜索、TTS 辅助
// ============================================================

use std::fmt;

use crate::pipeline::types::{
    ReaderChapterIr, ReaderInlineRun, ReaderIrBlock, ReaderIrBlockKind, IMAGE_PLAIN_CHAR_LEN,
    IMAGE_PLAIN_PLACEHOLDER,
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

/// 将 [`ReaderInlineRun`] 流按块内字符范围裁剪（分页切片用）。
pub fn slice_inline_runs(runs: &[ReaderInlineRun], start: u32, len: u32) -> Vec<ReaderInlineRun> {
    if len == 0 || runs.is_empty() {
        return Vec::new();
    }
    let end = start.saturating_add(len);
    let mut cursor = 0u32;
    let mut out = Vec::new();

    for run in runs {
        let span_len = run.text.chars().count() as u32;
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
        let text = slice_by_char_range(&run.text, overlap_start, slice_len);
        out.push(ReaderInlineRun {
            text,
            style: run.style,
            url: run.url.clone(),
        });
    }
    out
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
pub fn project_block_joined(blocks: &[ReaderIrBlock]) -> String {
    let mut plain = String::new();
    let mut cursor = 0u32;

    for block in blocks {
        match block.kind {
            ReaderIrBlockKind::Text => {
                append_block_separator(&mut plain, &mut cursor);
                plain.push_str(&block.text);
                cursor += block.text.chars().count() as u32;
            }
            ReaderIrBlockKind::Image => {
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
    blocks: Vec<ReaderIrBlock>,
    plain: String,
    cursor: u32,
}

impl BlockJoinedPlainBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    #[allow(clippy::too_many_arguments)]
    pub fn push_text(
        &mut self,
        text: String,
        is_heading: bool,
        heading_level: u8,
        text_indent_em: Option<f32>,
        margin_top_em: Option<f32>,
        margin_bottom_em: Option<f32>,
        text_align: Option<String>,
        font_size: Option<f32>,
    ) {
        self.push_text_spans(
            text,
            Vec::new(),
            is_heading,
            heading_level,
            text_indent_em,
            margin_top_em,
            margin_bottom_em,
            text_align,
            font_size,
        );
    }

    #[allow(clippy::too_many_arguments)]
    pub fn push_text_spans(
        &mut self,
        text: String,
        runs: Vec<ReaderInlineRun>,
        is_heading: bool,
        heading_level: u8,
        text_indent_em: Option<f32>,
        margin_top_em: Option<f32>,
        margin_bottom_em: Option<f32>,
        text_align: Option<String>,
        font_size: Option<f32>,
    ) {
        if text.trim().is_empty() {
            return;
        }
        append_block_separator(&mut self.plain, &mut self.cursor);
        let start = self.cursor;
        self.plain.push_str(&text);
        self.cursor += text.chars().count() as u32;
        self.blocks.push(ReaderIrBlock::text(
            start,
            text,
            runs,
            is_heading,
            heading_level,
            text_indent_em,
            margin_top_em,
            margin_bottom_em,
            text_align,
            font_size,
        ));
    }

    pub fn push_image(
        &mut self,
        asset_id: String,
        alt: Option<String>,
        intrinsic_width: Option<u32>,
        intrinsic_height: Option<u32>,
    ) {
        append_block_separator(&mut self.plain, &mut self.cursor);
        let start = self.cursor;
        self.plain.push(IMAGE_PLAIN_PLACEHOLDER);
        self.cursor += 1;
        self.blocks.push(ReaderIrBlock::image(
            start,
            asset_id,
            alt,
            intrinsic_width,
            intrinsic_height,
        ));
    }

    pub fn image_block_count(&self) -> usize {
        self.blocks
            .iter()
            .filter(|b| b.kind == ReaderIrBlockKind::Image)
            .count()
    }

    pub fn finish(self) -> ReaderChapterIr {
        ReaderChapterIr::new(self.blocks, self.plain)
    }
}

/// 将已有章 IR 的块追加进 builder（multi-spine 合并用）。
pub fn append_chapter_ir_to_builder(builder: &mut BlockJoinedPlainBuilder, ir: ReaderChapterIr) {
    for block in ir.blocks {
        match block.kind {
            ReaderIrBlockKind::Text => {
                builder.push_text_spans(
                    block.text,
                    block.runs,
                    block.is_heading,
                    block.heading_level,
                    block.text_indent_em,
                    block.margin_top_em,
                    block.margin_bottom_em,
                    block.text_align,
                    block.font_size,
                );
            }
            ReaderIrBlockKind::Image => {
                builder.push_image(
                    block.image_asset_id.unwrap_or_default(),
                    block.image_alt,
                    block.image_intrinsic_width,
                    block.image_intrinsic_height,
                );
            }
        }
    }
}

/// 校验章 IR 的 plain 投影（ADR-008 + ADR-001）。
pub fn validate_chapter_plain(
    ir: &ReaderChapterIr,
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
        let block_end = block.plain_start.saturating_add(block.plain_len);
        if block_end > plain_len {
            return Err(PlainProjectionError::BlockPlainOutOfRange {
                block_index: i,
                plain_start: block.plain_start,
                plain_len: block.plain_len,
                plain_len_total: plain_len,
            });
        }

        match block.kind {
            ReaderIrBlockKind::Text => {
                let expected_len = block.text.chars().count() as u32;
                if block.plain_len != expected_len {
                    return Err(PlainProjectionError::TextBlockPlainLenMismatch {
                        block_index: i,
                        expected: expected_len,
                        actual: block.plain_len,
                    });
                }
                let slice = slice_by_char_range(&ir.plain_text, block.plain_start, block.plain_len);
                if slice != block.text {
                    return Err(PlainProjectionError::TextBlockPlainLenMismatch {
                        block_index: i,
                        expected: expected_len,
                        actual: block.plain_len,
                    });
                }
                if !block.runs.is_empty() {
                    let joined: String = block.runs.iter().map(|r| r.text.as_str()).collect();
                    if joined != block.text {
                        return Err(PlainProjectionError::TextBlockPlainLenMismatch {
                            block_index: i,
                            expected: expected_len,
                            actual: block.plain_len,
                        });
                    }
                }
            }
            ReaderIrBlockKind::Image => {
                if block.plain_len != IMAGE_PLAIN_CHAR_LEN {
                    return Err(PlainProjectionError::ImageBlockPlainLenInvalid { block_index: i });
                }
                let ch = slice_by_char_range(&ir.plain_text, block.plain_start, 1);
                if ch != IMAGE_PLAIN_PLACEHOLDER.to_string() {
                    return Err(PlainProjectionError::ImageBlockPlaceholderMismatch {
                        block_index: i,
                        plain_start: block.plain_start,
                    });
                }
            }
        }
    }

    Ok(())
}

// ==================== ReaderChapterIr 实例方法 ====================

impl ReaderChapterIr {
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
            char_offset >= b.plain_start && char_offset < b.plain_start.saturating_add(b.plain_len)
        })
    }

    /// `charOffset` 是否落在 Image 占位符 `\uFFFC` 上。
    pub fn is_image_placeholder_offset(&self, char_offset: u32) -> bool {
        self.char_at_offset(char_offset) == Some(IMAGE_PLAIN_PLACEHOLDER)
    }

    /// 按 `plain_start` 精确匹配 Image 块（TTS / 书签恢复用）。
    pub fn image_block_at_offset(&self, char_offset: u32) -> Option<&ReaderIrBlock> {
        self.blocks
            .iter()
            .find(|b| b.kind == ReaderIrBlockKind::Image && b.plain_start == char_offset)
    }

    /// TTS：占位符处返回 `alt`；否则返回 `None`（由调用方朗读 Text 切片）。
    pub fn tts_alt_at_offset(&self, char_offset: u32) -> Option<&str> {
        self.image_block_at_offset(char_offset)
            .and_then(|img| img.image_alt.as_deref())
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
    use crate::pipeline::types::ReaderInlineStyle;

    #[test]
    fn block_joined_builder_matches_manual_epub() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello".into(), false, 0, None, None, None, None, None);
        b.push_text("World".into(), false, 0, None, None, None, None, None);
        let ir = b.finish();
        assert_eq!(ir.plain_text, "Hello\nWorld");
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
    }

    #[test]
    fn block_joined_with_image_adr008() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("before".into(), false, 0, None, None, None, None, None);
        b.push_image("pic.jpg".into(), Some("cover".into()), None, None);
        b.push_text("after".into(), false, 0, None, None, None, None, None);
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
        let ir = ReaderChapterIr::new(
            vec![
                ReaderIrBlock::text(
                    0,
                    "First\n".into(),
                    Vec::new(),
                    false,
                    0,
                    None,
                    None,
                    None,
                    None,
                    None,
                ),
                ReaderIrBlock::text(
                    7,
                    "Second".into(),
                    Vec::new(),
                    false,
                    0,
                    None,
                    None,
                    None,
                    None,
                    None,
                ),
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
        let ir = ReaderChapterIr::new(
            vec![ReaderIrBlock::text(
                0,
                "Hi".into(),
                Vec::new(),
                false,
                0,
                None,
                None,
                None,
                None,
                None,
            )],
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
    fn slice_inline_runs_preserves_style() {
        let runs = vec![
            ReaderInlineRun {
                text: "Hello ".into(),
                style: ReaderInlineStyle::Plain,
                url: None,
            },
            ReaderInlineRun {
                text: "bold".into(),
                style: ReaderInlineStyle::Bold,
                url: None,
            },
            ReaderInlineRun {
                text: " world".into(),
                style: ReaderInlineStyle::Plain,
                url: None,
            },
        ];
        let sliced = slice_inline_runs(&runs, 6, 4);
        assert_eq!(sliced.len(), 1);
        assert_eq!(sliced[0].style, ReaderInlineStyle::Bold);
        assert_eq!(sliced[0].text, "bold");
    }

    #[test]
    fn frb_sample_blocks_match_block_joined() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("sample".into(), false, 0, None, None, None, None, None);
        b.push_image("sample_asset".into(), None, None, None);
        let ir = b.finish();
        assert_eq!(ir.plain_text, format!("sample\n{IMAGE_PLAIN_PLACEHOLDER}"));
        assert_eq!(ir.blocks[1].plain_start, 7);
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
    }

    #[test]
    fn append_chapter_ir_preserves_image_intrinsic_size() {
        let source = ReaderChapterIr::new(
            vec![ReaderIrBlock::image(
                0,
                "img_main".into(),
                Some("cover".into()),
                Some(640),
                Some(960),
            )],
            IMAGE_PLAIN_PLACEHOLDER.to_string(),
        );

        let mut builder = BlockJoinedPlainBuilder::new();
        append_chapter_ir_to_builder(&mut builder, source);
        let ir = builder.finish();
        let image = &ir.blocks[0];

        assert_eq!(image.image_asset_id.as_deref(), Some("img_main"));
        assert_eq!(image.image_alt.as_deref(), Some("cover"));
        assert_eq!(image.image_intrinsic_width, Some(640));
        assert_eq!(image.image_intrinsic_height, Some(960));
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .unwrap();
    }
}
