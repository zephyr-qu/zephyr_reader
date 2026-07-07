//! EPUB HTML → Phase 2 章节 IR（M1.1）
//!
//! 复用 `parse_html_to_rich_text` 保持 DOM 顺序与 scroll 路径一致；
//! plain 投影见 `domain::BlockJoinedPlainBuilder`（ADR-008）。

use super::asset_registry::{canonicalize_chapter_image_assets, normalize_asset_id};
use crate::domain::{
    append_chapter_ir_to_builder, AppError, BlockJoinedPlainBuilder, ChapterContentIr,
    ContentBlock, PlainProjectionStyle, RichParagraph, TextBlockStyle,
};
use crate::text::rich_text;

use super::provider::EpubContentProvider;

/// 与 `get_chapter_content_rich` 相同：单个 html5ever 片段超过此值则分块或降级。
const MAX_HTML_CHUNK_BYTES: usize = 100 * 1024;

/// 在块级标签边界拆分 oversized HTML，使每段可独立 html5ever 解析。
fn split_html_at_block_boundaries(html: &str, max_bytes: usize) -> Vec<String> {
    if html.len() <= max_bytes {
        return vec![html.to_string()];
    }

    const BOUNDARY_TAGS: [&str; 9] = [
        "</p>",
        "</div>",
        "</section>",
        "</li>",
        "</h1>",
        "</h2>",
        "</h3>",
        "</blockquote>",
        "<img",
    ];

    let mut chunks = Vec::new();
    let mut start = 0;

    while start < html.len() {
        let tail = &html[start..];
        if tail.len() <= max_bytes {
            chunks.push(tail.to_string());
            break;
        }

        let window_end = utf8_safe_byte_index(tail, max_bytes);
        let split_end = find_last_block_boundary(tail, window_end, &BOUNDARY_TAGS)
            .unwrap_or(window_end);

        let end = if split_end == 0 { window_end } else { split_end };
        chunks.push(tail[..end].to_string());
        start += end;
    }

    chunks
}

fn utf8_safe_byte_index(text: &str, max_bytes: usize) -> usize {
    if max_bytes >= text.len() {
        return text.len();
    }
    let mut end = max_bytes;
    while end > 0 && !text.is_char_boundary(end) {
        end -= 1;
    }
    end.max(1)
}

fn find_last_block_boundary(html: &str, max_end: usize, tags: &[&str]) -> Option<usize> {
    let slice = &html[..max_end];
    let lower = slice.to_ascii_lowercase();
    let mut best = 0usize;
    for tag in tags {
        let mut pos = 0usize;
        while let Some(found) = lower[pos..].find(tag) {
            let end = pos + found + tag.len();
            if end > best {
                best = end;
            }
            pos = end;
        }
    }
    if best >= max_end / 4 {
        Some(best)
    } else {
        None
    }
}

fn append_plain_html_to_builder(builder: &mut BlockJoinedPlainBuilder, html: &str) {
    use super::provider::html_to_plain_text;

    let plain = html_to_plain_text(html);
    for line in plain.split('\n') {
        let text = line.trim();
        if !text.is_empty() {
            builder.push_text(text.to_string(), TextBlockStyle::default());
        }
    }
}

/// 将单个 spine HTML 追加进章 IR builder（含 oversized 分块路径）。
fn append_spine_html_to_builder(
    builder: &mut BlockJoinedPlainBuilder,
    html: &str,
    registry: &super::asset_registry::EpubAssetRegistry,
    base: &str,
) -> Result<(), AppError> {
    if html.trim().is_empty() {
        return Ok(());
    }

    let pieces = split_html_at_block_boundaries(html, MAX_HTML_CHUNK_BYTES);
    if pieces.len() > 1 {
        tracing::info!(
            "[get_chapter_content_ir] spine HTML {} bytes split into {} chunks",
            html.len(),
            pieces.len(),
        );
    }

    for piece in pieces {
        if piece.trim().is_empty() {
            continue;
        }
        if piece.len() <= MAX_HTML_CHUNK_BYTES {
            match html_to_chapter_ir(&piece) {
                Ok(mut ir) => {
                    canonicalize_chapter_image_assets(&mut ir, registry, base);
                    append_chapter_ir_to_builder(builder, ir);
                }
                Err(e) => {
                    tracing::warn!(
                        "[get_chapter_content_ir] chunk IR parse failed ({} bytes), plain fallback: {e}",
                        piece.len(),
                    );
                    append_plain_html_to_builder(builder, &piece);
                }
            }
        } else {
            tracing::warn!(
                "[get_chapter_content_ir] chunk still {} bytes after split, plain fallback",
                piece.len(),
            );
            append_plain_html_to_builder(builder, &piece);
        }
    }
    Ok(())
}

