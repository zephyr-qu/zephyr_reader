// ============================================================
// 文件作用：EPUB 按需内容提供器 — EpubContentProvider 基于 EpubFile 实现
//           spine item 粒度的懒加载。
//
// 公有类型/函数：
//   - EpubContentProvider — EPUB 按需内容提供器
//     - open_from_bounds() — 使用 DB 中的 spine 边界打开章节
//     - read_text_range() / read_html_range() — 读取文本/HTML 范围
//     - content_length() / format() — 内容长度和格式
//     - read_resource_bytes() — 读取资源原始字节
//     - read_spine_html() — 读取单个 spine 原始 HTML
//     - spine_count() / spine_internal_path() / primary_spine_href()
//     - asset_registry() — 构建 manifest asset 注册表
//
// 私有函数：
//   - ensure_spine_text() — 确保 spine 纯文本已缓存
//   - build_offsets_up_to() — 惰性构建偏移数组
//   - html_to_plain_text() — HTML 片段转纯文本（2-pass 策略）
//   - decode_entity() — 解码单个 HTML 实体
//   - clean_whitespace() — 清理空白字符
// ============================================================

//! EPUB 按需内容提供器
//!
//! `EpubContentProvider` 基于 `EpubFile` 实现 spine item 粒度的懒加载。
//! 每个 spine 的纯文本在其内容首次被请求时才加载和缓存，
//! 避免首次访问时加载整章所有 spine item 的内存浪费。

use std::sync::OnceLock as OnceLock;

use parking_lot::Mutex;

use super::asset_registry::EpubAssetRegistry;
use super::unzip::EpubFile;
use crate::domain::AppError;
use crate::parser::provider::ChapterContentProvider;
use crate::domain::book::BookFormat;

/// EPUB 按需内容提供器
///
/// 每个实例对应一书的一个章节（TOC entry）。
/// spine_hrefs 记录该章节覆盖的所有 spine item 的 href，
/// 首次读取时按需加载对应的 spine 并缓存。
pub struct EpubContentProvider {
    epub: Mutex<EpubFile>,
    spine_hrefs: Vec<String>,
    /// 每个 spine item 的纯文本（含尾部 \n 分隔符，最后一个除外）
    spine_texts: Vec<OnceLock<String>>,
    /// 每个 spine item 的原始 HTML（含尾部 \n 分隔符，最后一个除外）
    spine_htmls: Vec<OnceLock<String>>,
    /// 累积偏移量，惰性构建：转换为 spin 时追加实际长度，
    /// 未转换的 spin 在 `build_offsets_up_to` 中按需转换。
    offsets: Mutex<Vec<u64>>,
}

impl EpubContentProvider {
    /// 使用 DB 中的 spine 边界打开 EPUB 章节。
    ///
    /// 调用方在打开前通过 `get_chapter_bounds` 从 DB 读取边界；
    /// 导入阶段已按 `MAX_SPINE_ITEMS_PER_CHAPTER` 拆章，阅读侧不再截断。
    pub fn open_from_bounds(
        file_path: &str,
        start_index: i32,
        end_index: i32,
    ) -> Result<Self, AppError> {
        let mut epub = EpubFile::open(file_path)?;
        let spine = epub.spine();
        let start = start_index.max(0) as usize;
        let end = (end_index.max(0) as usize)
            .min(spine.len())
            .max(start + 1);

        let spine_hrefs: Vec<String> = spine[start..end].to_vec();
        let count = spine_hrefs.len();

        // Detect oversized single-spine chapters (>2MB HTML)
        if count == 1
            && let Ok(html) = epub.read_resource(&spine_hrefs[0])
                && html.len() > 2_000_000 {
                    return Err(AppError::ChapterTooLarge {
                        size_bytes: html.len(),
                        details: format!("spine {} is {} bytes", &spine_hrefs[0], html.len()),
                    });
                }

        Ok(Self {
            epub: Mutex::new(epub),
            spine_hrefs,
            spine_texts: (0..count).map(|_| OnceLock::new()).collect(),
            spine_htmls: (0..count).map(|_| OnceLock::new()).collect(),
            offsets: Mutex::new(vec![0u64]),
        })
    }
    /// 确保指定 spine index 的纯文本已缓存，返回其引用。
    /// 在 spine 文本后追加 `\n` 分隔符（最后一个 spine 除外），
    /// 以保持与旧版 `parts.join("\n")` 相同的行为。
    /// **不**负责偏移跟踪，调用方 `build_offsets_up_to` 处理。
    fn ensure_spine_text(&self, index: usize) -> Result<&str, AppError> {
        if let Some(text) = self.spine_texts[index].get() {
            return Ok(text.as_str());
        }

        let mut epub = self.epub.lock();
        let href = &self.spine_hrefs[index];
        let html = epub.read_resource(href).map_err(|e| {
            AppError::ChapterExtractError { index: -1, reason: format!("failed to read spine item {}: {}", href, e) }
        })?;
        // 缓存原始 HTML，供 read_html_range 使用
        let _ = self.spine_htmls[index].get_or_init(|| html.clone());
        let plain = html_to_plain_text(&html);

        // 除最后一个 spine 外，追加 \n 分隔符以兼容 parts.join("\n") 行为
        let text = if index + 1 < self.spine_texts.len() {
            format!("{}\n", plain)
        } else {
            plain
        };

        Ok(self.spine_texts[index].get_or_init(|| text).as_str())
    }

