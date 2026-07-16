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
//   - read_image_dimensions() / resolve_image_dimensions() — 图片 intrinsic 尺寸
// ============================================================

use super::asset_registry::{canonicalize_chapter_image_assets, normalize_asset_id};
use crate::common::AppError;
use crate::pipeline::{
    append_chapter_ir_to_builder, BlockJoinedPlainBuilder, PlainProjectionStyle,
    ReaderChapterIr, ReaderInlineRun, ReaderIrBlockKind,
};
use crate::parser::epub::rich_text;

use super::provider::EpubContentProvider;

/// EPUB 解析中间产物：富文本段落
///
/// 表示 HTML 中一个 `<p>` 或 `<div>` 块级元素的解析结果。
/// 含内联 span、CSS 样式和图片占位信息。
/// 最终被折叠为 `ReaderIrBlock`。
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize, Default)]
pub struct RichParagraph {
    pub spans: Vec<ReaderInlineRun>,
    pub indent: u8,
    pub is_heading: bool,
    pub heading_level: u8,
    pub class_name: Option<String>,
    pub text_align: Option<String>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub text_indent_em: Option<f32>,
    pub font_size: Option<f32>,
    pub is_image: bool,
    pub image_src: Option<String>,
    pub image_data: Vec<u8>,
    pub image_alt: Option<String>,
}

impl RichParagraph {
    /// 连接所有 span 的文本内容
    pub fn full_text(&self) -> String {
        self.spans.iter().map(|s| s.text.as_str()).collect()
    }

    /// 构造图片占位段落
    pub fn image_placeholder(src: String, alt: String) -> Self {
        Self {
            spans: Vec::new(),
            indent: 0,
            is_heading: false,
            heading_level: 0,
            class_name: None,
            text_align: None,
            margin_top_em: None,
            margin_bottom_em: None,
            text_indent_em: None,
            font_size: None,
            is_image: true,
            image_src: Some(src),
            image_data: Vec::new(),
            image_alt: Some(alt),
        }
    }
}

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
            builder.push_text(
                text.to_string(),
                false, 0, None, None, None, None, None,
            );
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

/// 将富文本段落流转为章 IR + plain 投影。
pub fn chapter_ir_from_rich_paragraphs(paragraphs: &[RichParagraph]) -> ReaderChapterIr {
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
            builder.push_image(src, alt, None, None);
            continue;
        }

        let text = p.full_text();
        if text.trim().is_empty() {
            continue;
        }
        builder.push_text_spans(
            text,
            p.spans.clone(),
            p.is_heading,
            p.heading_level,
            // text_indent_em: EPUB/CSS 显式值；None → Flutter 侧用用户首行缩进设置。
            if p.is_heading { Some(0.0) } else { p.text_indent_em },
            p.margin_top_em,
            p.margin_bottom_em,
            p.text_align.clone(),
            p.font_size,
        );
    }

    builder.finish()
}

/// HTML 片段 → 章 IR（单元测试 / 无 EPUB 文件场景）。
pub fn html_to_chapter_ir(html: &str) -> Result<ReaderChapterIr, AppError> {
    match rich_text::parse_html_to_rich_text(html) {
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

/// 从 PNG/JPEG 头部读取 intrinsic 尺寸（轻量，无完整解码）。
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

/// 遍历章 IR 中所有 Image block，从 EPUB 读取原始字节并解析 intrinsic 尺寸。
fn resolve_image_dimensions(ir: &mut ReaderChapterIr, provider: &EpubContentProvider) {
    for block in &mut ir.blocks {
        if block.kind != ReaderIrBlockKind::Image {
            continue;
        }
        if block.image_intrinsic_width.is_some() && block.image_intrinsic_height.is_some() {
            continue;
        }
        if let Some(ref asset_id) = block.image_asset_id
            && let Some(data) = provider.read_resource_bytes(asset_id)
                && let Some((w, h)) = read_image_dimensions(&data)
            {
                block.image_intrinsic_width = Some(w);
                block.image_intrinsic_height = Some(h);
                tracing::debug!(
                    "[get_chapter_content_ir] image {} intrinsic={}×{}",
                    asset_id, w, h
                );
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
