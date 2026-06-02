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
    /// 累积偏移量，spine_offsets[i] = spine 0..i 的总字符数
    /// 首次调用 content_length() 或 build_spine_offsets() 时计算
    spine_offsets: OnceLock<Vec<u64>>,
}

impl EpubContentProvider {
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
            .find(|c| c.chapter_index == chapter_index)
            .ok_or_else(|| {
                AppError::chapter_extract_error(
                    chapter_index,
                    format!("chapter {} not found", chapter_index),
                )
            })?;

        let spine = epub.spine();
        let start = chapter.start_index as usize;
        let end = (chapter.end_index as usize).min(spine.len()).max(start + 1);

        let spine_hrefs: Vec<String> = spine[start..end].to_vec();
        let count = spine_hrefs.len();

        Ok(Self {
            epub: Mutex::new(epub),
            spine_hrefs,
            spine_texts: (0..count).map(|_| OnceLock::new()).collect(),
            spine_offsets: OnceLock::new(),
        })
    }

    /// 确保指定 spine index 的纯文本已缓存，返回其引用
    ///
    /// 在 spine 文本后追加 `\n` 分隔符（最后一个 spine 除外），
    /// 以保持与旧版 `parts.join("\n")` 相同的行为。
    fn ensure_spine_text(&self, index: usize) -> Result<&str, AppError> {
        if let Some(text) = self.spine_texts[index].get() {
            return Ok(text.as_str());
        }

        let mut epub = self.epub.lock();
        let href = &self.spine_hrefs[index];
        let html = epub.read_resource(href).map_err(|e| {
            AppError::chapter_extract_error(
                -1,
                format!("failed to read spine item {}: {}", href, e),
            )
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

    /// 构建并缓存 spine 累积偏移数组
    ///
    /// `spine_offsets[i]` = spine 0..i 的总字符数
    /// 偏移量包含 \n 分隔符。
    fn build_spine_offsets(&self) -> Result<&[u64], AppError> {
        self.spine_offsets
            .get_or_try_init(|| {
                let mut offsets = Vec::with_capacity(self.spine_texts.len() + 1);
                offsets.push(0);
                for i in 0..self.spine_texts.len() {
                    let len = self.ensure_spine_text(i)?.len() as u64;
                    offsets.push(*offsets.last().unwrap() + len);
                }
                Ok(offsets)
            })
            .map(|v| v.as_slice())
    }
}

impl ChapterContentProvider for EpubContentProvider {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError> {
        let offsets = self.build_spine_offsets()?;
        let total = *offsets.last().unwrap();
        let start = start.min(total);
        let end = end.min(total);

        if start >= end {
            return Ok(String::new());
        }

        // 二分查找与 [start, end) 重叠的 spine 索引范围
        // offsets[i] ≤ start 的最大 i → spine index
        let first_spine = offsets
            .partition_point(|&off| off <= start)
            .saturating_sub(1);
        // offsets[i] < end 的个数 → exclusive end index
        let last_spine = offsets.partition_point(|&off| off < end);

        let mut result = String::with_capacity((end - start) as usize);
        for (relative_idx, &spine_start) in offsets[first_spine..last_spine].iter().enumerate() {
            let i = first_spine + relative_idx;
            let spine_text = self.ensure_spine_text(i)?;
            let local_start = (start.saturating_sub(spine_start)) as usize;
            let local_end = (end.saturating_sub(spine_start) as usize).min(spine_text.len());
            if local_start < local_end {
                result.push_str(&spine_text[local_start..local_end]);
            }
        }
        Ok(result)
    }

    fn content_length(&self) -> u64 {
        self.build_spine_offsets()
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

/// 将 HTML 片段转换为纯文本
///
/// 策略：
/// 1. 移除 `<script>` 和 `<style>` 块
/// 2. 提取并处理文本内容，对段落进行 trim 和空格压缩
/// 3. 将块级标签（`<p>`, `<br>`, `</div>` 等）替换为换行符
/// 4. 移除剩余所有 HTML 标签
/// 5. 解码 HTML 实体
/// 6. 清理多余的换行符
fn html_to_plain_text(html: &str) -> String {
    // 1. 移除 <script> 和 <style> 块
    let no_scripts = remove_tag_blocks(html, "script");
    let no_styles = remove_tag_blocks(&no_scripts, "style");

    // 2. 处理段落标签
    let processed = process_paragraphs(&no_styles);

    // 3. 移除所有剩余 HTML 标签
    let no_tags = remove_html_tags(&processed);

    // 4. 解码 HTML 实体
    let decoded = decode_html_entities(&no_tags);

    // 5. 清理多余的换行和空格
    clean_whitespace(&decoded)
}

/// 移除指定标签的块级内容（含标签本身）
fn remove_tag_blocks(html: &str, tag: &str) -> String {
    let mut result = String::with_capacity(html.len());
    let mut in_block = false;

    let open_start = format!("<{}", tag);
    let open_end = format!("</{}>", tag);
    let mut i = 0;
    let chars: Vec<char> = html.chars().collect();

    while i < chars.len() {
        if !in_block {
            if chars[i] == '<' {
                let remaining: String = chars[i..].iter().collect();
                if remaining.to_lowercase().starts_with(&open_start) {
                    in_block = true;
                    // 跳过到 > 或结尾
                    i += 1;
                    while i < chars.len() && chars[i] != '>' {
                        i += 1;
                    }
                    if i < chars.len() {
                        i += 1; // skip '>'
                    }
                    continue;
                }
            }
            result.push(chars[i]);
            i += 1;
        } else {
            // 查找闭合标签
            let remaining: String = chars[i..].iter().collect();
            if let Some(pos) = remaining.to_lowercase().find(&open_end) {
                i += pos + open_end.len();
                in_block = false;
            } else {
                break;
            }
        }
    }

    result
}

/// 处理段落标签内容：trim 并压缩空格
fn process_paragraphs(html: &str) -> String {
    let chars: Vec<char> = html.chars().collect();
    let mut result = String::with_capacity(html.len());
    let mut i = 0;

    while i < chars.len() {
        if chars[i] == '<' {
            let remaining: String = chars[i..].iter().collect();
            let lower = remaining.to_lowercase();

            // 检测段落相关的块级标签
            let is_para_block = html_starts_with(&chars[i..], "<p")
                || html_starts_with(&chars[i..], "</")
                || html_starts_with(&chars[i..], "<div")
                || html_starts_with(&chars[i..], "<h1")
                || html_starts_with(&chars[i..], "<h2")
                || html_starts_with(&chars[i..], "<h3")
                || html_starts_with(&chars[i..], "<h4")
                || html_starts_with(&chars[i..], "<h5")
                || html_starts_with(&chars[i..], "<h6")
                || html_starts_with(&chars[i..], "<li")
                || html_starts_with(&chars[i..], "<tr")
                || html_starts_with(&chars[i..], "<th")
                || html_starts_with(&chars[i..], "<td")
                || html_starts_with(&chars[i..], "<blockquote")
                || html_starts_with(&chars[i..], "<dd")
                || html_starts_with(&chars[i..], "<dt")
                || html_starts_with(&chars[i..], "<figcaption")
                || html_starts_with(&chars[i..], "<figure")
                || html_starts_with(&chars[i..], "<br");

            if is_para_block || lower.starts_with("</") && !lower.starts_with("</a>") {
                result.push('\n');
            }

            // 跳过整个 HTML 标签
            let skip = skip_html_tag(&remaining);
            if skip > 0 {
                i += skip;
                continue;
            }
        }

        // 压缩空格
        if chars[i].is_whitespace() && !chars[i].is_control() {
            // 找到完整空格序列的结束
            let space_start = i;
            while i < chars.len()
                && chars[i].is_whitespace()
                && !chars[i].is_control()
            {
                i += 1;
            }

            // 检查空格前后内容
            let after_chars: String = chars[i..].iter().collect();
            let at_end = after_chars.trim().is_empty();
            if !at_end {
                // 检查是否在特殊标签内
                let before = if space_start > 0 {
                    chars[space_start - 1]
                } else {
                    ' '
                };
                if before != '\n' {
                    result.push(' ');
                }
            }
        } else {
            result.push(chars[i]);
            i += 1;
        }
    }

    result
}

/// 检查字符切片是否以特定字符串开头
fn html_starts_with(slice: &[char], suffix: &str) -> bool {
    if slice.len() < suffix.len() {
        return false;
    }
    let suffix_chars: Vec<char> = suffix.chars().collect();
    for i in 0..suffix_chars.len() {
        if slice[i].to_ascii_lowercase() != suffix_chars[i] {
            return false;
        }
    }
    true
}

/// 跳过 HTML 标签（从 < 之后开始）
fn skip_html_tag(s: &str) -> usize {
    let chars: Vec<char> = s.chars().collect();
    if chars.is_empty() || chars[0] != '<' {
        return 0;
    }

    // 处理注释 <!-- ... -->
    if chars.len() >= 4 && chars[1] == '!' && chars[2] == '-' && chars[3] == '-' {
        let mut i = 4;
        while i + 2 < chars.len() {
            if chars[i] == '-' && chars[i + 1] == '-' && chars[i + 2] == '>' {
                return i + 3;
            }
            i += 1;
        }
        return chars.len();
    }

    // 常规标签 <...>
    for i in 1..chars.len() {
        if chars[i] == '>' {
            return i + 1;
        }
    }

    chars.len()
}

/// 移除 HTML 标签
fn remove_html_tags(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut in_tag = false;
    let mut in_entity = false;
    let mut entity_buf = String::new();

    for c in s.chars() {
        if in_tag {
            if c == '>' {
                in_tag = false;
            }
        } else if c == '<' {
            in_tag = true;
        } else if c == '&' {
            in_entity = true;
            entity_buf.clear();
            entity_buf.push(c);
        } else if in_entity {
            entity_buf.push(c);
            if c == ';' {
                result.push_str(&decode_entity(&entity_buf));
                in_entity = false;
            }
        } else {
            result.push(c);
        }
    }

    result
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

/// 解码 HTML 实体（完整实现）
fn decode_html_entities(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut in_entity = false;
    let mut entity_buf = String::new();

    for c in text.chars() {
        if c == '&' {
            in_entity = true;
            entity_buf.clear();
            entity_buf.push(c);
        } else if in_entity {
            entity_buf.push(c);
            if c == ';' {
                // 尝试解码命名字符实体
                let decoded = match entity_buf.as_str() {
                    "&amp;" => "&",
                    "&lt;" => "<",
                    "&gt;" => ">",
                    "&quot;" => "\"",
                    "&apos;" => "'",
                    "&nbsp;" => "\u{00A0}",
                    "&mdash;" => "\u{2014}",
                    "&ndash;" => "\u{2013}",
                    "&hellip;" => "\u{2026}",
                    "&ldquo;" => "\u{201C}",
                    "&rdquo;" => "\u{201D}",
                    "&lsquo;" => "\u{2018}",
                    "&rsquo;" => "\u{2019}",
                    "&laquo;" => "\u{00AB}",
                    "&raquo;" => "\u{00BB}",
                    "&bull;" => "\u{2022}",
                    "&copy;" => "\u{00A9}",
                    "&reg;" => "\u{00AE}",
                    "&trade;" => "\u{2122}",
                    "&euro;" => "\u{20AC}",
                    "&pound;" => "\u{00A3}",
                    "&yen;" => "\u{00A5}",
                    _ => "",
                };
                if decoded.is_empty() {
                    // 尝试数字实体
                    if let Some(hex) = entity_buf
                        .strip_prefix("&#x")
                        .and_then(|s| s.strip_suffix(';'))
                    {
                        if let Ok(code) = u32::from_str_radix(hex, 16) {
                            if let Some(ch) = char::from_u32(code) {
                                result.push(ch);
                                in_entity = false;
                                continue;
                            }
                        }
                    } else if let Some(dec) = entity_buf
                        .strip_prefix("&#")
                        .and_then(|s| s.strip_suffix(';'))
                    {
                        if let Ok(code) = dec.parse::<u32>() {
                            if let Some(ch) = char::from_u32(code) {
                                result.push(ch);
                                in_entity = false;
                                continue;
                            }
                        }
                    }
                    // 未知实体按原样保留
                    result.push_str(&entity_buf);
                } else {
                    result.push_str(decoded);
                }
                in_entity = false;
            }
        } else {
            result.push(c);
        }
    }

    // 如果实体未闭合，保留原样
    if in_entity {
        result.push_str(&entity_buf);
    }

    result
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
}
