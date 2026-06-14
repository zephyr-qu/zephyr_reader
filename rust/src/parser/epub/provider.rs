//! EPUB 按需内容提供器
//!
//! `EpubContentProvider` 基于 `EpubFile` 实现 spine item 粒度的懒加载。
//! 每个 spine 的纯文本在其内容首次被请求时才加载和缓存，
//! 避免首次访问时加载整章所有 spine item 的内存浪费。

use once_cell::sync::OnceCell as OnceLock;

use parking_lot::Mutex;

use super::toc::extract_chapters_from_epub;
use super::unzip::EpubFile;
use crate::domain::AppError;
use crate::parser::provider::ChapterContentProvider;
use crate::storage::models::BookFormat;

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
    /// 累积偏移量，惰性构建：转换为 spin 时追加实际长度，
    /// 未转换的 spin 在 `build_offsets_up_to` 中按需转换。
    offsets: Mutex<Vec<u64>>,
}

impl EpubContentProvider {
    /// Maximum spine items to load per chapter.
    ///
    /// Safety net for already-imported books whose chapter spans
    /// the entire spine. New imports are split at import time in
    /// `extract_toc_items`, but existing books still have the
    /// oversized chapter. This cap bounds per-chapter spine items
    /// so no single chapter takes more than ~1-2s to load.
    const MAX_SPINE_ITEMS: usize = 20;

    /// 打开 EPUB 文件并绑定到指定章节
    ///
    /// # 参数
    /// * `file_path` - EPUB 文件路径
    /// * `chapter_index` - TOC 章节索引（从 0 开始）
    pub fn open(file_path: &str, chapter_index: i32) -> Result<Self, AppError> {
        let mut epub = EpubFile::open(file_path)?;
        let chapters = extract_chapters_from_epub(&mut epub, "");

        let chapter = chapters
            .iter()
            .find(|c| c.chapter_index == chapter_index as i64)
            .ok_or_else(|| {
                AppError::ChapterExtractError { index: chapter_index, reason: format!("chapter {} not found", chapter_index).into() }
            })?;

        let spine = epub.spine();
        let start = chapter.start_index as usize;
        let end = (chapter.end_index as usize)
            .min(spine.len())
            .max(start + 1);

        // ── Safety cap ──────────────────────────────────────
        // Bound the number of spine items loaded at once to
        // prevent multi-second freeze on oversized chapters.
        let end = end.min(start + Self::MAX_SPINE_ITEMS);

        let spine_hrefs: Vec<String> = spine[start..end].to_vec();
        let count = spine_hrefs.len();

        Ok(Self {
            epub: Mutex::new(epub),
            spine_hrefs,
            spine_texts: (0..count).map(|_| OnceLock::new()).collect(),
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
            AppError::ChapterExtractError { index: -1, reason: format!("failed to read spine item {}: {}", href, e).into() }
        })?;
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

    fn supports_chunked_pagination(&self) -> bool {
        true
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

            // </tag> (closing tag except </a>) → newline
            if rest.len() >= 2 && rest[1] == b'/' {
                let is_close_a = rest.len() > 3
                    && bytes_starts_with_lower(&rest[2..], b"a")
                    && matches!(rest.get(3), Some(b'>') | Some(b' ') | Some(b'/'));
                if !is_close_a {
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

            // Other (inline) tags → skip silently
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
            if let Some(hex) = entity.strip_prefix("&#x").and_then(|s| s.strip_suffix(';')) {
                if let Ok(code) = u32::from_str_radix(hex, 16) {
                    if let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
                }
            }
            if let Some(dec) = entity.strip_prefix("&#").and_then(|s| s.strip_suffix(';')) {
                if let Ok(code) = dec.parse::<u32>() {
                    if let Some(ch) = char::from_u32(code) {
                        return ch.to_string();
                    }
                }
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
#[allow(dead_code)]
/// 解码数字 HTML 实体（&#xHH; 和 &#D;）
fn decode_numeric_entities(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '&' && chars.peek() == Some(&'#') {
            let mut entity = String::from("&#");
            chars.next(); // skip #
            if chars.peek() == Some(&'x') || chars.peek() == Some(&'X') {
                entity.push('x');
                chars.next(); // skip x
                let mut hex_val = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch == ';' {
                        chars.next(); // skip ;
                        if let Ok(code) = u32::from_str_radix(&hex_val, 16) {
                            if let Some(decoded) = char::from_u32(code) {
                                result.push(decoded);
                            } else {
                                result.push_str(&format!("&#x{};", hex_val));
                            }
                        } else {
                            result.push_str(&format!("&#x{};", hex_val));
                        }
                        break;
                    }
                    hex_val.push(ch);
                    chars.next();
                }
            } else {
                let mut dec_val = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch == ';' {
                        chars.next(); // skip ;
                        if let Ok(code) = dec_val.parse::<u32>() {
                            if let Some(decoded) = char::from_u32(code) {
                                result.push(decoded);
                            } else {
                                result.push_str(&format!("&#{};", dec_val));
                            }
                        } else {
                            result.push_str(&format!("&#{};", dec_val));
                        }
                        break;
                    }
                    dec_val.push(ch);
                    chars.next();
                }
            }
        } else {
            result.push(c);
        }
    }

    result
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
    fn test_decode_numeric_entities_hex() {
        assert_eq!(decode_numeric_entities("&#x41;"), "A");
        assert_eq!(decode_numeric_entities("&#x4F60;"), "你");
    }

    #[test]
    fn test_decode_numeric_entities_dec() {
        assert_eq!(decode_numeric_entities("&#65;"), "A");
        assert_eq!(decode_numeric_entities("&#20320;"), "你");
    }

    #[test]
    fn test_decode_numeric_entities_mixed() {
        let text = "Hello &#x57;orld &#33;";
        assert_eq!(decode_numeric_entities(text), "Hello World !");
    }

    #[test]
    fn test_html_to_plain_text_nested_inline_tags() {
        let text = html_to_plain_text("<p><b>Bold</b> <i>italic</i></p>");
        assert_eq!(text, "Bold\nitalic");
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
}
