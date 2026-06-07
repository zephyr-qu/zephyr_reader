//! 英语词库
//! 加载 CET4、CET6、IELTS、TOEFL 词表，提供词汇查询和枚举功能

use std::{collections::HashSet, sync::LazyLock};

/// 大学英语四级词表
static CET4: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/cet4.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("cet4.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

/// 大学英语六级词表
static CET6: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/cet6.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("cet6.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

/// 雅思词表
static IELTS: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/ielts.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("ielts.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

/// 托福词表
static TOEFL: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/toefl.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("toefl.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

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