/// EPUB CSS → TextBlockStyle 映射。
///
/// 当前为透传：所有 RichParagraph 上的 CSS 属性直接映射。
///
/// TODO(ponytail): 增加样式白名单过滤步骤。仅提取渲染/排版层实际使用的属性
/// （font_size / text_indent / margin / font_family / line_height / text_align / is_heading）。
/// 显式丢弃不支持的属性（color / background / border / float / position 等），
/// 减少 IR 体积和 BlockPaginator 的无用分支。
fn rich_paragraph_style(p: &RichParagraph) -> TextBlockStyle {
    // text_indent_em：仅 EPUB/CSS 显式值；None → Flutter/Rust 侧用用户首行缩进设置。
    let text_indent_em = if p.is_heading {
        Some(0.0)
    } else {
        p.text_indent_em
    };
    TextBlockStyle {
        is_heading: p.is_heading,
        heading_level: p.heading_level,
        text_indent_em,
        margin_top_em: p.margin_top_em,
        margin_bottom_em: p.margin_bottom_em,
        font_family: p.font_family.clone(),
        line_height: p.line_height,
        text_align: p.text_align.clone(),
        font_size: p.font_size,
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
        builder.push_text_spans(text, rich_paragraph_style(p), p.spans.clone());
    }

    builder.finish()
}

/// HTML 片段 → 章 IR（单元测试 / 无 EPUB 文件场景）。
pub fn html_to_chapter_ir(html: &str) -> Result<ChapterContentIr, AppError> {
    let paragraphs = rich_text::parse_html_to_rich_text(html)?;
    Ok(chapter_ir_from_rich_paragraphs(&paragraphs))
}


/// 从 PNG/JPEG 头部读取 intrinsic 尺寸（轻量，无完整解码）。
///
/// 移植自 Dart `scroll_list_metrics.dart:readImageDimensions`。
fn read_image_dimensions(bytes: &[u8]) -> Option<(u32, u32)> {
    // PNG: 检查 8-byte signature + IHDR chunk
    if bytes.len() >= 24
        && bytes[0] == 0x89
        && bytes[1] == 0x50
        && bytes[2] == 0x4E
        && bytes[3] == 0x47
    {
        let w = u32::from_be_bytes([bytes[16], bytes[17], bytes[18], bytes[19]]);
        let h = u32::from_be_bytes([bytes[20], bytes[21], bytes[22], bytes[23]]);
        if w > 0 && h > 0 {
            return Some((w, h));
        }
    }

    // JPEG: 扫描 SOF0/SOF1/SOF2 marker
    if bytes.len() >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
        let mut i = 2usize;
        while i + 9 < bytes.len() {
            if bytes[i] != 0xFF {
                i += 1;
                continue;
            }
            let marker = bytes[i + 1];
            if marker == 0xD9 || marker == 0xDA {
                break;
            }
            if i + 3 > bytes.len() {
                break;
            }
            let len = ((bytes[i + 2] as usize) << 8) | (bytes[i + 3] as usize);
            if len < 2 {
                break;
            }
            if matches!(marker, 0xC0..=0xC2) {
                if i + 9 > bytes.len() {
                    break;
                }
                let h = ((bytes[i + 5] as u32) << 8) | (bytes[i + 6] as u32);
                let w = ((bytes[i + 7] as u32) << 8) | (bytes[i + 8] as u32);
                if w > 0 && h > 0 {
                    return Some((w, h));
                }
            }
            i += 2 + len;
        }
    }

    None
}

