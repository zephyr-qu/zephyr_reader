// ============================================================
// 文件作用：IR 到 plain text 投影及校验
//
// 公有类型/函数：
//   - enum PlainProjectionStyle — plain 投影风格
//   - enum PlainProjectionError — 投影校验失败原因
//   - fn slice_by_utf16_range() — 按 UTF-16 code-unit 索引安全切片
//   - fn slice_inline_runs() — 裁剪 ReaderInlineRun 流
//   - fn project_block_joined() — 从块流重建 plain
//   - fn validate_chapter_plain() — 校验章 IR plain 投影
//   - impl ReaderChapterIr 方法 — 字符读取、搜索、TTS 辅助
// ============================================================

//! IR 到 plain text 投影及校验
//! 提供 plain text 投影算法、校验逻辑和 ReaderChapterIr 实例方法

use std::fmt;

use crate::pipeline::types::{
    IMAGE_PLAIN_CHAR_LEN, IMAGE_PLAIN_PLACEHOLDER, ReaderChapterIr, ReaderInlineRun, ReaderIrBlock,
    ReaderIrBlockKind,
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

/// 返回字符串的 UTF-16 code-unit 长度。
pub fn utf16_len(text: &str) -> u32 {
    text.encode_utf16().count() as u32
}

/// 将 UTF-16 code-unit offset 映射为 UTF-8 byte index。
///
/// 落在代理对中间或越界时返回 `None`，避免静默切坏 Unicode scalar。
fn byte_index_at_utf16_offset(text: &str, offset: u32) -> Option<usize> {
    if offset == 0 {
        return Some(0);
    }

    let mut utf16_cursor = 0u32;
    for (byte_index, ch) in text.char_indices() {
        if utf16_cursor == offset {
            return Some(byte_index);
        }
        utf16_cursor = utf16_cursor.saturating_add(ch.len_utf16() as u32);
        if utf16_cursor > offset {
            return None;
        }
    }

    (utf16_cursor == offset).then_some(text.len())
}

/// 按 UTF-16 code-unit 半开区间安全切片。
pub fn slice_by_utf16_range(text: &str, start: u32, len: u32) -> Option<&str> {
    let end = start.checked_add(len)?;
    let start_byte = byte_index_at_utf16_offset(text, start)?;
    let end_byte = byte_index_at_utf16_offset(text, end)?;
    text.get(start_byte..end_byte)
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
        let span_len = utf16_len(&run.text);
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
        let Some(text) = slice_by_utf16_range(&run.text, overlap_start, slice_len) else {
            continue;
        };
        out.push(ReaderInlineRun {
            text: text.to_string(),
            style: run.style,
            url: run.url.clone(),
        });
    }
    out
}

/// 从块流按 BlockJoined 规则重建 plain。
pub fn project_block_joined(blocks: &[ReaderIrBlock]) -> String {
    let mut plain = String::new();
    let mut cursor = 0u32;

    for block in blocks {
        match block.kind {
            ReaderIrBlockKind::Text => {
                super::block_joined_builder::append_block_separator(&mut plain, &mut cursor);
                plain.push_str(&block.text);
                cursor += utf16_len(&block.text);
            }
            ReaderIrBlockKind::Image => {
                super::block_joined_builder::append_block_separator(&mut plain, &mut cursor);
                plain.push(IMAGE_PLAIN_PLACEHOLDER);
                cursor += 1;
            }
        }
    }

    plain
}

/// 校验章 IR 的 plain 投影（ADR-008 + ADR-001）。
pub fn validate_chapter_plain(
    ir: &ReaderChapterIr,
    style: PlainProjectionStyle,
) -> Result<(), PlainProjectionError> {
    let plain_len = utf16_len(&ir.plain_text);

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
                let expected_len = utf16_len(&block.text);
                if block.plain_len != expected_len {
                    return Err(PlainProjectionError::TextBlockPlainLenMismatch {
                        block_index: i,
                        expected: expected_len,
                        actual: block.plain_len,
                    });
                }
                let slice =
                    slice_by_utf16_range(&ir.plain_text, block.plain_start, block.plain_len);
                if slice != Some(block.text.as_str()) {
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
                let ch = slice_by_utf16_range(&ir.plain_text, block.plain_start, 1);
                if ch != Some("\u{FFFC}") {
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
    /// 章级 plain UTF-16 code-unit 数（`charOffset` 上界）。
    pub fn plain_char_count(&self) -> u32 {
        utf16_len(&self.plain_text)
    }

    /// 读取 UTF-16 offset 起始处的 Unicode scalar（代理对中间返回 `None`）。
    pub fn char_at_offset(&self, char_offset: u32) -> Option<char> {
        let byte_index = byte_index_at_utf16_offset(&self.plain_text, char_offset)?;
        self.plain_text.get(byte_index..)?.chars().next()
    }

    /// plain 切片 `[start, start+len)`（UTF-16 code-unit 索引）。
    pub fn plain_slice(&self, start: u32, len: u32) -> Option<&str> {
        slice_by_utf16_range(&self.plain_text, start, len)
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
    use crate::pipeline::types::{BlockStyle, ReaderInlineStyle};

    #[test]
    fn source_preserved_txt_validation() {
        let ir = ReaderChapterIr::new(
            vec![
                ReaderIrBlock::text(0, "First\n".into(), Vec::new(), BlockStyle::empty()),
                ReaderIrBlock::text(7, "Second".into(), Vec::new(), BlockStyle::empty()),
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
                BlockStyle::empty(),
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
    fn utf16_ranges_reject_surrogate_pair_midpoints() {
        let text = "A😀B";
        assert_eq!(utf16_len(text), 4);
        assert_eq!(slice_by_utf16_range(text, 1, 2), Some("😀"));
        assert_eq!(slice_by_utf16_range(text, 2, 1), None);
        assert_eq!(slice_by_utf16_range(text, 0, 4), Some(text));
    }

    #[test]
    fn inline_runs_slice_with_utf16_offsets() {
        let runs = vec![ReaderInlineRun {
            text: "A😀B".into(),
            style: ReaderInlineStyle::Bold,
            url: None,
        }];

        let sliced = slice_inline_runs(&runs, 1, 2);
        assert_eq!(sliced.len(), 1);
        assert_eq!(sliced[0].text, "😀");
    }
}
