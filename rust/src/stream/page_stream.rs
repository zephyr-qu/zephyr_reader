//! 内容分页流
//! 将解析后的内容分页输出，支持基于像素宽度的精确定位

use crate::ffi::{PageContent, PageOffset, TypesetConfig};
use flutter_rust_bridge::frb;

/// 计算单个字符的像素宽度
fn char_pixel_width(c: char, font_size: f32) -> f32 {
    let cp = c as u32;

    // ✅ 优化：合并相同返回值条件
    if (0x4E00..=0x9FFF).contains(&cp)
        || (0x3400..=0x4DBF).contains(&cp)
        || (0xF900..=0xFAFF).contains(&cp)
        || (0x3000..=0x303F).contains(&cp)
    // 全角标点
    {
        font_size
    }
    // 英文、数字、半角标点
    else if c.is_ascii_graphic() || c.is_ascii_whitespace() {
        font_size * 0.6
    }
    // 其他字符
    else {
        font_size * 0.8
    }
}

/// 判断是否为避首标点
fn is_start_avoid_punctuation(c: char) -> bool {
    matches!(
        c,
        '，' | '。'
            | '、'
            | '；'
            | '：'
            | '？'
            | '！'
            | '…'
            | '—'
            | '）'
            | '】'
            | '》'
            | '」'
            | '』'
            | '!'
            | ','
            | '.'
            | '?'
            | ':'
    )
}

/// 基于像素宽度的智能断行
fn smart_line_breaks(text: &str, max_width_px: f32, font_size: f32) -> Vec<(usize, usize)> {
    let mut lines = Vec::new();
    let char_indices: Vec<(usize, char)> = text.char_indices().collect();
    let char_count = char_indices.len();

    if char_count == 0 {
        return lines;
    }

    let mut start = 0;

    while start < char_count {
        let mut current_width = 0.0;
        let mut end = start;

        // 尝试放入更多字符
        for offset in 0..(char_count - start) {
            let (_, ch) = char_indices[start + offset];
            let char_width = char_pixel_width(ch, font_size);

            if current_width + char_width <= max_width_px {
                current_width += char_width;
                end = start + offset + 1;
            } else {
                break;
            }
        }

        // 如果一行都放不下，至少放一个字符
        if end == start {
            end = start + 1;
        }

        // 检查避首标点
        if end < char_count && end > start {
            let next_char = char_indices[end].1;
            if is_start_avoid_punctuation(next_char) {
                end -= 1;
            }
        }

        let byte_start = char_indices[start].0;
        let byte_end = if end < char_count {
            char_indices[end].0
        } else {
            text.len()
        };

        lines.push((byte_start, byte_end));
        start = end;
    }

    lines
}

/// 分页器
#[frb]
#[derive(Clone)]
pub struct PageStreamer {
    pub lines: Vec<String>,
    pub current_page: usize,
    pub lines_per_page: usize,
    #[frb]
    pub line_offsets: Vec<(usize, usize)>,
}

const PAGE_STREAMER_MEMORY_THRESHOLD: usize = 100 * 1024 * 1024;

#[frb]
impl PageStreamer {
    #[frb(sync)]
    pub fn new(content: String, config: TypesetConfig) -> Self {
        let start_time = std::time::Instant::now();
        let content_len = content.len();

        if content_len > PAGE_STREAMER_MEMORY_THRESHOLD {
            tracing::warn!(
                "内容大小较大（{} MB），可能导致高内存占用。",
                content_len / 1024 / 1024
            );
        }

        let font_size = config.font_size as f32;
        let line_spacing = config.line_spacing;
        let page_height_px = config.page_height as f32;
        let page_width_px = config.page_width as f32;

        let line_height = font_size * line_spacing;
        let lines_per_page = ((page_height_px / line_height) as usize).max(5);

        let indent_width = font_size * config.first_line_indent as f32;
        let max_line_width = page_width_px - indent_width;

        // 预计算缩进字符串，避免重复分配
        let indent_str = "  ".repeat(config.first_line_indent as usize);

        let mut lines = Vec::new();
        let mut line_offsets = Vec::new();
        let mut global_offset = 0;

        for line_with_ending in content.split_inclusive(|c| c == '\n') {
            let paragraph = line_with_ending.trim_end_matches(['\r', '\n']);

            if paragraph.is_empty() {
                lines.push(String::new());
                line_offsets.push((global_offset, global_offset));
                global_offset += line_with_ending.len();
                continue;
            }

            let line_breaks = smart_line_breaks(paragraph, max_line_width, font_size);

            for (i, (start, end)) in line_breaks.iter().enumerate() {
                let line_text = &paragraph[*start..*end];
                let line_start = global_offset + *start;
                let line_end = global_offset + *end;

                if i == 0 {
                    // ✅ 优化：使用 reserve 和 push_str 减少分配
                    let mut formatted_line =
                        String::with_capacity(indent_str.len() + line_text.len());
                    formatted_line.push_str(&indent_str);
                    formatted_line.push_str(line_text);
                    lines.push(formatted_line);
                } else {
                    lines.push(line_text.to_string());
                }

                line_offsets.push((line_start, line_end));
            }

            global_offset += line_with_ending.len();
        }

        let elapsed = start_time.elapsed();
        tracing::debug!(
            "分页完成：行数={}, 页数={}, 耗时：{:?}",
            lines.len(),
            lines.len().div_ceil(lines_per_page),
            elapsed
        );

        Self {
            lines,
            current_page: 0,
            lines_per_page,
            line_offsets,
        }
    }

