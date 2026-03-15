//! 字符串工具函数

use std::borrow::Cow;

/// 截断字符串到指定长度（按字符）
pub fn truncate_string(s: &str, max_len: usize) -> Cow<'_, str> {
    if s.chars().count() <= max_len {
        Cow::Borrowed(s)
    } else {
        Cow::Owned(s.chars().take(max_len).collect())
    }
}

/// 截断字符串并添加省略号
pub fn truncate_with_ellipsis(s: &str, max_len: usize) -> String {
    if s.chars().count() <= max_len {
        s.to_string()
    } else {
        let mut result: String = s.chars().take(max_len - 1).collect();
        result.push('…');
        result
    }
}

/// 移除字符串两端的空白字符
pub fn trim_string(s: &str) -> &str {
    s.trim()
}

/// 移除所有空白字符
pub fn remove_whitespace(s: &str) -> String {
    s.chars().filter(|c| !c.is_whitespace()).collect()
}

/// 将字符串转换为安全的文件名
pub fn to_safe_filename(s: &str) -> String {
    s.chars()
        .map(|c| {
            if c.is_alphanumeric() || c == '-' || c == '_' || c == '.' {
                c
            } else {
                '_'
            }
        })
        .collect()
}

/// 清理文本中的非法字符
pub fn sanitize_text(s: &str) -> String {
    s.chars()
        .filter(|c| {
            // 保留可见字符和常见空白字符
            !c.is_control() || *c == '\n' || *c == '\r' || *c == '\t'
        })
        .collect()
}

/// 标准化换行符
pub fn normalize_line_endings(s: &str) -> String {
    s.replace("\r\n", "\n").replace("\r", "\n")
}

/// 移除空行
pub fn remove_empty_lines(s: &str) -> String {
    s.lines()
        .filter(|line| !line.trim().is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

/// 压缩多个空行为单个空行
pub fn compress_empty_lines(s: &str, max_consecutive: usize) -> String {
    let mut result = String::new();
    let mut empty_count = 0;

    for line in s.lines() {
        if line.trim().is_empty() {
            empty_count += 1;
            if empty_count <= max_consecutive {
                if !result.is_empty() {
                    result.push('\n');
                }
                result.push_str(line);
            }
        } else {
            empty_count = 0;
            if !result.is_empty() {
                result.push('\n');
            }
            result.push_str(line);
        }
    }

    result
}

/// 计算字符串的显示宽度（中文算 1，英文算 1）
pub fn display_width(s: &str) -> usize {
    s.chars().count()
}

/// 判断字符串是否主要为中文
pub fn is_mostly_chinese(s: &str) -> bool {
    let total = s.chars().count();
    if total == 0 {
        return false;
    }

    let chinese_count = s
        .chars()
        .filter(|c| {
            let cp = *c as u32;
            (0x4E00..=0x9FFF).contains(&cp)
                || (0x3400..=0x4DBF).contains(&cp)
                || (0xF900..=0xFAFF).contains(&cp)
        })
        .count();

    chinese_count as f32 / total as f32 > 0.5
}

/// 提取字符串中的数字
pub fn extract_numbers(s: &str) -> Vec<i32> {
    let mut numbers = Vec::new();
    let mut current_number = String::new();

    for c in s.chars() {
        if c.is_ascii_digit() {
            current_number.push(c);
        } else if !current_number.is_empty() {
            if let Ok(num) = current_number.parse::<i32>() {
                numbers.push(num);
            }
            current_number.clear();
        }
    }

    if !current_number.is_empty() {
        if let Ok(num) = current_number.parse::<i32>() {
            numbers.push(num);
        }
    }

    numbers
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_truncate_string() {
        assert_eq!(truncate_string("Hello 世界", 5), "Hello");
        assert_eq!(truncate_string("Hello", 10), "Hello");
    }

    #[test]
    fn test_truncate_with_ellipsis() {
        assert_eq!(truncate_with_ellipsis("Hello World", 5), "Hell…");
        assert_eq!(truncate_with_ellipsis("Hi", 5), "Hi");
    }

    #[test]
    fn test_to_safe_filename() {
        assert_eq!(to_safe_filename("Hello/World?.txt"), "Hello_World_.txt");
    }

    #[test]
    fn test_normalize_line_endings() {
        assert_eq!(
            normalize_line_endings("Line1\r\nLine2\rLine3"),
            "Line1\nLine2\nLine3"
        );
    }

    #[test]
    fn test_is_mostly_chinese() {
        assert!(is_mostly_chinese("这是中文"));
        assert!(!is_mostly_chinese("This is English"));
    }
}
