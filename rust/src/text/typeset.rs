//! 文本排版处理
//! 包含中英文混排优化、标点避首避尾、段落处理




/// 优化标点符号（避首避尾）
///
/// 单次遍历 O(n)，预分配容量避免重新分配。
pub(crate) fn optimize_punctuation(text: &str, language: &str) -> String {
    let is_zh_or_mix = matches!(language, "zh" | "mix" | "auto");
    let is_en_or_mix = matches!(language, "en" | "mix" | "auto");

    if !is_zh_or_mix && !is_en_or_mix {
        return text.to_string();
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
        return text.to_string();
    }
    result
}

/// 优化空格
pub(crate) fn optimize_spaces(text: &str, _language: &str) -> String {
    let mut result = text.to_string();

    // 移除多余空格（连续空白合并为单个空格）
    result = remove_extra_spaces(&result);

    result
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
