// ============================================================
// 文件作用：EPUB HTML → 章节 IR，复用 parse_html_to_rich_text
//           保持 DOM 顺序与 scroll 路径一致。
//
// 公有类型/函数：
//   - get_chapter_content_ir() — 获取 EPUB 章节 IR
//   - html_to_chapter_ir() — HTML 片段 → 章 IR
//   - chapter_ir_from_rich_paragraphs() — 富文本段落流转为章 IR
//
// 私有函数：
//   - split_html_at_block_boundaries() — 在块级标签边界拆分 oversized HTML
//   - append_spine_html_to_builder() / append_plain_html_to_builder() — IR 构建
// ============================================================

use super::asset_registry::{canonicalize_chapter_image_assets, normalize_asset_id};
use super::image_size::resolve_image_dimensions;
use super::provider::EpubContentProvider;
use super::rich_paragraph::RichParagraph;
use crate::common::AppError;
use crate::parser::epub::rich_parser;
use crate::pipeline::{
    BlockJoinedPlainBuilder, BlockStyle, PlainProjectionStyle, ReaderChapterIr,
    append_chapter_ir_to_builder,
};

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
        let split_end =
            find_last_block_boundary(tail, window_end, &BOUNDARY_TAGS).unwrap_or(window_end);

        let end = if split_end == 0 {
            window_end
        } else {
            split_end
        };
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
    use super::plain_text::html_to_plain_text;

    let plain = html_to_plain_text(html);
    for line in plain.split('\n') {
        let text = line.trim();
        if !text.is_empty() {
            builder.push_text(text.to_string(), BlockStyle::empty());
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
                        target: "reader_ir_fallback",
                        stage = "parse",
                        fallback = "plain",
                        fallback_succeeded = true,
                        chunk_bytes = piece.len(),
                        error = %e,
                        "EPUB IR chunk parse failed; using plain projection",
                    );
                    append_plain_html_to_builder(builder, &piece);
                }
            }
        } else {
            tracing::warn!(
                target: "reader_ir_fallback",
                stage = "split",
                fallback = "plain",
                fallback_succeeded = true,
                chunk_bytes = piece.len(),
                "EPUB IR chunk remains oversized; using plain projection",
            );
            append_plain_html_to_builder(builder, &piece);
        }
    }
    Ok(())
}

/// 将富文本段落流转为章 IR + plain 投影。
pub fn chapter_ir_from_rich_paragraphs(paragraphs: &[RichParagraph]) -> ReaderChapterIr {
    let mut builder = BlockJoinedPlainBuilder::new();

    for p in paragraphs {
        if p.is_image {
            let Some(src) = p
                .image_src
                .as_deref()
                .map(normalize_asset_id)
                .filter(|src| !src.is_empty())
            else {
                tracing::warn!(target: "epub.malformed", "image without src skipped");
                continue;
            };
            let alt = p
                .image_alt
                .as_ref()
                .map(|s| s.trim())
                .filter(|s| !s.is_empty())
                .map(str::to_string);
            builder.push_image(src, alt, None, None);
            continue;
        }

        let text = p.full_text();
        if text.trim().is_empty() {
            continue;
        }
        let block_style = BlockStyle {
            is_heading: p.is_heading,
            heading_level: p.heading_level,
            // text_indent_em: EPUB/CSS 显式值；None → Flutter 侧用用户首行缩进设置。
            text_indent_em: if p.is_heading {
                Some(0.0)
            } else {
                p.text_indent_em
            },
            margin_top_em: p.margin_top_em,
            margin_bottom_em: p.margin_bottom_em,
            text_align: p.text_align.clone(),
            font_size: p.font_size,
        };
        builder.push_text_spans(text, p.spans.clone(), block_style);
    }

    builder.finish()
}

/// HTML 片段 → 章 IR（单元测试 / 无 EPUB 文件场景）。
pub fn html_to_chapter_ir(html: &str) -> Result<ReaderChapterIr, AppError> {
    match rich_parser::parse_html_to_rich_text(html) {
        Ok(paragraphs) => Ok(chapter_ir_from_rich_paragraphs(&paragraphs)),
        Err(e) => {
            let preview = html
                .chars()
                .take(120)
                .collect::<String>()
                .replace('\n', " ");
            tracing::warn!(
                target: "epub.malformed",
                "[html_to_chapter_ir] parse failed: {e} (input {} bytes, preview: {preview:?})",
                html.len(),
            );
            Err(e)
        }
    }
}

/// 获取 EPUB 章节 IR（spine 范围与 `get_chapter_content_rich` 一致）。
pub fn get_chapter_content_ir(
    file_path: &str,
    start_index: i32,
    end_index: i32,
) -> Result<ReaderChapterIr, AppError> {
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
        let base = provider.spine_internal_path(i).unwrap_or_default();
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
