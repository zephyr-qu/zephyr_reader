use std::{collections::HashSet, sync::LazyLock};

static CET6: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/cet6.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("cet6.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

static IELTS: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/ielts.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("ielts.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

static TOEFL: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/toefl.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("toefl.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

static ALL: LazyLock<HashSet<String>> = LazyLock::new(|| {
    CET6.iter()
        .chain(IELTS.iter())
        .chain(TOEFL.iter())
        .map(|s| s.to_lowercase())
        .collect()
});

pub fn contains(word: &str) -> bool {
    ALL.contains(&word.to_lowercase())
}

pub fn total_words() -> usize {
    ALL.len()
}

pub fn all_words() -> Vec<String> {
    ALL.iter().cloned().collect()
}
