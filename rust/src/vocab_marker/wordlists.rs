use std::{collections::HashSet, sync::LazyLock};

static CET4: LazyLock<HashSet<String>> = LazyLock::new(|| {
    let json = include_str!("../../../assets/wordlists/cet4.json");
    serde_json::from_str::<Vec<String>>(json)
        .expect("cet4.json must be valid JSON array of strings")
        .into_iter()
        .collect()
});

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
    CET4.iter()
        .chain(CET6.iter())
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

pub fn cet4_words() -> Vec<String> {
    CET4.iter().cloned().collect()
}

pub fn cet6_words() -> Vec<String> {
    CET6.iter().cloned().collect()
}

pub fn ielts_words() -> Vec<String> {
    IELTS.iter().cloned().collect()
}

pub fn toefl_words() -> Vec<String> {
    TOEFL.iter().cloned().collect()
}
