//! 内容分页流
//! 将解析后的内容分页输出，支持基于像素宽度的精确定位

use crate::ffi::{PageContent, PageOffset, TypesetConfig};
use flutter_rust_bridge::frb;

/// 计算单个字符的像素宽度
/// - 中文字符：1.0 倍字体大小
/// - 英文/数字：0.6 倍字体大小
/// - 标点符号：0.6 倍字体大小（半角）或 1.0 倍（全角）
fn char_pixel_width(c: char, font_size: f32) -> f32 {
    let cp = c as u32;

    // 中文字符（CJK Unified Ideographs）
    if (0x4E00..=0x9FFF).contains(&cp)
        || (0x3400..=0x4DBF).contains(&cp)
        || (0xF900..=0xFAFF).contains(&cp)
    {
        font_size
    }
    // 全角标点（CJK 标点符号区）
    else if (0x3000..=0x303F).contains(&cp) {
        font_size
    }
    // 英文、数字、半角标点（ASCII 可打印字符）
    else if c.is_ascii_graphic() || c.is_ascii_whitespace() {
        font_size * 0.6
    }
    // 其他字符（默认按中文处理）
    else {
        font_size * 0.8
    }
}

/// 基于像素宽度的智能断行
/// 返回每行的起始和结束字符索引
fn smart_line_breaks(text: &str, max_width_px: f32, font_size: f32) -> Vec<(usize, usize)> {
    let mut lines = Vec::new();
    let chars: Vec<char> = text.chars().collect();
    let mut start = 0;

    while start < chars.len() {
        let mut current_width = 0.0;
        let mut end = start;

        // 尝试放入更多字符
        for i in start..chars.len() {
            let char_width = char_pixel_width(chars[i], font_size);

            if current_width + char_width <= max_width_px {
                current_width += char_width;
                end = i + 1;
            } else {
                // 当前行已满
                break;
            }
        }

        // 如果一行都放不下，至少放一个字符
        if end == start {
            end = start + 1;
        }

        // 检查是否需要避首标点
        if end < chars.len() {
            let next_char = chars[end];
            if is_start_avoid_punctuation(next_char) && end > start {
                // 将标点移到下一行开头
                end -= 1;
            }
        }

        lines.push((start, end));
        start = end;
    }

    lines
}

/// 判断是否为避首标点（不应出现在行首）
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

/// 分页器（基于像素宽度）
///
/// 支持克隆，便于在 Flutter 侧传递和保存状态
#[frb]
#[derive(Clone)]
pub struct PageStreamer {
    pub lines: Vec<String>, // 已断行的所有行
    pub current_page: usize,
    pub lines_per_page: usize,
    /// 每行的字符偏移量（在原始内容中的起始和结束位置）
    #[frb]
    pub line_offsets: Vec<(usize, usize)>,
}

#[frb]
impl PageStreamer {
    /// 创建分页器（基于像素宽度精确计算）
    #[frb(sync)]
    pub fn new(content: String, config: TypesetConfig) -> Self {
        let start_time = std::time::Instant::now();
        let content_len = content.len();
        tracing::debug!("开始分页处理，字符数：{}", content_len);

        let font_size = config.font_size as f32;
        let line_spacing = config.line_spacing;
        let page_height_px = config.page_height as f32;
        let page_width_px = config.page_width as f32;

        // 计算每页最大行数（考虑行间距）
        let line_height = font_size * line_spacing;
        let lines_per_page = ((page_height_px / line_height) as usize).max(5);

        // 计算最大行宽（减去首行缩进）
        let indent_width = font_size * config.first_line_indent as f32;
        let max_line_width = page_width_px - indent_width;

        // 智能断行
        let mut lines = Vec::new();
        let mut line_offsets = Vec::new();
        let mut global_offset = 0; // 在原始内容中的字符偏移
        let mut line_count: usize = 0;

        // 计算换行符长度（处理 \r\n 和 \n 的差异）
        let line_ending_len = if content.contains("\r\n") { 2 } else { 1 };

        for paragraph in content.lines() {
            if paragraph.trim().is_empty() {
                lines.push(String::new());
                line_offsets.push((global_offset, global_offset));
                line_count += 1;
                continue;
            }

            // 处理段落首行缩进
            let indent_str = "  ".repeat(config.first_line_indent as usize);

            // 对段落进行智能断行
            let line_breaks = smart_line_breaks(paragraph, max_line_width, font_size);

            for (i, (start, end)) in line_breaks.iter().enumerate() {
                let line_text = &paragraph[*start..*end];
                // 计算在原始内容中的偏移量
                let line_start = global_offset + *start;
                let line_end = global_offset + *end;

                if i == 0 {
                    // 首行添加缩进
                    lines.push(format!("{}{}", indent_str, line_text));
                } else {
                    lines.push(line_text.to_string());
                }
                line_offsets.push((line_start, line_end));
                line_count += 1;
            }

            // 更新全局偏移（包括换行符）
            global_offset += paragraph.len() + line_ending_len;
        }

        let elapsed = start_time.elapsed();
        tracing::debug!(
            "分页处理完成：总行数={}, 每页行数={}, 预计页数={}, 耗时：{:?}",
            line_count,
            lines_per_page,
            line_count.div_ceil(lines_per_page),
            elapsed
        );

        Self {
            lines,
            current_page: 0,
            lines_per_page,
            line_offsets,
        }
    }

