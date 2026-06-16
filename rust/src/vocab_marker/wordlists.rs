//! 英语词库
//! 加载 CET4、CET6、IELTS、TOEFL 词表，提供词汇查询和枚举功能

use std::{collections::HashSet, sync::LazyLock};

macro_rules! load_wordlist {
    ($name:ident, $file:literal) => {
        static $name: LazyLock<HashSet<String>> = LazyLock::new(|| {
            let json = include_str!(concat!("../../../assets/wordlists/", $file));
            serde_json::from_str::<Vec<String>>(json)
                .expect(concat!($file, " must be valid JSON array of strings"))
                .into_iter()
                .collect()
        });
    };
}

// 大学英语四级词表
load_wordlist!(CET4, "cet4.json");
// 大学英语六级词表
load_wordlist!(CET6, "cet6.json");
// 雅思词表
load_wordlist!(IELTS, "ielts.json");
// 托福词表
load_wordlist!(TOEFL, "toefl.json");

/// 所有词表的合并集合（统一转为小写）
static ALL: LazyLock<HashSet<String>> = LazyLock::new(|| {
    CET4.iter()
        .chain(CET6.iter())
        .chain(IELTS.iter())
        .chain(TOEFL.iter())
        .map(|s| s.to_lowercase())
        .collect()
});

/// 查询单词是否在词表中（大小写不敏感）
pub fn contains(word: &str) -> bool {
    ALL.contains(&word.to_lowercase())
}

/// 返回词表中的单词总数
pub fn total_words() -> usize {
    ALL.len()
}

/// 返回所有词表中的单词列表
pub fn all_words() -> Vec<String> {
    ALL.iter().cloned().collect()
}

/// 返回四级词表中的单词列表
pub fn cet4_words() -> Vec<String> {
    CET4.iter().cloned().collect()
}

/// 返回六级词表中的单词列表
pub fn cet6_words() -> Vec<String> {
    CET6.iter().cloned().collect()
}

/// 返回雅思词表中的单词列表
pub fn ielts_words() -> Vec<String> {
    IELTS.iter().cloned().collect()
}

/// 返回托福词表中的单词列表
pub fn toefl_words() -> Vec<String> {
    TOEFL.iter().cloned().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_contains_known_word() {
        assert!(contains("abandon"));
        assert!(contains("ability"));
    }

    #[test]
    fn test_contains_unknown_word() {
        assert!(!contains("xyzqwertyabc"));
        assert!(!contains(""));
    }

    #[test]
    fn test_contains_case_insensitive() {
        assert!(contains("Abandon"));
        assert!(contains("ABANDON"));
        assert!(contains("AbAnDoN"));
    }

    #[test]
    fn test_contains_punctuation_not_found() {
        assert!(!contains("abandon!"));
        assert!(!contains("ability."));
    }

    #[test]
    fn test_total_words_positive() {
        let total = total_words();
        assert!(total > 0, "total_words should be non-zero");
    }

    #[test]
    fn test_all_words_contains_known() {
        let all = all_words();
        assert!(all.iter().any(|w| w == "abandon"));
        assert!(all.len() >= total_words());
    }

    #[test]
    fn test_subset_word_counts() {
        assert!(!cet4_words().is_empty());
        assert!(!cet6_words().is_empty());
        assert!(!ielts_words().is_empty());
        assert!(!toefl_words().is_empty());
        let total = total_words();
        assert!(
            cet4_words().len() + cet6_words().len() + ielts_words().len() + toefl_words().len()
                >= total,
            "individual subsets should sum to at least total"
        );
    }
}
