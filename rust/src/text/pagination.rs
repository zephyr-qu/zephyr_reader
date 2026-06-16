//! 页面排版分页
//! 提供分页流式处理，支持懒加载模式以减少大文件内存占用

use crate::domain::{LanguageType, PageContent, PageDescriptor, TypesetConfig};
use crate::text::char_width::CharWidthTable;
use crate::text::constants::{is_cjk_char, is_cjk_punctuation, is_start_avoid_punctuation};
use crate::text::typeset::{optimize_punctuation, optimize_spaces};
use flutter_rust_bridge::frb;


/// 排版安全余量（像素），防止字符恰好贴边
const SAFETY_MARGIN_PX: f32 = 2.0;

/// 使用预计算的 char_indices 计算行分割
fn compute_line_breaks_from_indices(
    para_char_indices: &[(usize, char)],
    para_start: usize,
    para_end: usize,
    max_width_px: f32,
    width_table: &CharWidthTable,
    auto_space_px: f32,
    letter_spacing_px: f32,
    punctuation_squeeze: bool,
) -> Vec<(usize, usize)> {
    let char_count = para_char_indices.len();
    let mut lines = Vec::new();
    if char_count == 0 {
        return lines;
    }

    let mut start = 0;

    while start < char_count {
        let mut current_width = 0.0;
        let mut end = start;

        for offset in 0..(char_count - start) {
            let (_, ch) = para_char_indices[start + offset];
            let mut char_width = width_table.char_width(ch) + letter_spacing_px;
            // 标点挤压: 连续 CJK 标点以 65% 宽度显示
            if punctuation_squeeze && offset > 0 {
                let prev_ch = para_char_indices[start + offset - 1].1;
                let prev_is_punct = is_cjk_punctuation(prev_ch);
                let curr_is_punct = is_cjk_punctuation(ch);
                if prev_is_punct && curr_is_punct {
                    char_width *= 0.65;
                }
            }

            // 中西文自动间距
            if offset > 0 {
                let prev_ch = para_char_indices[start + offset - 1].1;
                let prev_is_cjk = is_cjk_char(prev_ch);
                let prev_is_latin = prev_ch.is_ascii_alphabetic() || prev_ch.is_ascii_digit();
                let curr_is_cjk = is_cjk_char(ch);
                let curr_is_latin = ch.is_ascii_alphabetic() || ch.is_ascii_digit();
                if (prev_is_cjk && curr_is_latin) || (prev_is_latin && curr_is_cjk) {
                    char_width += auto_space_px;
                }
            }

            if current_width + char_width <= max_width_px {
                current_width += char_width;
                end = start + offset + 1;
            } else {
                break;
            }
        }

        if end == start {
            end = start + 1;
        }

        if end < char_count && end > start + 1 {
            let next_char = para_char_indices[end].1;
            if is_start_avoid_punctuation(next_char) {
                end -= 1;
            }
        }

        let byte_start = para_char_indices[start].0;
        let byte_end = if end < char_count {
            para_char_indices[end].0
        } else {
            para_end
        };
        lines.push((byte_start - para_start, byte_end - para_start));
        start = end;
    }

    lines
}

/// 分页流处理器
///
/// 根据排版配置将文本内容分割为页面。
/// 提供两种模式：eager 模式（小文件，预计算所有行偏移）和 lazy 模式（大文件，按需计算）。
/// 通过 `#[frb(opaque)]` 暴露给 Flutter 侧使用。
#[derive(Clone)]
#[frb(opaque)]
pub struct PageStreamer {
    content: String,
    pub(crate) current_page: usize,
    pub(crate) lines_per_page: usize,
    pub(crate) line_offsets: Vec<(usize, usize)>,
    total_lines: usize,
    chars_per_line: usize,
    /// Byte offsets of each character boundary, for safe UTF-8 indexing in lazy mode
    char_boundaries: Vec<usize>,
    /// Whether each line is the first line of a paragraph (eager mode)
    first_of_paragraph: Vec<bool>,
    /// Indentation string (e.g., "  ") (eager mode)
    indent_str: String,
    /// Pre-computed pages from KV cache (populated by from_pages)
    cached_pages: Option<Vec<PageContent>>,
}

