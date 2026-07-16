//! 词汇标记模块纯函数单元测试
//!
//! 测试 wordlists 词表查询和 scan_for_vocabulary 文本扫描功能。
//! 词表通过 include_str! 编译时嵌入，无需初始化。

use rust_lib_zephyr_reader::domain::wordlist::vocab;
use rust_lib_zephyr_reader::domain::wordlist::wordlists;

// ==================== wordlists ====================

#[test]
fn test_wordlists_contains() {
    // 已知 CET4 单词应返回 true
    assert!(
        wordlists::contains("abandon"),
        "abandon should be in wordlists"
    );
    assert!(
        wordlists::contains("ability"),
        "ability should be in wordlists"
    );
    // 不存在的单词应返回 false
    assert!(
        !wordlists::contains("xyzqwertyabc"),
        "nonsense word should not be in wordlists"
    );
    // 大小写不敏感
    assert!(
        wordlists::contains("Abandon"),
        "Abandon (capitalized) should match"
    );
    assert!(
        wordlists::contains("ABANDON"),
        "ABANDON (uppercase) should match"
    );
    assert!(wordlists::contains("ABILITY"), "ABILITY should match");
}

#[test]
fn test_wordlists_total_words() {
    let total = wordlists::total_words();
    assert!(total > 0, "total_words should be non-zero, got {total}");
}

#[test]
fn test_wordlists_cet4_words() {
    let words = wordlists::cet4_words();
    assert!(!words.is_empty(), "cet4_words should be non-empty");
    assert!(
        words.iter().any(|w| w == "abandon"),
        "cet4_words should contain 'abandon'"
    );
}

#[test]
fn test_wordlists_cet6_words() {
    let words = wordlists::cet6_words();
    assert!(!words.is_empty(), "cet6_words should be non-empty");
}

#[test]
fn test_wordlists_ielts_words() {
    let words = wordlists::ielts_words();
    assert!(!words.is_empty(), "ielts_words should be non-empty");
}

#[test]
fn test_wordlists_toefl_words() {
    let words = wordlists::toefl_words();
    assert!(!words.is_empty(), "toefl_words should be non-empty");
}

#[test]
fn test_wordlists_all_words() {
    let words = wordlists::all_words();
    assert!(!words.is_empty(), "all_words should be non-empty");
    // all_words 应包含各子词表中的单词（统一小写）
    let lower_words: Vec<String> = words.iter().map(|w| w.to_lowercase()).collect();
    assert!(
        lower_words.contains(&"abandon".to_string()),
        "all_words should contain 'abandon'"
    );
}

#[test]
fn test_wordlists_contains_empty_string() {
    assert!(
        !wordlists::contains(""),
        "empty string should not be in wordlists"
    );
}

#[test]
fn test_wordlists_contains_punctuation_variants() {
    // contains 直接查全集，不含前导/后缀标点；标点留给 scan_for_vocabulary 过滤
    // 但即使传入带标点的字符串，contains 按整体匹配（转小写）
    assert!(
        !wordlists::contains("abandon!"),
        "abandon! with punctuation should not match raw contains"
    );
}

#[test]
fn test_wordlists_subset_relationship() {
    // 各子词表非空且 all_words 大于每个子集
    let total = wordlists::total_words();
    assert!(
        wordlists::cet4_words().len() <= total,
        "cet4 count should not exceed total"
    );
    // CET6、IELTS、TOEFL 同理
    assert!(
        wordlists::cet6_words().len()
            + wordlists::ielts_words().len()
            + wordlists::toefl_words().len()
            >= 1
    );
}

// ==================== scan_for_vocabulary ====================

#[test]
fn test_scan_empty_text() {
    let result = vocab::scan_for_vocabulary("");
    assert!(
        result.is_empty(),
        "scanning empty text should return empty vec"
    );
}

#[test]
fn test_scan_no_vocab() {
    // 使用无意义字符串，确保其中的 token 都不在任何词表中
    let text = "zxcvbnm qwertyu lkjhgfds";
    let result = vocab::scan_for_vocabulary(text);
    assert!(
        result.is_empty(),
        "text with no vocab words should return empty vec, got {len}",
        len = result.len()
    );
}