    /// 惰性构建偏移数组，直到累积长度 ≥ `target_char`。
    ///
    /// 只转换必要的 spine：按顺序转换为 spine 并记录其实际长度。
    /// 未触及目标范围以外的 spine。已转换过的不重复转换。
    fn build_offsets_up_to(&self, target_char: u64) -> Result<Vec<u64>, AppError> {
        let cache = self.offsets.lock();
        // 检查是否已经达到目标
        if *cache.last().unwrap_or(&0) >= target_char && cache.len() > 1 {
            return Ok(cache.clone());
        }
        drop(cache);

        loop {
            let offsets = self.offsets.lock();
            let n_converted = offsets.len() - 1; // 已记录偏移的 spine 数量

            if n_converted >= self.spine_texts.len() {
                break; // 所有 spine 转换完成
            }
            if *offsets.last().unwrap_or(&0) >= target_char {
                break; // 已达到目标累积长度
            }

            // 转换下一个 spine
            drop(offsets);
            let text = self.ensure_spine_text(n_converted)?;

            // 记录偏移（确保未被其他路径提前记录）
            let mut offsets = self.offsets.lock();
            if offsets.len() == n_converted + 1 {
                let last = *offsets.last().unwrap_or(&0);
                offsets.push(last + text.len() as u64);
            }
        }
        Ok(self.offsets.lock().clone())
    }
    /// 读取 EPUB 资源文件的原始字节（用于图片加载）
    pub fn read_resource_bytes(&self, href: &str) -> Option<Vec<u8>> {
        self.epub.lock().read_resource_bytes(href)
    }

    /// 本章第一个 spine manifest idref（OPF `idref`，非包内路径）。
    pub fn primary_spine_href(&self) -> &str {
        self.spine_hrefs.first().map(String::as_str).unwrap_or("")
    }

    pub fn spine_count(&self) -> usize {
        self.spine_hrefs.len()
    }

    /// 读取单个 spine 的原始 HTML（不含 spine 间拼接 `\n`）。
    pub fn read_spine_html(&self, index: usize) -> Result<String, AppError> {
        if index >= self.spine_hrefs.len() {
            return Err(AppError::ChapterExtractError {
                index: index as i32,
                reason: format!("spine index {index} out of range"),
            });
        }
        self.ensure_spine_text(index)?;
        self.spine_htmls[index]
            .get()
            .cloned()
            .ok_or_else(|| AppError::EpubParseError {
                reason: format!("spine HTML not cached at index {index}"),
            })
    }

    /// spine manifest idref → OPF 包内路径（相对路径解析基准）。
    pub fn spine_internal_path(&self, index: usize) -> Option<String> {
        let idref = self.spine_hrefs.get(index)?;
        let epub = self.epub.lock();
        epub.resources().get(idref).map(|item| {
            item.path.to_string_lossy().replace('\\', "/")
        })
    }