/// 主动模式内存阈值（100 MB），超过此大小记录警告
const PAGE_STREAMER_MEMORY_THRESHOLD: usize = 100 * 1024 * 1024;
/// 懒加载模式字符数阈值（50K 字符）
/// 当内容字符数超过此值时使用懒加载分页，避免预计算所有行偏移
const LAZY_PAGINATION_CHAR_THRESHOLD: usize = 50_000;

#[frb]
impl PageStreamer {
    pub fn new(content: String, config: TypesetConfig) -> Self {
        // 先判断是否需要惰性分页，大章节直接跳过文本预处理（O(n) 字符串复制）
        if content.chars().count() > LAZY_PAGINATION_CHAR_THRESHOLD {
            return Self::new_lazy(content, config);
        }
        // 小章节：标点优化 + 空格优化（避头避尾、CJK/Latin 间距等）
        let lang = match config.language {
            LanguageType::Chinese => "zh",
            LanguageType::English => "en",
            LanguageType::Auto | LanguageType::Mixed => "auto",
        };
        let punct = optimize_punctuation(&content, lang);
        let optimized = optimize_spaces(&punct, lang);
        Self::new_eager(optimized.into_owned(), config)
    }

    /// Create a PageStreamer from pre-computed page content (KV cache hit).
    /// Skips CPU-intensive typesetting — pages are served directly.
    pub fn from_pages(pages: Vec<PageContent>) -> Self {
        let total_pages = pages.len();
        Self {
            cached_pages: Some(pages),
            content: String::new(),
            current_page: 0,
            lines_per_page: 1,
            line_offsets: Vec::new(),
            total_lines: total_pages,
            chars_per_line: 0,
            char_boundaries: Vec::new(),
            first_of_paragraph: Vec::new(),
            indent_str: String::new(),
        }
    }

    fn new_eager(content: String, config: TypesetConfig) -> Self {
        let start_time = std::time::Instant::now();
        let content_len = content.len();

        if content_len > PAGE_STREAMER_MEMORY_THRESHOLD {
            tracing::warn!(
                "content size is large ({} MB), may cause high memory usage.",
                content_len / 1024 / 1024
            );
        }

        let font_size = config.font_size as f32;
        let line_spacing = config.line_spacing;
        let page_height_px = config.page_height as f32;
        let page_width_px = config.page_width as f32;

        let line_height = (font_size * line_spacing).max(1.0);
        let lines_per_page = ((page_height_px / line_height) as usize).max(5);

        let indent_width = font_size * config.first_line_indent as f32;
        let effective_width = (page_width_px - SAFETY_MARGIN_PX).max(1.0);
        let max_line_width = (effective_width - indent_width).max(font_size);

        let auto_space_px = (font_size * config.auto_space_ratio).max(1.0);

        let width_table = CharWidthTable::from_calibration(
            config.calibration.as_ref().unwrap_or(&Default::default()),
        );

        let indent_str = "  ".repeat(config.first_line_indent as usize);

        // M4: 使用 chars_per_line 而非 content.len()/40 估算，避免 CJK 估偏
        let avg_char_width = width_table.char_width('中').max(1.0);
        let chars_per_line = (effective_width / avg_char_width * 1.2).max(10.0) as usize;
        let estimated_lines = content.chars().count() / chars_per_line + 1;
        let mut line_offsets = Vec::with_capacity(estimated_lines);
        let mut first_of_paragraph = Vec::with_capacity(estimated_lines);
        let mut global_offset = 0;

        // M3: 一次性计算全文 char_indices，段落复用
        let full_char_indices: Vec<(usize, char)> = content.char_indices().collect();

        for line_with_ending in content.split_inclusive(|c| c == '\n') {
            let paragraph = line_with_ending.trim_end_matches(['\r', '\n']);

            if paragraph.is_empty() {
                line_offsets.push((global_offset, global_offset));
                first_of_paragraph.push(false);
                global_offset += line_with_ending.len();
                continue;
            }

            let para_start = global_offset;
            let para_end = para_start + paragraph.len();

            // Find char_indices subrange for this paragraph via binary search
            let start_idx =
                full_char_indices.partition_point(|&(byte, _)| byte < para_start);
            let end_idx =
                full_char_indices.partition_point(|&(byte, _)| byte < para_end);
            let para_indices = &full_char_indices[start_idx..end_idx];

            let line_breaks =
                compute_line_breaks_from_indices(para_indices, para_start, para_end, max_line_width, &width_table, auto_space_px, config.letter_spacing, config.punctuation_squeeze);
            for (i, (start, end)) in line_breaks.iter().enumerate() {
                let line_start = global_offset + *start;
                let line_end = global_offset + *end;
                line_offsets.push((line_start, line_end));
                first_of_paragraph.push(i == 0);
            }
            global_offset += line_with_ending.len();

            // 段落间距：在两个**非空**段落之间添加空白行
            if config.paragraph_spacing > 0.0
                && !paragraph.is_empty()
                && line_offsets.last().map(|(s, e)| s != e).unwrap_or(false)
            {
                let spacer_lines = (config.paragraph_spacing * line_spacing).round() as usize;
                for _ in 0..spacer_lines {
                    line_offsets.push((global_offset, global_offset));
                    first_of_paragraph.push(false);
                }
            }
        }

        let total_lines = line_offsets.len();

        let elapsed = start_time.elapsed();
        tracing::debug!(
            "pagination done: lines={}, pages={}, elapsed={:?}",
            total_lines,
            total_lines.div_ceil(lines_per_page),
            elapsed
        );

        Self {
            content,
            current_page: 0,
            lines_per_page,
            line_offsets,
            total_lines,
            chars_per_line,
            char_boundaries: Vec::new(),
            first_of_paragraph,
            indent_str,
            cached_pages: None,
        }
    }

