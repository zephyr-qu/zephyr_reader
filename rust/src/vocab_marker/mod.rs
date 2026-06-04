pub mod wordlists;

use std::sync::LazyLock;

use regex::Regex;

/// A vocabulary word match found in text.
pub struct VocabularyMatch {
    pub word: String,
    pub start: usize,
    pub end: usize,
}

pub static VOCAB_MATCH: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[a-zA-Z]+(?:'[a-zA-Z]+)?").expect("static regex is valid"));

/// Scan text for vocabulary words from all built-in word lists (CET6, IELTS, TOEFL).
/// Returns all matches with their positions.
///
/// The regex matches English words including contractions (e.g. "don't", "it's").
/// Matching is case-insensitive.
pub fn scan_for_vocabulary(text: &str) -> Vec<VocabularyMatch> {
    VOCAB_MATCH.find_iter(text)
        .filter(|m| wordlists::contains(&text[m.start()..m.end()]))
        .map(|m| VocabularyMatch {
            word: text[m.start()..m.end()].to_string(),
            start: m.start(),
            end: m.end(),
        })
        .collect()
}
