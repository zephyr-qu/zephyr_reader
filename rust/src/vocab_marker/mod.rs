pub mod wordlists;

use regex::Regex;

/// A vocabulary word match found in text.
pub struct VocabularyMatch {
    pub word: String,
    pub start: usize,
    pub end: usize,
}

/// Scan text for vocabulary words from all built-in word lists (CET6, IELTS, TOEFL).
/// Returns all matches with their positions.
///
/// The regex matches English words including contractions (e.g. "don't", "it's").
/// Matching is case-insensitive.
pub fn scan_for_vocabulary(text: &str) -> Vec<VocabularyMatch> {
    let re = Regex::new(r"[a-zA-Z]+(?:'[a-zA-Z]+)?").expect("static regex is valid");
    re.find_iter(text)
        .filter(|m| wordlists::contains(&text[m.start()..m.end()]))
        .map(|m| VocabularyMatch {
            word: text[m.start()..m.end()].to_string(),
            start: m.start(),
            end: m.end(),
        })
        .collect()
}
