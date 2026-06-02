//! FRB wrapper for vocabulary word scanning.

use crate::{
    domain::AppError,
    vocab_marker::{self as engine},
};
use flutter_rust_bridge::frb;

/// A vocabulary word match found in text.
#[frb]
pub struct VocabMatch {
    pub word: String,
    pub start: i64,
    pub end: i64,
}

/// Scan text for vocabulary words from all built-in word lists (CET6, IELTS, TOEFL).
/// Returns all matches with their positions.
#[frb(sync)]
pub fn scan_for_vocabulary(text: &str) -> Result<Vec<VocabMatch>, AppError> {
    Ok(engine::scan_for_vocabulary(text)
        .into_iter()
        .map(|m| VocabMatch {
            word: m.word,
            start: m.start as i64,
            end: m.end as i64,
        })
        .collect())
}

/// Return all vocabulary words from all built-in word lists as a flat list.
/// This is used for one-time initialization of the Dart-side word set.
#[frb(sync)]
pub fn get_all_vocabulary_words() -> Result<Vec<String>, AppError> {
    Ok(engine::wordlists::all_words())
}
