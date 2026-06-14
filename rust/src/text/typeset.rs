//! 文本排版处理
//! 包含中英文混排优化、标点避首避尾、段落处理

use std::borrow::Cow;



/// 优化标点符号（避首避尾）
///
/// 单次遍历 O(n)，预分配容量避免重新分配。
/// 若无修改则返回 Cow::Borrowed 避免不必要的克隆。
pub(crate) fn optimize_punctuation<'a>(text: &'a str, language: &str) -> Cow<'a, str> {
    let is_zh_or_mix = matches!(language, "zh" | "mix" | "auto");
    let is_en_or_mix = matches!(language, "en" | "mix" | "auto");

    if !is_zh_or_mix && !is_en_or_mix {
        return Cow::Borrowed(text);
    }

    let mut result = String::with_capacity(text.len() + 32);
    let chars: Vec<char> = text.chars().collect();
    let mut modified = false;
    let mut i = 0;

    while i < chars.len() {
        let c = chars[i];
        if c == '\n' && i + 1 < chars.len() {
            let next = chars[i + 1];
            if is_zh_or_mix && crate::text::constants::is_start_avoid_punctuation(next) {
                result.push('\n');
                result.push(' ');
                i += 1;
                modified = true;
                continue;
            }
        }
        if is_zh_or_mix
            && crate::text::constants::is_end_avoid_punctuation(c)
            && i + 1 < chars.len()
            && chars[i + 1] == '\n'
        {
            result.push(c);
            result.push(' ');
            i += 1;
            modified = true;
            continue;
        }
        if i + 2 < chars.len() && is_en_or_mix {
            if c == '.' && chars[i + 1] == '.' && chars[i + 2] == '.' {
                result.push('…');
                i += 3;
                modified = true;
                continue;
            }
            if c == '-' && chars[i + 1] == '-' {
                result.push('—');
                i += 2;
                modified = true;
                continue;
            }
        }
        result.push(c);
        i += 1;
    }

    if !modified {
        return Cow::Borrowed(text);
    }
    Cow::Owned(result)
}

/// 优化空格
pub(crate) fn optimize_spaces<'a>(text: &'a str, _language: &str) -> Cow<'a, str> {
    // 快速检查：是否有连续空白、前导或尾随空白
    let mut prev_space = false;
    let mut in_leading = true;
    for c in text.chars() {
        if c.is_whitespace() {
            if in_leading || prev_space {
                // 需要压缩空格
                return Cow::Owned(remove_extra_spaces(text));
            }
            prev_space = true;
        } else {
            prev_space = false;
            in_leading = false;
        }
    }
    // 尾随空白检查
    if prev_space || in_leading {
        return Cow::Owned(remove_extra_spaces(text));
    }
    Cow::Borrowed(text)
}

/// 移除多余空格（连续空白合并为单个空格，并去除首尾空白）
fn remove_extra_spaces(text: &str) -> String {
    let mut result = String::new();
    let mut prev_space = false;

    for c in text.chars() {
        if c.is_whitespace() {
            if !prev_space {
                result.push(' ');
                prev_space = true;
            }
        } else {
            result.push(c);
            prev_space = false;
        }
    }

    result.trim().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;


    #[test]
    fn test_remove_extra_spaces() {
        let result = remove_extra_spaces("  a   b  ");
        assert_eq!(result, "a b");
    }

    #[test]
    fn test_optimize_spaces_noop_on_clean_text() {
        let result = optimize_spaces("这是Chinese文本", "auto");
        // optimize_spaces 不再插入空格，只合并多余空白
        assert_eq!(result, "这是Chinese文本");
    }
}