/// 遍历章 IR 中所有 [ImageBlock]，从 EPUB 读取原始字节并解析 intrinsic 尺寸。
///
/// 解析失败时静默跳过（保留 None），分页器会回退到 `DEFAULT_IMAGE_HEIGHT_RATIO`。
fn resolve_image_dimensions(ir: &mut ChapterContentIr, provider: &EpubContentProvider) {
    for block in &mut ir.blocks {
        if let ContentBlock::Image(img) = block {
            if img.intrinsic_width.is_some() && img.intrinsic_height.is_some() {
                continue; // 已有尺寸，跳过
            }
            if let Some(data) = provider.read_resource_bytes(&img.asset_id)
                && let Some((w, h)) = read_image_dimensions(&data) {
                    img.intrinsic_width = Some(w);
                    img.intrinsic_height = Some(h);
                    tracing::debug!(
                        "[get_chapter_content_ir] image {} intrinsic={}×{}",
                        img.asset_id, w, h
                    );
                }
        }
    }
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
    let registry = provider.asset_registry();
    let mut builder = BlockJoinedPlainBuilder::new();

    for i in 0..provider.spine_count() {
        let html = provider.read_spine_html(i)?;
        let base = provider
            .spine_internal_path(i)
            .unwrap_or_default();
        append_spine_html_to_builder(&mut builder, &html, &registry, &base)?;
    }

    let mut ir = builder.finish();
    resolve_image_dimensions(&mut ir, &provider);
    ir.validate_plain(PlainProjectionStyle::BlockJoined)
        .map_err(|e| AppError::EpubParseError {
            reason: format!("IR plain validation failed: {e}"),
        })?;
    Ok(ir)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{ContentBlock, PlainProjectionStyle, IMAGE_PLAIN_PLACEHOLDER};
    use crate::parser::epub::asset_registry::EpubAssetRegistry;
    use std::collections::HashMap;
    use std::path::PathBuf;

    use epub::doc::ResourceItem;

    fn assert_ir_invariants(ir: &ChapterContentIr) {
        ir.validate_plain(PlainProjectionStyle::BlockJoined)
            .expect("EPUB IR must satisfy BlockJoined plain projection");
    }

    fn sample_registry() -> EpubAssetRegistry {
        let mut resources = HashMap::new();
        resources.insert(
            "spine_a".into(),
            ResourceItem {
                path: PathBuf::from("OEBPS/Text/part1.xhtml"),
                mime: "application/xhtml+xml".into(),
                properties: None,
            },
        );
        resources.insert(
            "spine_b".into(),
            ResourceItem {
                path: PathBuf::from("OEBPS/Text/part2.xhtml"),
                mime: "application/xhtml+xml".into(),
                properties: None,
            },
        );
        resources.insert(
            "img_spine_b".into(),
            ResourceItem {
                path: PathBuf::from("OEBPS/Images/from_b.jpg"),
                mime: "image/jpeg".into(),
                properties: None,
            },
        );
        EpubAssetRegistry::from_manifest(&resources)
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
    fn multi_spine_merge_resolves_image_per_spine_base() {
        let registry = sample_registry();
        let mut builder = BlockJoinedPlainBuilder::new();

        let mut ir1 = html_to_chapter_ir("<p>part one</p>").unwrap();
        canonicalize_chapter_image_assets(&mut ir1, &registry, "OEBPS/Text/part1.xhtml");
        append_chapter_ir_to_builder(&mut builder, ir1);

        let mut ir2 = html_to_chapter_ir("<img src=\"../Images/from_b.jpg\" alt=\"b\"/>").unwrap();
        canonicalize_chapter_image_assets(&mut ir2, &registry, "OEBPS/Text/part2.xhtml");
        append_chapter_ir_to_builder(&mut builder, ir2);

        let ir = builder.finish();
        assert_ir_invariants(&ir);
        assert_eq!(ir.block_count(), 2);
        let ContentBlock::Image(img) = &ir.blocks[1] else {
            panic!("expected image in second spine");
        };
        assert_eq!(img.asset_id, "img_spine_b");
    }

    #[test]
    fn html_inline_bold_spans_preserved() {
        use crate::domain::{RichTextSpan, SpanStyle};

        let ir = html_to_chapter_ir("<p>Hello <b>bold</b> world</p>").unwrap();
        assert_eq!(ir.block_count(), 1);
        let ContentBlock::Text(t) = &ir.blocks[0] else {
            panic!("expected Text block");
        };
        assert!(!t.spans.is_empty());
        assert_eq!(t.text, "Hello bold world");
        assert!(
            t.spans
                .iter()
                .any(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)))
        );
        assert_ir_invariants(&ir);
    }

    #[test]
    fn html_plain_paragraph_has_no_explicit_text_indent() {
        let ir = html_to_chapter_ir("<p>Plain</p>").unwrap();
        let ContentBlock::Text(t) = &ir.blocks[0] else {
            panic!("expected Text");
        };
        assert!(t.style.text_indent_em.is_none());
        assert_ir_invariants(&ir);
    }

    #[test]
    fn html_css_span_font_weight_in_spans() {
        use crate::domain::{RichTextSpan, SpanStyle};

        let ir = html_to_chapter_ir(r#"<p><span style="font-weight: bold">bold</span></p>"#).unwrap();
        let ContentBlock::Text(t) = &ir.blocks[0] else {
            panic!("expected Text");
        };
        assert!(
            t.spans
                .iter()
                .any(|s| matches!(s, RichTextSpan::Styled(SpanStyle::Bold, _)))
        );
        assert_ir_invariants(&ir);
    }

    #[test]
    fn html_text_indent_style_preserved() {
        let html = r#"<style>p { text-indent: 2em; margin-top: 0.5em; margin-bottom: 1em; }</style><p>Indented</p>"#;
        let ir = html_to_chapter_ir(html).unwrap();
        assert_eq!(ir.block_count(), 1);
        let ContentBlock::Text(t) = &ir.blocks[0] else {
            panic!("expected Text block");
        };
        assert_eq!(t.style.text_indent_em, Some(2.0));
        assert_eq!(t.style.margin_top_em, Some(0.5));
        assert_eq!(t.style.margin_bottom_em, Some(1.0));
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

    #[test]
    fn split_oversized_html_at_paragraph_boundaries() {
        let para = format!("<p>{}</p>", "word ".repeat(5000));
        let html = para.repeat(5);
        assert!(html.len() > MAX_HTML_CHUNK_BYTES);

        let chunks = split_html_at_block_boundaries(&html, MAX_HTML_CHUNK_BYTES);
        assert!(chunks.len() > 1, "expected multiple chunks, got {}", chunks.len());
        for chunk in &chunks {
            assert!(
                chunk.len() <= MAX_HTML_CHUNK_BYTES,
                "chunk {} bytes exceeds limit",
                chunk.len()
            );
        }

        let mut builder = BlockJoinedPlainBuilder::new();
        for chunk in chunks {
            let ir = html_to_chapter_ir(&chunk).expect("chunk should parse");
            append_chapter_ir_to_builder(&mut builder, ir);
        }
        let ir = builder.finish();
        assert!(ir.block_count() >= 5);
        assert_ir_invariants(&ir);
    }

    #[test]
    fn multi_spine_cumulative_html_not_truncated() {
        let registry = sample_registry();
        let spine_html = format!("<p>{}</p>", "line ".repeat(8000));
        assert!(spine_html.len() < MAX_HTML_CHUNK_BYTES);

        let mut builder = BlockJoinedPlainBuilder::new();
        append_spine_html_to_builder(&mut builder, &spine_html, &registry, "part1.xhtml")
            .expect("first spine");
        append_spine_html_to_builder(&mut builder, &spine_html, &registry, "part2.xhtml")
            .expect("second spine");

        let ir = builder.finish();
        assert_eq!(ir.block_count(), 2);
        assert!(
            ir.plain_text.chars().count() > MAX_HTML_CHUNK_BYTES / 4,
            "cumulative plain should not be truncated early"
        );
        assert_ir_invariants(&ir);
    }

    #[test]
    fn oversized_spine_with_image_parsed_via_chunks() {
        let registry = sample_registry();
        let text = format!("<p>{}</p>", "x ".repeat(60000));
        let html = format!(
            "{text}<img src=\"../Images/from_b.jpg\" alt=\"pic\"/>{text}",
        );
        assert!(html.len() > MAX_HTML_CHUNK_BYTES);

        let mut builder = BlockJoinedPlainBuilder::new();
        append_spine_html_to_builder(
            &mut builder,
            &html,
            &registry,
            "OEBPS/Text/part2.xhtml",
        )
        .expect("chunked image spine");

        let ir = builder.finish();
        assert!(ir.image_block_count() >= 1, "image block should survive chunked parse");
        assert_ir_invariants(&ir);
    }
}