    /// 构建本书 manifest asset 注册表。
    pub fn asset_registry(&self) -> EpubAssetRegistry {
        EpubAssetRegistry::from_epub(&self.epub.lock())
    }
}
impl ChapterContentProvider for EpubContentProvider {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError> {
        // 先确保偏移覆盖到 end，只转换必要的 spine
        let offsets = self.build_offsets_up_to(end)?;
        let total = *offsets.last().unwrap_or(&0);
        let start = start.min(total);
        let end = end.min(total);

        if start >= end {
            return Ok(String::new());
        }

        // 二分查找与 [start, end) 重叠的 spine 索引范围
        let first_spine = offsets
            .partition_point(|&off| off <= start)
            .saturating_sub(1);
        let last_spine = offsets.partition_point(|&off| off < end);

        let mut result = String::with_capacity((end - start) as usize);
        for (relative_idx, &spine_start) in offsets[first_spine..last_spine].iter().enumerate() {
            let i = first_spine + relative_idx;
            let spine_text = self.ensure_spine_text(i)?;
            let raw_local_start = (start.saturating_sub(spine_start)) as usize;
            let raw_local_end = (end.saturating_sub(spine_start) as usize)
                .min(spine_text.len());
            let local_start = spine_text.ceil_char_boundary(raw_local_start);
            let local_end = spine_text.floor_char_boundary(raw_local_end);
            if local_start < local_end {
                result.push_str(&spine_text[local_start..local_end]);
            }
        }
        Ok(result)
    }

    fn content_length(&self) -> u64 {
        // 使用惰性构建，最多转换 spines 至累积长度 cover u64::MAX
        // 由于 build_offsets_up_to 在 while 循环中检查边界，
        // 调用 u64::MAX 会转换所有 spine（同旧版行为，但惰性逐步进行）
        self.build_offsets_up_to(u64::MAX)
            .map(|offsets| *offsets.last().unwrap_or(&0))
            .unwrap_or(0)
    }

    fn format(&self) -> BookFormat {
        BookFormat::Epub
    }

    fn read_html_range(&self, _start: u64, _end: u64) -> Option<Result<String, AppError>> {
        Some((|| {
            let mut html = String::new();
            for i in 0..self.spine_htmls.len() {
                self.ensure_spine_text(i)?;
                let content = self.spine_htmls[i].get()
                    .ok_or_else(|| AppError::EpubParseError { reason: "spine HTML not cached".into() })?;
                html.push_str(content);
                html.push('\n');
            }
            // Trim trailing newline to match read_chapter_content join("\n") behavior
            if html.ends_with('\n') {
                html.pop();
            }
            Ok(html)
        })())
    }
}

