// ============================================================
// 文件作用：HTML → 纯文本转换工具函数
//
// 公有函数：
//   - html_to_plain_text() — HTML 片段转纯文本（2-pass 策略）
//
// 私有函数：
//   - decode_entity() — 解码单个 HTML 实体
//   - clean_whitespace() — 清理空白字符
// ============================================================

//! HTML → 纯文本转换
//!
//! Pass 1: byte-level 单次扫描，剥离标签、解码实体、压缩空格。
//! Pass 2: clean_whitespace 清理多余换行和前后空白。

/// 将 HTML 片段转换为纯文本（2-pass 策略）
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

        let c = html[pos..].chars().next().unwrap_or('?');
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
                let next = html[pos..].chars().next().unwrap_or('\0');
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
}