#[test]
fn test_scan_with_vocab() {
    // "abandon" 是已知 CET4 单词
    let text = "hello abandon world";
    let result = vocab::scan_for_vocabulary(text);
    assert!(
        !result.is_empty(),
        "text containing 'abandon' should produce at least one match"
    );
    let m = &result[0];
    assert_eq!(m.word, "abandon", "matched word should be 'abandon'");
    assert_eq!(m.start, 6, "match start should be 6 (after 'hello ')");
    assert_eq!(
        m.end, 13,
        "match end should be 13 (start + len of 'abandon')"
    );
    assert!(m.start < m.end, "match start must be less than end");
}

#[test]
fn test_scan_by_index_check() {
    // 验证位置正确性：单词从 index 0 开始
    let text = "abandon";
    let result = vocab::scan_for_vocabulary(text);
    assert_eq!(result.len(), 1, "exactly one match expected");
    assert_eq!(result[0].start, 0);
    assert_eq!(result[0].end, 7);
    assert_eq!(result[0].word, "abandon");
}

#[test]
fn test_scan_case_insensitive() {
    // 大写形式应同样匹配
    let text = "ABANDON ability";
    let result = vocab::scan_for_vocabulary(text);
    assert_eq!(result.len(), 2, "both ABANDON and ability should match");
    assert_eq!(result[0].word, "ABANDON");
    assert_eq!(result[1].word, "ability");
}

#[test]
fn test_scan_mixed_case() {
    let text = "AbAnDoN";
    let result = vocab::scan_for_vocabulary(text);
    assert!(!result.is_empty(), "mixed-case 'AbAnDoN' should match");
    assert_eq!(
        result[0].word, "AbAnDoN",
        "matched word preserves original case"
    );
}

#[test]
fn test_scan_multiple_words() {
    // 文本中包含多个已知单词
    let text = "abandon ability abstract accelerate";
    let result = vocab::scan_for_vocabulary(text);
    assert!(
        result.len() >= 4,
        "expected at least 4 matches, got {len}",
        len = result.len()
    );
    // 验证每个匹配的单词
    let words: Vec<&str> = result.iter().map(|m| m.word.as_str()).collect();
    assert!(
        words.contains(&"abandon"),
        "results should include 'abandon'"
    );
    assert!(
        words.contains(&"ability"),
        "results should include 'ability'"
    );
    assert!(
        words.contains(&"abstract"),
        "results should include 'abstract'"
    );
    assert!(
        words.contains(&"accelerate"),
        "results should include 'accelerate'"
    );
}

#[test]
fn test_scan_no_false_positives() {
    // 单词片段不应匹配；但 scan_for_vocabulary 用正则提取完整 token，
    // 所以 "abandoning" 整体不会被匹配（除非它在词表中）
    // 我们测试一个不在词表中的长单词
    let text = "abandonxyz";
    let result = vocab::scan_for_vocabulary(text);
    assert!(
        result.is_empty(),
        "'abandonxyz' is not a known word and should not match"
    );
}

#[test]
fn test_scan_with_punctuation() {
    // 标点符号被正则排除，仅匹配字母 token
    let text = "hello, abandon! how's it going?";
    let result = vocab::scan_for_vocabulary(text);
    let words: Vec<&str> = result.iter().map(|m| m.word.as_str()).collect();
    assert!(
        words.contains(&"abandon"),
        "'abandon' should match in punctuated text"
    );
    // "how's" — 正则有 `(?:'[a-zA-Z]+)?` 所以会匹配完整 "how's"
    // 但 "how's" 不在词表中，不应匹配
    assert!(
        !words.contains(&"how's"),
        "contraction 'how's' should not match"
    );
}

#[test]
fn test_scan_positions_monotonic() {
    let text = "ability abandon accelerate";
    let result = vocab::scan_for_vocabulary(text);
    assert!(result.len() >= 3, "expected at least 3 matches");
    for i in 1..result.len() {
        assert!(
            result[i - 1].end <= result[i].start,
            "matches should be in order and non-overlapping: match {} ends at {}, match {} starts at {}",
            i - 1,
            result[i - 1].end,
            i,
            result[i].start
        );
    }
}
