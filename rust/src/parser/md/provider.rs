//! Markdown 按需内容提供器
//!
//! `MdContentProvider` 基于预计算的块级偏移表实现按需文本范围读取。
//! 打开时单次 O(n) 扫描记录块边界，读取时仅转换请求范围的文本。

use comrak::options::{Extension, ListStyleType, Parse, Plugins, Render};
use comrak::{Arena, Options, format_html_with_plugins, parse_document};
use std::sync::LazyLock;
use regex::Regex;

use crate::domain::AppError;
use crate::parser::provider::ChapterContentProvider;
use crate::storage::models::BookFormat;

/// 块级元素的字节范围
#[derive(Debug, Clone, Copy)]
struct BlockRange {
    start: u64,
    end: u64,
}

/// MD 文件按需内容提供器
pub struct MdContentProvider {
    raw_content: String,
    block_offsets: Vec<BlockRange>,
    code_block_regions: Vec<BlockRange>,
}

// ==================== 懒编译正则 ====================

/// 匹配 Markdown 图片语法：![alt](url)
static RE_IMAGE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"!\[([^\]]*)\]\([^)]*\)").unwrap());
/// 匹配 Markdown 链接语法：[text](url)
static RE_LINK: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\[([^\]]*)\]\([^)]*\)").unwrap());
/// 匹配加粗/斜体标记：*text* / **text** / ***text***
static RE_BOLD_ITALIC: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\*{1,3}([^*]+)\*{1,3}").unwrap());
/// 匹配下划线标记：__text__
static RE_UNDERLINE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"__([^_]+)__").unwrap());
/// 匹配行内代码标记：`code`
static RE_INLINE_CODE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"`([^`]+)`").unwrap());
/// 匹配删除线标记：~~text~~
static RE_STRIKETHROUGH: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"~~([^~]+)~~").unwrap());

impl MdContentProvider {
    /// 创建新的 MD 内容提供器
    ///
    /// 执行单次 O(n) 扫描，预计算文本块边界和代码块区域。
    ///
    /// # 参数
    ///
    /// * `content` - 完整的 Markdown 文件内容
    pub fn new(content: String) -> Self {
        let (block_offsets, code_block_regions) = Self::scan_blocks(&content);

        Self {
            raw_content: content,
            block_offsets,
            code_block_regions,
        }
    }

    /// 单次 O(n) 扫描 MD 内容，提取块边界和代码块区域
    fn scan_blocks(content: &str) -> (Vec<BlockRange>, Vec<BlockRange>) {
        let mut block_boundaries: Vec<u64> = Vec::new();
        let mut code_block_regions: Vec<BlockRange> = Vec::new();
        let mut in_code_block = false;
        let mut code_block_start: u64 = 0;
        let mut prev_line_blank = false;

        block_boundaries.push(0);

        // 跳过 YAML frontmatter
        let body_start = if content.trim().starts_with("---") {
            if let Some(pos) = content[3..].find("\n---") {
                let end = 3 + pos + 5;
                block_boundaries.push(end as u64);
                end
            } else {
                0
            }
        } else {
            0
        };

        let bytes = content.as_bytes();
        let mut byte_pos = body_start;
        let len = content.len();

        while byte_pos < len {
            let line_start = byte_pos;
            while byte_pos < len && bytes[byte_pos] != b'\n' {
                byte_pos += 1;
            }
            let line_end = if byte_pos < len {
                byte_pos + 1
            } else {
                byte_pos
            };
            if byte_pos < len {
                byte_pos += 1;
            }

            let line = &content[line_start..line_end].trim();

            // 代码围栏
            if (line.starts_with("```") || line.starts_with("~~~")) && line.len() >= 3 {
                if in_code_block {
                    block_boundaries.push(line_end as u64);
                    code_block_regions.push(BlockRange {
                        start: code_block_start,
                        end: line_end as u64,
                    });
                    in_code_block = false;
                } else {
                    block_boundaries.push(line_start as u64);
                    code_block_start = line_start as u64;
                    in_code_block = true;
                }
                prev_line_blank = false;
                continue;
            }

            if in_code_block {
                prev_line_blank = false;
                continue;
            }

            // 标题
            if line.starts_with('#') {
                block_boundaries.push(line_start as u64);
                prev_line_blank = false;
                continue;
            }

            // 主题分割线
            let trimmed = line.trim();
            if (trimmed == "---" || trimmed == "***" || trimmed == "___")
                && trimmed.chars().all(|c| c == '-' || c == '*' || c == '_')
            {
                block_boundaries.push(line_start as u64);
                prev_line_blank = false;
                continue;
            }

            // 空行→块间隔
            if line.is_empty() {
                if !prev_line_blank {
                    block_boundaries.push(line_end as u64);
                }
                prev_line_blank = true;
                continue;
            }

            prev_line_blank = false;
        }

        block_boundaries.push(len as u64);

        block_boundaries.sort();
        block_boundaries.dedup();

        let mut blocks = Vec::with_capacity(block_boundaries.len().saturating_sub(1));
        for i in 0..block_boundaries.len().saturating_sub(1) {
            let start = block_boundaries[i];
            let end = block_boundaries[i + 1];
            if end > start {
                blocks.push(BlockRange { start, end });
            }
        }

        (blocks, code_block_regions)
    }