    fn new_lazy(content: String, config: TypesetConfig) -> Self {
        let font_size = config.font_size as f32;
        let line_spacing = config.line_spacing;
        let page_height_px = config.page_height as f32;
        let page_width_px = config.page_width as f32;

        let line_height = (font_size * line_spacing).max(1.0);
        let lines_per_page = ((page_height_px / line_height) as usize).max(5);

        let effective_width = (page_width_px - SAFETY_MARGIN_PX).max(1.0);
        let width_table = CharWidthTable::from_calibration(
            config.calibration.as_ref().unwrap_or(&Default::default()),
        );
        let avg_char_width = width_table.char_width('中').max(1.0);
        let chars_per_line = (effective_width / avg_char_width * 1.2).max(10.0) as usize;

        // 用字符数而非字节数计算 total_lines
        let total_chars = content.chars().count();
        let total_lines = total_chars.div_ceil(chars_per_line);

        // 预计算 char_indices 供 get_page_lazy 安全索引
        let char_boundaries: Vec<usize> = content.char_indices().map(|(i, _)| i).collect();

        Self {
            content,
            current_page: 0,
            lines_per_page,
            line_offsets: Vec::new(),
            total_lines,
            chars_per_line,
            char_boundaries,
            first_of_paragraph: Vec::new(),
            indent_str: String::new(),
            cached_pages: None,
        }
    }

    /// Build the content string for a single page (eager mode only).
    fn build_single_page(&self, page_idx: usize) -> String {
        let start_line = page_idx * self.lines_per_page;
        let end_line = (start_line + self.lines_per_page).min(self.total_lines);
        let mut page_content = String::new();
        for i in start_line..end_line {
            if i > start_line {
                page_content.push('\n');
            }
            if self.first_of_paragraph[i] && !self.indent_str.is_empty() {
                page_content.push_str(&self.indent_str);
            }
            let (s, e) = self.line_offsets[i];
            page_content.push_str(&self.content[s..e]);
        }
        page_content
    }

    #[frb(sync)]
    pub fn current_page(&self, chapter_index: i32) -> Option<PageContent> {
        self.get_page(self.current_page, chapter_index)
    }