    /// 获取当前页
    #[frb(sync)]
    pub fn current_page(&self, chapter_id: i32) -> Option<PageContent> {
        if self.current_page >= self.total_pages() || self.lines.is_empty() {
            return None;
        }

        let start = self.current_page * self.lines_per_page;
        let end = (start + self.lines_per_page).min(self.lines.len());

        let page_lines = &self.lines[start..end];
        let is_last = end >= self.lines.len();

        Some(PageContent {
            chapter_id,
            page_index: self.current_page as i32,
            content: page_lines.join("\n"),
            is_last_page: is_last,
        })
    }

    /// 获取指定页
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
            chapter_id,
            page_index: page_index as i32,
            content: page_lines.join("\n"),
            is_last_page: is_last,
        })
    }

    /// 下一页
    #[frb(sync)]
    pub fn next_page(&mut self, chapter_id: i32) -> Option<PageContent> {
        if self.current_page >= self.total_pages() - 1 {
            return None;
        }

        self.current_page += 1;
        self.current_page(chapter_id)
    }

    /// 上一页
    #[frb(sync)]
    pub fn prev_page(&mut self, chapter_id: i32) -> Option<PageContent> {
        if self.current_page == 0 {
            return None;
        }

        self.current_page -= 1;
        self.current_page(chapter_id)
    }

    /// 跳转到指定页
    #[frb(sync)]
    pub fn seek_to(&mut self, page_index: usize) {
        self.current_page = page_index.min(self.total_pages().saturating_sub(1));
    }

    /// 总页数
    #[frb(sync)]
    pub fn total_pages(&self) -> usize {
        if self.lines.is_empty() {
            return 0;
        }
        self.lines.len().div_ceil(self.lines_per_page)
    }

    /// 当前页码
    #[frb(sync)]
    pub fn current_page_index(&self) -> usize {
        self.current_page
    }

    /// 获取进度（0.0 - 1.0）
    #[frb(sync)]
    pub fn progress(&self) -> f32 {
        if self.lines.is_empty() || self.total_pages() == 0 {
            return 0.0;
        }

        let current_lines = (self.current_page + 1) * self.lines_per_page;
        (current_lines as f32 / self.lines.len() as f32).min(1.0)
    }

    /// 获取总行数
    #[frb(sync)]
    pub fn total_lines(&self) -> usize {
        self.lines.len()
    }

    /// 获取当前行号
    #[frb(sync)]
    pub fn current_line_index(&self) -> usize {
        self.current_page * self.lines_per_page
    }

    /// 获取所有页面的偏移量信息
    ///
    /// 用于缓存分页结果，实现"秒开"功能。
    /// 返回每个页面的起始字符偏移量和长度。
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

/// 将所有内容分页（基于像素宽度）
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

#[cfg(test)]
mod tests {
    use super::*;

    /// 计算字符串的像素宽度（测试辅助函数）
    #[cfg(test)]
    fn string_pixel_width(s: &str, font_size: f32) -> f32 {
        s.chars().map(|c| char_pixel_width(c, font_size)).sum()
    }

    #[test]
    fn test_string_pixel_width() {
        // 纯中文
        assert_eq!(string_pixel_width("中文", 20.0), 40.0);

        // 纯英文
        assert_eq!(string_pixel_width("abc", 20.0), 36.0);

        // 混合 - 修正期望值：中 (20) + a(12) + 文 (20) = 52，但实际是 76
        // 因为"中 a 文"有空格，实际计算：中 (20) + 空格 (12) + a(12) + 空格 (12) + 文 (20) = 76
        assert_eq!(string_pixel_width("中 a 文", 20.0), 76.0);
    }

    #[test]
    fn test_smart_line_breaks() {
        // 测试短文本（不需要断行）
        let breaks = smart_line_breaks("短文本", 200.0, 20.0);
        assert_eq!(breaks.len(), 1);

        // 测试长文本（需要断行）
        let text = "这是一段很长的中文文本，需要进行智能断行处理";
        let breaks = smart_line_breaks(text, 100.0, 20.0);
        assert!(breaks.len() > 1);
    }

    #[test]
    fn test_page_streamer() {
        let content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8\nLine 9\nLine 10\nLine 11\nLine 12";
        let config = TypesetConfig {
            page_width: 800, // 增加宽度以容纳更多字符
            page_height: 600,
            font_size: 16, // 减小字体以增加每页行数
            line_spacing: 1.5,
            letter_spacing: 0.0,
            paragraph_spacing: 1.0,
            first_line_indent: 2,
            language: crate::ffi::LanguageType::Auto,
            enable_hyphenation: false,
            hyphenation_language: None,
        };

        let streamer = PageStreamer::new(content.to_string(), config);

        // 验证有内容
        assert!(streamer.total_lines() > 0);
        assert!(streamer.total_pages() > 0);

        // 获取第一页
        let page = streamer.get_page(0, 0);
        assert!(page.is_some());
        assert_eq!(page.unwrap().page_index, 0);
    }

    #[test]
    fn test_page_streamer_mixed_text() {
        let content = "这是中文 This is English 混合文本";
        let config = TypesetConfig {
            page_width: 300,
            page_height: 400,
            font_size: 18,
            line_spacing: 1.5,
            letter_spacing: 0.0,
            paragraph_spacing: 1.0,
            first_line_indent: 2,
            language: crate::ffi::LanguageType::Auto,
            ..Default::default()
        };

        let streamer = PageStreamer::new(content.to_string(), config);

        // 验证有内容
        assert!(streamer.total_lines() > 0);
    }
}
