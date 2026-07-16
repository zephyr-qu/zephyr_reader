// ============================================================
// 文件作用：BlockJoined 增量构建器，将文本和图片块拼接为 ReaderChapterIr
//
// 公有类型/函数：
//   - struct BlockJoinedPlainBuilder — BlockJoined 增量构建器
//   - fn append_chapter_ir_to_builder() — 合并多 spine IR 到 builder
//   - fn append_block_separator() — 块间 \n 分隔符
// ============================================================

//! BlockJoined 增量构建器
//! 将文本和图片块按 BlockJoined 规则拼接为 ReaderChapterIr
//! 投影/校验委托给 plain_projector 模块

use crate::pipeline::types::{
    BlockStyle, ReaderChapterIr, ReaderInlineRun, ReaderIrBlock, ReaderIrBlockKind,
    IMAGE_PLAIN_PLACEHOLDER,
};

/// 块级 `\n` 分隔符（ADR-007 单换行）。
pub fn append_block_separator(plain: &mut String, plain_cursor: &mut u32) {
    if plain.is_empty() || plain.ends_with('\n') {
        return;
    }
    plain.push('\n');
    *plain_cursor += 1;
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
    pub fn push_text(&mut self, text: String, style: BlockStyle) {
        self.push_text_spans(text, Vec::new(), style);
    }

    pub fn push_text_spans(&mut self, text: String, runs: Vec<ReaderInlineRun>, style: BlockStyle) {
        if text.trim().is_empty() {
            return;
        }
        append_block_separator(&mut self.plain, &mut self.cursor);
        let start = self.cursor;
        self.plain.push_str(&text);
        self.cursor += text.chars().count() as u32;
        self.blocks
            .push(ReaderIrBlock::text(start, text, runs, style));
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
                builder.push_text_spans(block.text, block.runs, block.style);
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pipeline::types::BlockStyle;

    #[test]
    fn block_joined_builder_matches_manual_epub() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello".into(), BlockStyle::empty());
        b.push_text("World".into(), BlockStyle::empty());
        let ir = b.finish();
        assert_eq!(ir.plain_text, "Hello\nWorld");
        ir.validate_plain(crate::pipeline::plain_projector::PlainProjectionStyle::BlockJoined)
            .unwrap();
    }

    #[test]
    fn block_joined_with_image_adr008() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("before".into(), BlockStyle::empty());
        b.push_image("pic.jpg".into(), Some("cover".into()), None, None);
        b.push_text("after".into(), BlockStyle::empty());
        let ir = b.finish();
        assert_eq!(
            ir.plain_text,
            format!("before\n{IMAGE_PLAIN_PLACEHOLDER}\nafter")
        );
        ir.validate_plain(crate::pipeline::plain_projector::PlainProjectionStyle::BlockJoined)
            .unwrap();
        assert!(ir.is_image_placeholder_offset(7));
        assert_eq!(ir.tts_alt_at_offset(7), Some("cover"));
        assert!(!ir.is_searchable_offset(7));
        assert!(ir.is_searchable_offset(0));
    }

    #[test]
    fn frb_sample_blocks_match_block_joined() {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("sample".into(), BlockStyle::empty());
        b.push_image("sample_asset".into(), None, None, None);
        let ir = b.finish();
        assert_eq!(ir.plain_text, format!("sample\n{IMAGE_PLAIN_PLACEHOLDER}"));
        assert_eq!(ir.blocks[1].plain_start, 7);
        ir.validate_plain(crate::pipeline::plain_projector::PlainProjectionStyle::BlockJoined)
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
        ir.validate_plain(crate::pipeline::plain_projector::PlainProjectionStyle::BlockJoined)
            .unwrap();
    }
}