    #[frb(sync)]
    pub fn get_page(&self, page_index: usize, chapter_index: i32) -> Option<PageContent> {
        if let Some(ref pages) = self.cached_pages {
            return pages.get(page_index).cloned();
        }
        if self.line_offsets.is_empty() {
            return self.get_page_lazy(page_index, chapter_index);
        }
        if page_index >= self.total_pages() || self.total_lines == 0 {
            return None;
        }

        let page_content = self.build_single_page(page_index);

        let start = page_index * self.lines_per_page;
        let end = (start + self.lines_per_page).min(self.total_lines);

        Some(PageContent {
            chapter_index,
            page_index: page_index as i32,
            content: page_content,
            is_last_page: end >= self.total_lines,
            start_offset: self.line_offsets[start].0 as i32,
            end_offset: self.line_offsets[end - 1].1 as i32,
        })
    }

    fn get_page_lazy(&self, page_index: usize, chapter_index: i32) -> Option<PageContent> {
        let total = self.total_pages();
        if page_index >= total || self.total_lines == 0 {
            return None;
        }
        let chars_per_page = self.chars_per_line * self.lines_per_page;
        let char_start = page_index * chars_per_page;
        let char_end = (char_start + chars_per_page).min(self.total_chars());

        // 将字符索引转换为安全的字节索引
        let byte_start = self.char_boundaries
            .get(char_start)
            .copied()
            .unwrap_or(self.content.len());
        let byte_end = self.char_boundaries
            .get(char_end)
            .copied()
            .unwrap_or(self.content.len());

        let page_content = self.content[byte_start..byte_end].to_string();

        Some(PageContent {
            chapter_index,
            page_index: page_index as i32,
            content: page_content,
            is_last_page: char_end >= self.total_chars(),
            start_offset: byte_start as i32,
            end_offset: byte_end as i32,
        })
    }

    #[frb(sync)]
    pub fn next_page(&mut self, chapter_index: i32) -> Option<PageContent> {
        if self.current_page >= self.total_pages().saturating_sub(1) {
            return None;
        }
        self.current_page += 1;
        self.current_page(chapter_index)
    }

    #[frb(sync)]
    pub fn prev_page(&mut self, chapter_index: i32) -> Option<PageContent> {
        if self.current_page == 0 {
            return None;
        }
        self.current_page -= 1;
        self.current_page(chapter_index)
    }

    #[frb(sync)]
    pub fn seek_to(&mut self, page_index: usize) {
        self.current_page = page_index.min(self.total_pages().saturating_sub(1));
    }

    #[frb(sync)]
    pub fn total_pages(&self) -> usize {
        if let Some(ref pages) = self.cached_pages {
            return pages.len();
        }
        if self.total_lines == 0 {
            return 0;
        }
        self.total_lines.div_ceil(self.lines_per_page)
    }

    #[frb(sync)]
    pub fn current_page_index(&self) -> usize {
        self.current_page
    }

    #[frb(sync)]
    pub fn progress(&self) -> f32 {
        if let Some(ref pages) = self.cached_pages {
            if pages.is_empty() {
                return 0.0;
            }
            return ((self.current_page + 1) as f32 / pages.len() as f32).min(1.0);
        }
        if self.total_lines == 0 {
            return 0.0;
        }
        let current_lines = (self.current_page + 1) * self.lines_per_page;
        (current_lines as f32 / self.total_lines as f32).min(1.0)
    }

    #[frb(sync)]
    pub fn total_lines(&self) -> usize {
        self.total_lines
    }

    fn total_chars(&self) -> usize {
        self.char_boundaries.len()
    }

    #[frb(sync)]
    pub fn current_line_index(&self) -> usize {
        self.current_page * self.lines_per_page
    }