    /// 将对齐到最近块边界
    fn align_to_block_bounds(&self, start: u64, end: u64) -> (usize, usize) {
        for region in &self.code_block_regions {
            if start >= region.start && start < region.end {
                let aligned_start = region.start as usize;
                let len = self.raw_content.len();
                let aligned_end = (end as usize).min(len);
                return (aligned_start, aligned_end);
            }
        }

        let len = self.raw_content.len();

        let s_idx = self
            .block_offsets
            .partition_point(|b| b.end <= start)
            .min(self.block_offsets.len().saturating_sub(1));
        let e_idx = self
            .block_offsets
            .partition_point(|b| b.start <= end)
            .max(s_idx + 1)
            .min(self.block_offsets.len());

        let aligned_start = self.block_offsets[s_idx].start as usize;
        let aligned_end = self.block_offsets[e_idx - 1]
            .end
            .min(len as u64)
            .max(aligned_start as u64 + 1) as usize;

        (aligned_start.min(len), aligned_end.min(len))
    }

    fn md_to_plain_text(text: &str) -> String {
        text.lines()
            .map(|line| {
                let mut result = line.to_string();

                if let Some(stripped) = result.strip_prefix('#') {
                    let level = stripped.chars().take_while(|&c| c == '#').count() + 1;
                    result = stripped[level..].trim().to_string();
                }

                if result.starts_with('>') {
                    result = result[1..].trim().to_string();
                }

                if result.starts_with("- ") || result.starts_with("* ") || result.starts_with("+ ")
                {
                    result = result[2..].to_string();
                }

                if let Some(rest) = result
                    .strip_prefix(|c: char| c.is_ascii_digit())
                    .and_then(|s| s.strip_prefix(". "))
                {
                    result = rest.to_string();
                }

                if result.starts_with("```") || result.starts_with("~~~") {
                    return String::new();
                }

                result = RE_IMAGE.replace_all(&result, "$1").to_string();
                result = RE_LINK.replace_all(&result, "$1").to_string();
                result = RE_BOLD_ITALIC.replace_all(&result, "$1").to_string();
                result = RE_UNDERLINE.replace_all(&result, "$1").to_string();
                result = RE_INLINE_CODE.replace_all(&result, "$1").to_string();
                result = RE_STRIKETHROUGH.replace_all(&result, "$1").to_string();

                result
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

impl ChapterContentProvider for MdContentProvider {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError> {
        let len = self.raw_content.len();
        let start = (start as usize).min(len);
        let end = (end as usize).min(len);

        if start >= end {
            return Ok(String::new());
        }

        let (aligned_start, aligned_end) = self.align_to_block_bounds(start as u64, end as u64);
        let slice = &self.raw_content[aligned_start..aligned_end];

        Ok(Self::md_to_plain_text(slice))
    }

    fn content_length(&self) -> u64 {
        self.raw_content.len() as u64
    }

    fn format(&self) -> BookFormat {
        BookFormat::Md
    }

    fn supports_chunked_pagination(&self) -> bool {
        true
    }

    fn read_html_range(&self, start: u64, end: u64) -> Option<Result<String, AppError>> {
        let len = self.raw_content.len();
        let start = (start as usize).min(len);
        let end = (end as usize).min(len);

        if start >= end {
            return Some(Ok(String::new()));
        }

        let (aligned_start, aligned_end) = self.align_to_block_bounds(start as u64, end as u64);
        let slice = &self.raw_content[aligned_start..aligned_end];

        Some(Ok(markdown_slice_to_html(slice)))
    }
}

fn markdown_slice_to_html(text: &str) -> String {
    let arena = Arena::new();
    let options = Options {
        render: Render {
            github_pre_lang: true,
            full_info_string: true,
            list_style: ListStyleType::Dash,
            ..Default::default()
        },
        extension: Extension {
            strikethrough: true,
            tagfilter: true,
            table: true,
            autolink: true,
            tasklist: true,
            superscript: true,
            header_id_prefix: None,
            footnotes: true,
            description_lists: true,
            front_matter_delimiter: None,
            multiline_block_quotes: true,
            math_dollars: false,
            math_code: false,
            ..Default::default()
        },
        parse: Parse {
            smart: true,
            default_info_string: None,
            relaxed_tasklist_matching: true,
            broken_link_callback: None,
            relaxed_autolinks: false,
            escaped_char_spans: false,
            ignore_setext: false,
            leave_footnote_definitions: false,
            sourcepos_chars: false,
            tasklist_in_table: false,
        },
        ..Default::default()
    };

    let root = parse_document(&arena, text, &options);
    let mut html = String::new();
    format_html_with_plugins(root, &options, &mut html, &Plugins::default()).ok();
    html
}
