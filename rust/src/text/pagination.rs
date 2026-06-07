//! 页面排版分页
//! 提供分页流式处理，支持懒加载模式以减少大文件内存占用

use crate::domain::{PageContent, PageOffset, TypesetConfig};
use crate::text::char_width::CharWidthTable;
use crate::text::constants::is_start_avoid_punctuation;
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
            let char_width = width_table.char_width(ch);
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

        if end < char_count && end > start {
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
}

/// 主动模式内存阈值（100 MB），超过此大小记录警告
const PAGE_STREAMER_MEMORY_THRESHOLD: usize = 100 * 1024 * 1024;
/// 懒加载模式字符数阈值（50K 字符）
/// 当内容字符数超过此值时使用懒加载分页，避免预计算所有行偏移
const LAZY_PAGINATION_CHAR_THRESHOLD: usize = 50_000;

#[frb]
impl PageStreamer {
    pub fn new(content: String, config: TypesetConfig) -> Self {
        let content_len = content.len();
        if content_len > LAZY_PAGINATION_CHAR_THRESHOLD {
            return Self::new_lazy(content, config);
        }
        Self::new_eager(content, config)
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
        let max_line_width = effective_width - indent_width;

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
                compute_line_breaks_from_indices(para_indices, para_start, para_end, max_line_width, &width_table);

            for (i, (start, end)) in line_breaks.iter().enumerate() {
                let line_start = global_offset + *start;
                let line_end = global_offset + *end;
                line_offsets.push((line_start, line_end));
                first_of_paragraph.push(i == 0);
            }

            global_offset += line_with_ending.len();
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
    fn extract_line(&self, line_idx: usize) -> &str {
        if self.line_offsets.is_empty() {
            return "";
        }
        let (start, end) = self.line_offsets[line_idx];
        &self.content[start..end]
    }

    #[frb(sync)]
    pub fn current_page(&self, chapter_index: i32) -> Option<PageContent> {
        self.get_page(self.current_page, chapter_index)
    }

    #[frb(sync)]
    pub fn get_page(&self, page_index: usize, chapter_index: i32) -> Option<PageContent> {
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

    #[frb(sync)]
    pub fn get_page_offsets(&self) -> Vec<PageOffset> {
        if self.line_offsets.is_empty() {
            let total = self.total_pages();
            let chars_per_page = self.chars_per_line * self.lines_per_page;
            let mut offsets = Vec::with_capacity(total);
            for page_idx in 0..total {
                let start = page_idx * chars_per_page;
                let end = (start + chars_per_page).min(self.content.len());
                offsets.push(PageOffset {
                    offset: start as i32,
                    length: (end - start) as i32,
                });
            }
            return offsets;
        }
        let mut offsets = Vec::with_capacity(self.total_pages());

        for page_idx in 0..self.total_pages() {
            let start_line = page_idx * self.lines_per_page;
            let end_line = (start_line + self.lines_per_page).min(self.total_lines);

            if start_line >= self.line_offsets.len() {
                offsets.push(PageOffset {
                    offset: 0,
                    length: 0,
                });
                continue;
            }

            let actual_end = end_line.min(self.line_offsets.len());
            let (page_start, _) = self.line_offsets[start_line];
            let (_, page_end) = self.line_offsets[actual_end.saturating_sub(1)];

            offsets.push(PageOffset {
                offset: page_start as i32,
                length: (page_end - page_start) as i32,
            });
        }

        offsets
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
        // Create >50K bytes of Chinese text to trigger lazy mode
        // Each Chinese character is 3 bytes in UTF-8: 20,000 chars = 60,000 bytes
        let content = "中".repeat(20_000);
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
}
