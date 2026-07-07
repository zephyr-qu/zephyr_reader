//! 行级断行计算
//!
//! 提供给定最大宽度的标点优化行分割函数，被 `BlockPaginator` 调用。

use crate::text::char_width::CharWidthTable;
use crate::text::constants::{
    is_cjk_char, is_cjk_punctuation, is_end_avoid_punctuation, is_start_avoid_punctuation,
};

/// 使用预计算的 char_indices 计算行分割
#[cfg(test)]
pub(crate) fn compute_line_breaks_from_indices(
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

        // 避尾标点：行尾不应出现开括号等 end-avoid 字符，推到下一行
        while end > start + 1 {
            let last_char = para_char_indices[end - 1].1;
            if is_end_avoid_punctuation(last_char) {
                end -= 1;
            } else {
                break;
            }
        }

        // 避头标点：行首不应出现逗号、句号等 start-avoid 字符，回拉一个字符
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

/// 首行与续行使用不同行宽（首行缩进仅作用于段首行）。
pub(crate) fn compute_line_breaks_variable_width(
    para_char_indices: &[(usize, char)],
    para_start: usize,
    para_end: usize,
    first_line_max_width_px: Option<f32>,
    continuation_max_width_px: f32,
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
        let max_width_px = if start == 0 {
            first_line_max_width_px.unwrap_or(continuation_max_width_px)
        } else {
            continuation_max_width_px
        };

        let mut current_width = 0.0;
        let mut end = start;

        for offset in 0..(char_count - start) {
            let (_, ch) = para_char_indices[start + offset];
            let mut char_width = width_table.char_width(ch) + letter_spacing_px;
            if punctuation_squeeze && offset > 0 {
                let prev_ch = para_char_indices[start + offset - 1].1;
                let prev_is_punct = is_cjk_punctuation(prev_ch);
                let curr_is_punct = is_cjk_punctuation(ch);
                if prev_is_punct && curr_is_punct {
                    char_width *= 0.65;
                }
            }

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

        while end > start + 1 {
            let last_char = para_char_indices[end - 1].1;
            if is_end_avoid_punctuation(last_char) {
                end -= 1;
            } else {
                break;
            }
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
mod tests {
    
    

    #[test]
    fn test_line_breaks_end_avoid_direct() {
        // 直接测试 compute_line_breaks_from_indices 的避尾逻辑
        use crate::text::char_width::CharWidthTable;

        // 文本中开括号（《是避尾标点，不应出现在行尾
        let text = "你好世界（《重要内容》更多文字继续写下去还有内容";
        let char_indices: Vec<(usize, char)> = text.char_indices().collect();
        let width_table = CharWidthTable::from_calibration(&Default::default());

        // 合理行宽：每行约6-7个CJK字符（~120px）
        let max_width = 120.0;
        let line_breaks = compute_line_breaks_from_indices(
            &char_indices,
            0,
            text.len(),
            max_width,
            &width_table,
            0.0,
            0.0,
            false,
        );

        // 验证没有多字符行以避尾标点结尾
        for (start, end) in &line_breaks {
            let line_text = &text[*start..*end];
            let char_count = line_text.chars().count();
            if char_count > 1 {
                let last_char = line_text.chars().last().unwrap();
                assert!(
                    !crate::text::constants::is_end_avoid_punctuation(last_char),
                    "line (len={}) should not end with end-avoid '{}': {:?}",
                    char_count,
                    last_char,
                    line_text,
                );
            }
        }

        // 验证避头逻辑：没有行以避头标点开头（段落首行除外）
        for (i, (start, end)) in line_breaks.iter().enumerate() {
            if *end > *start && i > 0 {
                let first_char = text[*start..*end].chars().next().unwrap();
                assert!(
                    !crate::text::constants::is_start_avoid_punctuation(first_char),
                    "line should not start with start-avoid '{}': {:?}",
                    first_char,
                    &text[*start..*end],
                );
            }
        }
    }
}