    /// 获取所有页面的描述符（轻量级，不含文本内容）。
    ///
    /// Eager 模式基于预计算的 `line_offsets` 计算偏移量。
    /// Lazy 模式基于 `char_boundaries` 估算偏移量。
    #[frb(sync)]
    pub fn get_descriptors(&self) -> Vec<PageDescriptor> {
        if let Some(ref pages) = self.cached_pages {
            return pages.iter().map(|p| PageDescriptor {
                page_index: p.page_index,
                start_offset: p.start_offset,
                end_offset: p.end_offset,
                is_last_page: p.is_last_page,
            }).collect();
        }
        if self.line_offsets.is_empty() {
            return self.get_descriptors_lazy();
        }
        let total = self.total_pages();
        let mut descriptors = Vec::with_capacity(total);
        for page_idx in 0..total {
            let start_line = page_idx * self.lines_per_page;
            let end_line = (start_line + self.lines_per_page).min(self.total_lines);

            let start_offset = self.line_offsets[start_line].0 as i32;
            let end_offset = self.line_offsets[end_line.saturating_sub(1)].1 as i32;
            let is_last_page = end_line >= self.total_lines;

            descriptors.push(PageDescriptor {
                page_index: page_idx as i32,
                start_offset,
                end_offset,
                is_last_page,
            });
        }
        descriptors
    }

    fn get_descriptors_lazy(&self) -> Vec<PageDescriptor> {
        let total = self.total_pages();
        let mut descriptors = Vec::with_capacity(total);
        let chars_per_page = self.chars_per_line * self.lines_per_page;
        let total_chars = self.total_chars();
        for page_idx in 0..total {
            let char_start = page_idx * chars_per_page;
            let char_end = (char_start + chars_per_page).min(total_chars);

            let byte_start = self.char_boundaries
                .get(char_start)
                .copied()
                .unwrap_or(self.content.len());
            let byte_end = self.char_boundaries
                .get(char_end)
                .copied()
                .unwrap_or(self.content.len());

            descriptors.push(PageDescriptor {
                page_index: page_idx as i32,
                start_offset: byte_start as i32,
                end_offset: byte_end as i32,
                is_last_page: char_end >= total_chars,
            });
        }
        descriptors
    }
}