/// 将 HTML 片段转换为纯文本（2-pass 策略）
///
/// Pass 1: byte-level 单次扫描，剥离标签、解码实体、压缩空格
/// Pass 2: clean_whitespace 清理多余换行和前后空白
pub(crate) fn html_to_plain_text(html: &str) -> String {
    /// Case-insensitive prefix comparison on byte slices
    fn bytes_starts_with_lower(haystack: &[u8], needle: &[u8]) -> bool {
        if haystack.len() < needle.len() {
            return false;
        }
        haystack[..needle.len()]
            .iter()
            .zip(needle)
            .all(|(h, n)| h.to_ascii_lowercase() == *n)
    }

    /// Check if at byte position `pos` (right after '<') the tag name matches,
    /// followed by '>', space, or '/'
    fn is_tag_at(bytes: &[u8], pos: usize, tag_name: &[u8]) -> bool {
        let rest = &bytes[pos..];
        rest.len() > tag_name.len()
            && bytes_starts_with_lower(rest, tag_name)
            && matches!(rest[tag_name.len()], b'>' | b' ' | b'/')
    }

    let bytes = html.as_bytes();
    let mut out = String::with_capacity(html.len());
    let mut pos = 0;

    enum SkipMode { None, Script, Style }
    let mut skip = SkipMode::None;
    let mut last_was_newline = true;

    while pos < bytes.len() {
        // ── Handle skip mode (inside <script> or <style>) ──
        match skip {
            SkipMode::Script | SkipMode::Style => {
                let close_tag: &[u8] = match skip {
                    SkipMode::Script => b"</script>",
                    SkipMode::Style => b"</style>",
                    _ => unreachable!(),
                };
                let mut found = false;
                let mut scan = pos;
                while scan < bytes.len() {
                    if bytes[scan] == b'<' && bytes_starts_with_lower(&bytes[scan..], close_tag) {
                        pos = scan + close_tag.len();
                        skip = SkipMode::None;
                        found = true;
                        break;
                    }
                    scan += 1;
                }
                if !found {
                    pos = bytes.len();
                }
                continue;
            }
            SkipMode::None => {}
        }

        let c = html[pos..].chars().next().unwrap();
        let c_len = c.len_utf8();

        // ── <tag> handling ──
        if c == '<' {
            let rest = &bytes[pos..];

            // HTML comment <!-- ... -->
            if rest.len() >= 4 && rest[1] == b'!' && rest[2] == b'-' && rest[3] == b'-' {
                if let Some(end) = rest.windows(3).position(|w| w == b"-->") {
                    pos += end + 3;
                } else {
                    pos = bytes.len();
                }
                continue;
            }

            // <script> opening
            if is_tag_at(bytes, pos + 1, b"script") {
                skip = SkipMode::Script;
                if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                    pos += gt + 1;
                } else {
                    pos += 1;
                }
                continue;
            }

            // <style> opening
            if is_tag_at(bytes, pos + 1, b"style") {
                skip = SkipMode::Style;
                if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                    pos += gt + 1;
                } else {
                    pos += 1;
                }
                continue;
            }

            // <br> → newline
            if is_tag_at(bytes, pos + 1, b"br") {
                out.push('\n');
                last_was_newline = true;
                if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                    pos += gt + 1;
                } else {
                    pos += 1;
                }
                continue;
            }

            // Block-level tags → newline
            const BLOCK_TAGS: &[&[u8]] = &[
                b"p", b"div", b"h1", b"h2", b"h3", b"h4", b"h5", b"h6",
                b"li", b"tr", b"th", b"td", b"blockquote", b"dd", b"dt",
                b"figcaption", b"figure",
            ];
            let mut is_block = false;
            for &tag in BLOCK_TAGS {
                if is_tag_at(bytes, pos + 1, tag) {
                    is_block = true;
                    break;
                }
            }
            if is_block {
                out.push('\n');
                last_was_newline = true;
                if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                    pos += gt + 1;
                } else {
                    pos += 1;
                }
                continue;
            }

            // </tag> — emit newline only for block-level close tags
            if rest.len() >= 2 && rest[1] == b'/' {
                let mut is_block_close = false;
                for &tag in BLOCK_TAGS {
                    if is_tag_at(bytes, pos + 2, tag) {
                        is_block_close = true;
                        break;
                    }
                }
                if is_block_close {
                    out.push('\n');
                    last_was_newline = true;
                }
                if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                    pos += gt + 1;
                } else {
                    pos += 1;
                }
                continue;
            }
            if let Some(gt) = rest.iter().position(|&b| b == b'>') {
                pos += gt + 1;
            } else {
                out.push(c);
                pos += c_len;
            }
            continue;
        }

        // ── Entity decoding —─
        if c == '&' {
            let rest = &bytes[pos..];
            let max_scan = rest.len().min(21);
            let semi_pos = rest[..max_scan].iter().position(|&b| b == b';');
            if let Some(semi) = semi_pos {
                let body = &rest[1..semi];
                if !body.is_empty()
                    && body.iter().all(|&b| {
                        b.is_ascii_alphanumeric() || b == b'#' || b == b'x' || b == b'X'
                    })
                {
                    let entity = std::str::from_utf8(&rest[..=semi]).unwrap_or("");
                    let decoded = decode_entity(entity);
                    out.push_str(&decoded);
                    pos += semi + 1;
                    last_was_newline = false;
                    continue;
                }
            }
            // Malformed entity → output '&' as-is
            out.push('&');
            pos += 1;
            last_was_newline = false;
            continue;
        }

        // ── Whitespace compression ──
        if c.is_whitespace() && !c.is_control() {
            if !last_was_newline {
                out.push(' ');
                last_was_newline = false;
            }
            pos += c_len;
            while pos < bytes.len() {
                let next = html[pos..].chars().next().unwrap();
                if !next.is_whitespace() || next.is_control() {
                    break;
                }
                pos += next.len_utf8();
            }
            continue;
        }

        // ── Regular character ──
        out.push(c);
        pos += c_len;
        last_was_newline = false;
    }

    clean_whitespace(&out)
}