    #[frb(sync)]
    pub fn current_page(&self, chapter_id: i32) -> Option<PageContent> {
        self.get_page(self.current_page, chapter_id)
    }

    #[frb(sync)]
    pub fn get_page(&self, page_index: usize, chapter_id: i32) -> Option<PageContent> {
        if page_index >= self.total_pages() || self.lines.is_empty() {
            return None;
        }

        let start = page_index * self.lines_per_page;
        let end = (start + self.lines_per_page).min(self.lines.len());

        let page_lines = &self.lines[start..end];
        let is_last = end >= self.lines.len();

        Some(PageContent {
            chapter_index: chapter_id,
            page_index: page_index as i32,
            content: page_lines.join("\n"),
            is_last_page: is_last,
        })
    }

    #[frb(sync)]
    pub fn next_page(&mut self, chapter_id: i32) -> Option<PageContent> {
        if self.current_page >= self.total_pages().saturating_sub(1) {
            return None;
        }
        self.current_page += 1;
        self.current_page(chapter_id)
    }

    #[frb(sync)]
    pub fn prev_page(&mut self, chapter_id: i32) -> Option<PageContent> {
        if self.current_page == 0 {
            return None;
        }
        self.current_page -= 1;
        self.current_page(chapter_id)
    }

    #[frb(sync)]
    pub fn seek_to(&mut self, page_index: usize) {
        self.current_page = page_index.min(self.total_pages().saturating_sub(1));
    }

    #[frb(sync)]
    pub fn total_pages(&self) -> usize {
        if self.lines.is_empty() {
            return 0;
        }
        self.lines.len().div_ceil(self.lines_per_page)
    }

    #[frb(sync)]
    pub fn current_page_index(&self) -> usize {
        self.current_page
    }

    #[frb(sync)]
    pub fn progress(&self) -> f32 {
        let total = self.total_pages();
        if total == 0 {
            return 0.0;
        }
        // 更精确的进度计算
        let current_lines = (self.current_page + 1) * self.lines_per_page;
        (current_lines as f32 / self.lines.len() as f32).min(1.0)
    }

    #[frb(sync)]
    pub fn total_lines(&self) -> usize {
        self.lines.len()
    }

    #[frb(sync)]
    pub fn current_line_index(&self) -> usize {
        self.current_page * self.lines_per_page
    }

    #[frb(sync)]
    pub fn get_page_offsets(&self) -> Vec<PageOffset> {
        let mut offsets = Vec::with_capacity(self.total_pages());

        for page_idx in 0..self.total_pages() {
            let start_line = page_idx * self.lines_per_page;
            let end_line = (start_line + self.lines_per_page).min(self.lines.len());

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
                offset: page_start as i64,
                length: (page_end - page_start) as i64,
            });
        }

        offsets
    }
}

#[frb(sync)]
pub fn paginate_all(content: String, chapter_id: i32, config: TypesetConfig) -> Vec<PageContent> {
    let streamer = PageStreamer::new(content, config);
    let total = streamer.total_pages();
    let mut pages = Vec::with_capacity(total);

    for i in 0..total {
        if let Some(page) = streamer.get_page(i, chapter_id) {
            pages.push(page);
        }
    }
    pages
}