/// 对全文进行完整分页，返回所有页面的内容列表
///
/// # 参数
///
/// * `content` - 文本内容
/// * `chapter_index` - 章节索引
/// * `config` - 排版配置
///
/// # 返回值
///
/// 按页码顺序排列的 `PageContent` 列表
pub fn paginate_all(
    content: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Vec<PageContent> {
    let streamer = PageStreamer::new(content, config);
    let total = streamer.total_pages();
    let mut pages = Vec::with_capacity(total);

    for i in 0..total {
        if let Some(page) = streamer.get_page(i, chapter_index) {
            pages.push(page);
        }
    }
    pages
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::TypesetConfig;

    #[test]
    fn test_page_streamer_new_empty() {
        let streamer = PageStreamer::new(String::new(), TypesetConfig::default());
        assert_eq!(streamer.total_pages(), 0);
        assert_eq!(streamer.total_lines(), 0);
        assert!(streamer.get_page(0, 0).is_none());
    }

    #[test]
    fn test_page_streamer_single_paragraph_no_wrap() {
        let content = "短文本".to_string();
        let streamer = PageStreamer::new(content, TypesetConfig::default());
        assert!(streamer.total_pages() > 0);
        let page = streamer.get_page(0, 0);
        assert!(page.is_some());
        assert!(page.unwrap().content.contains("短文本"));
    }

    #[test]
    fn test_page_streamer_multi_paragraph() {
        let content = "第一段内容\n\n第二段内容\n\n第三段内容".to_string();
        let mut config = TypesetConfig::default();
        config.font_size = 100;
        config.page_width = 200;
        let streamer = PageStreamer::new(content, config);
        assert!(streamer.total_pages() > 0);
        let first_page = streamer.get_page(0, 0).unwrap();
        assert!(!first_page.content.is_empty());
    }

    #[test]
    fn test_page_streamer_get_page_boundary() {
        let content = "line1\nline2\nline3\nline4\nline5".to_string();
        let mut config = TypesetConfig::default();
        config.page_width = 100;
        config.font_size = 100;
        config.page_height = 200;
        let streamer = PageStreamer::new(content, config);
        let total = streamer.total_pages();
        assert!(total > 0);
        let last = streamer.get_page(total - 1, 0);
        assert!(last.is_some());
        let out_of_range = streamer.get_page(total, 0);
        assert!(out_of_range.is_none());
    }

    #[test]
    fn test_page_streamer_total_pages_division() {
        let content = "A\nB\nC\nD\nE\nF\nG\nH\nI\nJ".to_string();
        let mut config = TypesetConfig::default();
        config.page_height = 1;
        config.font_size = 100;
        config.page_width = 10;
        let streamer = PageStreamer::new(content, config);
        assert!(streamer.total_pages() >= 1);
    }

    #[test]
    fn test_lazy_mode_large_chinese_text_no_panic() {
        // 50K+ characters to trigger lazy mode
        let content = "中".repeat(60_000);
        let mut config = TypesetConfig::default();
        // Force small pages to have multiple pages
        config.font_size = 100;
        config.page_width = 200;
        config.page_height = 200;

        let streamer = PageStreamer::new(content, config);

        // Verify lazy mode was triggered (line_offsets empty)
        assert!(streamer.line_offsets.is_empty());
        assert!(streamer.total_pages() > 0);

        // Access every page - must not panic (regression test for byte/char confusion)
        let total = streamer.total_pages();
        for i in 0..total {
            let page = streamer.get_page(i, 0);
            assert!(page.is_some(), "page {} should exist in lazy mode", i);
            assert!(!page.unwrap().content.is_empty(), "page {} content should not be empty", i);
        }
    }

    #[test]
    fn test_letter_spacing_reduces_chars_per_line() {
        let content = "ABCDEFGHIJ".to_string();
        let mut config_no = TypesetConfig::default();
        config_no.font_size = 20;
        config_no.page_width = 100;
        config_no.page_height = 800;
        config_no.letter_spacing = 0.0;

        let mut config_yes = TypesetConfig::default();
        config_yes.font_size = 20;
        config_yes.page_width = 100;
        config_yes.page_height = 800;
        config_yes.letter_spacing = 6.0;

        let lines_no = PageStreamer::new(content.clone(), config_no).total_lines();
        let lines_yes = PageStreamer::new(content, config_yes).total_lines();

        assert!(
            lines_yes > lines_no,
            "letter_spacing=6 should produce more lines than letter_spacing=0 \
             (got {} vs {})",
            lines_yes,
            lines_no,
        );
    }

    #[test]
    fn test_punctuation_squeeze_reduces_lines() {
        let content = "你好！！！\n你好！！！\n你好！！！\n你好！！！".to_string();
        let mut config_no = TypesetConfig::default();
        config_no.font_size = 20;
        config_no.page_width = 100;
        config_no.page_height = 600;
        config_no.punctuation_squeeze = false;

        let mut config_yes = TypesetConfig::default();
        config_yes.font_size = 20;
        config_yes.page_width = 100;
        config_yes.page_height = 600;
        config_yes.punctuation_squeeze = true;

        let lines_no = PageStreamer::new(content.clone(), config_no).total_lines();
        let lines_yes = PageStreamer::new(content, config_yes).total_lines();

        assert!(
            lines_yes <= lines_no,
            "punctuation_squeeze=true should not produce more lines than squeeze=false \
             (got {} vs {})",
            lines_yes,
            lines_no,
        );
    }

    #[test]
    fn test_paragraph_spacing_inserts_blank_lines() {
        let content = "第一段\n第二段\n第三段".to_string();
        let mut config_no = TypesetConfig::default();
        config_no.font_size = 20;
        config_no.page_width = 400;
        config_no.page_height = 800;
        config_no.paragraph_spacing = 0.0;

        let mut config_yes = TypesetConfig::default();
        config_yes.font_size = 20;
        config_yes.page_width = 400;
        config_yes.page_height = 800;
        config_yes.paragraph_spacing = 1.0;

        let lines_no = PageStreamer::new(content.clone(), config_no).total_lines();
        let lines_yes = PageStreamer::new(content, config_yes).total_lines();

        assert!(
            lines_yes > lines_no,
            "paragraph_spacing=1.0 should produce more lines than paragraph_spacing=0 \
             (got {} vs {})",
            lines_yes,
            lines_no,
        );
    }
}