/// 解码单个 HTML 实体
fn decode_entity(entity: &str) -> String {
    match entity {
        "&amp;" => "&".to_string(),
        "&lt;" => "<".to_string(),
        "&gt;" => ">".to_string(),
        "&quot;" => "\"".to_string(),
        "&apos;" => "'".to_string(),
        "&nbsp;" => " ".to_string(),
        _ => {
            // 数字实体
            if let Some(hex) = entity.strip_prefix("&#x").and_then(|s| s.strip_suffix(';'))
                && let Ok(code) = u32::from_str_radix(hex, 16)
                    && let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
            if let Some(dec) = entity.strip_prefix("&#").and_then(|s| s.strip_suffix(';'))
                && let Ok(code) = dec.parse::<u32>()
                    && let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
            entity.to_string()
        }
    }
}

/// 清理空白字符，保留 \n\n 作为段落间隔
fn clean_whitespace(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_newline = false;

    for c in text.chars() {
        if c == '\n' {
            if prev_newline {
                // 保留空行（段落间）
                result.push('\n');
                result.push('\n');
                prev_newline = false;
            } else {
                prev_newline = true;
            }
        } else if c.is_whitespace() {
            if !prev_newline {
                result.push(' ');
            }
        } else {
            if prev_newline {
                result.push('\n');
                prev_newline = false;
            }
            result.push(c);
        }
    }

    // 清理首尾空白
    let trimmed = result.trim().to_string();
    // 压缩多余的空行（最多保留一个连续空行）
    let mut cleaned = String::with_capacity(trimmed.len());
    let mut consecutive_newlines = 0;

    for c in trimmed.chars() {
        if c == '\n' {
            consecutive_newlines += 1;
            if consecutive_newlines <= 2 {
                cleaned.push(c);
            }
        } else {
            consecutive_newlines = 0;
            cleaned.push(c);
        }
    }

    cleaned
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_html_to_plain_text_simple() {
        let html = "<p>Hello World</p>";
        let text = html_to_plain_text(html);
        assert_eq!(text, "Hello World");
    }

    #[test]
    fn test_html_to_plain_text_with_newlines() {
        let html = "<p>First paragraph</p><p>Second paragraph</p>";
        let text = html_to_plain_text(html);
        assert_eq!(text, "First paragraph\n\nSecond paragraph");
    }

    #[test]
    fn test_html_to_plain_text_strip_scripts() {
        let html = "<p>Hello</p><script>alert('xss');</script><p>World</p>";
        let text = html_to_plain_text(html);
        assert_eq!(text, "Hello\n\nWorld");
    }

    #[test]
    fn test_html_to_plain_text_entities() {
        let html = "<p>Tom &amp; Jerry</p>";
        let text = html_to_plain_text(html);
        assert_eq!(text, "Tom & Jerry");
    }

    #[test]
    fn test_html_to_plain_text_br() {
        let html = "Line1<br>Line2<br/>Line3";
        let text = html_to_plain_text(html);
        assert!(text.contains("Line1"));
        assert!(text.contains("Line2"));
        assert!(text.contains("Line3"));
    }


    #[test]
    fn test_html_to_plain_text_nested_inline_tags() {
        let text = html_to_plain_text("<p><b>Bold</b> <i>italic</i></p>");
        assert_eq!(text, "Bold italic");
    }

    #[test]
    fn test_html_to_plain_text_style_block() {
        let text = html_to_plain_text("<p>Hi</p><style>body { color: red; }</style><p>Bye</p>");
        assert_eq!(text, "Hi\n\nBye");
    }

    #[test]
    fn test_html_to_plain_text_unclosed_entity() {
        let text = html_to_plain_text("<p>A &amp B</p>");
        assert_eq!(text, "A &amp B");
    }

    #[test]
    fn test_html_to_plain_text_numeric_entity() {
        let text = html_to_plain_text("<p>&#x4F60;&#22909;</p>");
        assert_eq!(text, "你好");
    }

    #[test]
    fn test_html_to_plain_text_mixed_br_and_p() {
        let text = html_to_plain_text("Line1<br>Line2<p>Line3</p>");
        assert_eq!(text, "Line1\nLine2\nLine3");
    }

    #[test]
    fn test_html_to_plain_text_inline_only() {
        let text = html_to_plain_text("<b>Bold</b> and <i>italic</i>");
        assert_eq!(text, "Bold and italic");
    }

    #[test]
    fn test_html_to_plain_text_block_nesting() {
        let text = html_to_plain_text("<div><p>Nested</p><p>Paragraphs</p></div>");
        assert_eq!(text, "Nested\n\nParagraphs");
    }

    #[test]
    fn test_html_to_plain_text_mixed_block_inline() {
        let text = html_to_plain_text("<p>Hello <b>world</b></p><p>Second <i>para</i></p>");
        assert_eq!(text, "Hello world\n\nSecond para");
    }

    #[test]
    fn test_oversized_single_spine_returns_too_large() {
        use std::io::{Read, Write};
        use std::path::PathBuf;
        use zip::write::SimpleFileOptions;
        use zip::CompressionMethod;
        use zip::ZipWriter;

        // Start from the real medium.epub fixture, extract all entries,
        // then replace a spine XHTML with >2MB content
        let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let src_path = manifest_dir.join("../test/fixtures/medium.epub");

        // Read the real EPUB
        let src_bytes = std::fs::read(&src_path).unwrap();
        let src_zip = std::io::Cursor::new(src_bytes);
        let mut src_archive = zip::ZipArchive::new(src_zip).unwrap();

        let dir = tempfile::TempDir::new().unwrap();
        let out_path = dir.path().join("large.epub");
        let out_file = std::fs::File::create(&out_path).unwrap();
        let mut out_zip = ZipWriter::new(out_file);

        // Get all entry names, keep mimetype first
        let mut names: Vec<String> = (0..src_archive.len())
            .map(|i| src_archive.by_index(i).unwrap().name().to_string())
            .collect();
        // Sort so mimetype is first
        names.sort_by(|a, b| {
            if a == "mimetype" { std::cmp::Ordering::Less }
            else if b == "mimetype" { std::cmp::Ordering::Greater }
            else { a.cmp(b) }
        });

        for name in &names {
            let mut entry = src_archive.by_name(name).unwrap();
            let opts = if name == "mimetype" {
                SimpleFileOptions::default().compression_method(CompressionMethod::Stored)
            } else {
                SimpleFileOptions::default()
            };
            out_zip.start_file(name, opts).unwrap();
            let mut data = Vec::new();
            entry.read_to_end(&mut data).unwrap();

            // Replace the first XHTML entry (spine) with >2MB content
            if name.ends_with(".xhtml") && !name.contains("nav") {
                let mut large_html = Vec::new();
                write!(&mut large_html, r#"<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Large</title></head>
<body><p>"#).unwrap();
                let content = "A".repeat(2_100_000);
                write!(&mut large_html, "{}</p></body></html>", content).unwrap();
                out_zip.write_all(&large_html).unwrap();
            } else {
                out_zip.write_all(&data).unwrap();
            }
        }
        out_zip.finish().unwrap();

        let path = out_path.to_string_lossy().to_string();
        let result = EpubContentProvider::open_from_bounds(&path, 0, 1);
        assert!(result.as_ref().is_err_and(|e| matches!(e, AppError::ChapterTooLarge { .. })),
            "expected ChapterTooLarge, got {:?}", result.as_ref().err());
    }
}

