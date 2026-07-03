//! 文本处理模块纯函数单元测试
use rust_lib_zephyr_reader::domain::types::TypesetCalibration;
use rust_lib_zephyr_reader::text::{
    bilingual::{SentenceSegmenter, SimilarityCalculator},
    chapter_detect::extract_chapters,
    char_width::CharWidthTable,
    constants::{is_cjk_char, is_end_avoid_punctuation, is_start_avoid_punctuation},
    css::{
        build_style_map, extract_inline_css, parse_css, resolve_color, resolve_float,
        resolve_font_size,
    },
};

// ==================== constants ====================

#[test]
fn test_is_cjk_char() {
    // CJK unified ideographs (U+4E00..=U+9FFF)
    assert!(is_cjk_char('中'));
    assert!(is_cjk_char('汉'));
    assert!(is_cjk_char('字'));
    // CJK Extension A (U+3400..=U+4DBF)
    assert!(is_cjk_char('\u{3400}'));
    assert!(is_cjk_char('\u{4DBF}'));
    // CJK Compatibility Ideographs (U+F900..=U+FAFF)
    assert!(is_cjk_char('\u{F900}'));
    // CJK punctuation range (U+3000..=U+303F)
    assert!(is_cjk_char('\u{3000}')); // full-width space
    assert!(is_cjk_char('\u{3001}')); // 、
    assert!(is_cjk_char('\u{3002}')); // 。
                                      // ASCII chars return false
    assert!(!is_cjk_char('a'));
    assert!(!is_cjk_char('Z'));
    assert!(!is_cjk_char('0'));
    // Emoji
    assert!(!is_cjk_char('\u{1F600}')); // 😀
                                        // Full-width punctuation (U+FF01) — outside is_cjk range
    assert!(!is_cjk_char('\u{FF01}')); // ！
}

#[test]
fn test_is_start_avoid_punctuation() {
    // CJK start-avoid punctuation
    assert!(is_start_avoid_punctuation('，'));
    assert!(is_start_avoid_punctuation('。'));
    assert!(is_start_avoid_punctuation('、'));
    assert!(is_start_avoid_punctuation('；'));
    assert!(is_start_avoid_punctuation('：'));
    assert!(is_start_avoid_punctuation('？'));
    assert!(is_start_avoid_punctuation('！'));
    assert!(is_start_avoid_punctuation('…'));
    assert!(is_start_avoid_punctuation('—'));
    assert!(is_start_avoid_punctuation('）'));
    assert!(is_start_avoid_punctuation('】'));
    assert!(is_start_avoid_punctuation('》'));
    assert!(is_start_avoid_punctuation('」'));
    assert!(is_start_avoid_punctuation('』'));
    // English start-avoid punctuation
    assert!(is_start_avoid_punctuation('!'));
    assert!(is_start_avoid_punctuation(','));
    assert!(is_start_avoid_punctuation('.'));
    assert!(is_start_avoid_punctuation('?'));
    assert!(is_start_avoid_punctuation(':'));
    // End-avoid char should NOT be start-avoid
    assert!(!is_start_avoid_punctuation('（'));
    assert!(!is_start_avoid_punctuation('【'));
    assert!(!is_start_avoid_punctuation('《'));
    // Regular chars
    assert!(!is_start_avoid_punctuation('a'));
    assert!(!is_start_avoid_punctuation('中'));
}

#[test]
fn test_is_end_avoid_punctuation() {
    // CJK end-avoid punctuation (opening brackets)
    assert!(is_end_avoid_punctuation('（'));
    assert!(is_end_avoid_punctuation('【'));
    assert!(is_end_avoid_punctuation('《'));
    assert!(is_end_avoid_punctuation('「'));
    assert!(is_end_avoid_punctuation('『'));
    // Start-avoid chars should NOT be end-avoid
    assert!(!is_end_avoid_punctuation('。'));
    assert!(!is_end_avoid_punctuation('，'));
    assert!(!is_end_avoid_punctuation('、'));
    assert!(!is_end_avoid_punctuation('！'));
    assert!(!is_end_avoid_punctuation('？'));
    assert!(!is_end_avoid_punctuation('）'));
    assert!(!is_end_avoid_punctuation('》'));
    // Regular chars
    assert!(!is_end_avoid_punctuation('a'));
    assert!(!is_end_avoid_punctuation('中'));
}


// ==================== bilingual ====================

#[test]
fn test_sentence_segmenter_chinese() {
    // Multiple sentences with different punctuation
    let result = SentenceSegmenter::segment_chinese("你好世界。这是一个测试！");
    assert_eq!(result.len(), 2, "should split on 。and ！");
    assert_eq!(result[0].0, "你好世界。");
    assert_eq!(result[1].0, "这是一个测试！");

    // Single sentence without punctuation
    let result = SentenceSegmenter::segment_chinese("这是一个测试");
    assert_eq!(result.len(), 1);
    assert_eq!(result[0].0, "这是一个测试");

    // Question mark
    let result = SentenceSegmenter::segment_chinese("你还好吗？我很好。");
    assert_eq!(result.len(), 2);
    assert_eq!(result[0].0, "你还好吗？");
    assert_eq!(result[1].0, "我很好。");

    // Empty string
    let result = SentenceSegmenter::segment_chinese("");
    assert!(result.is_empty());

    // Newline separator
    let result = SentenceSegmenter::segment_chinese("第一行\n第二行\n");
    assert_eq!(result.len(), 2);
}

#[test]
fn test_sentence_segmenter_english() {
    // Multiple sentences
    let result = SentenceSegmenter::segment_english("Hello World. This is a test!");
    assert_eq!(result.len(), 2);
    assert_eq!(result[0].0, "Hello World.");
    assert_eq!(result[1].0, "This is a test!");

    // Abbreviations should not split (e.g. Mr., Dr.)
    let result = SentenceSegmenter::segment_english("Dr. Smith went home. He was tired.");
    assert_eq!(
        result.len(),
        2,
        "should NOT split after Dr. — keep together with first sentence"
    );

    // Question mark
    let result = SentenceSegmenter::segment_english("How are you? I am fine.");
    assert_eq!(result.len(), 2);

    // Empty string
    let result = SentenceSegmenter::segment_english("");
    assert!(result.is_empty());

    // Single sentence
    let result = SentenceSegmenter::segment_english("This is a test");
    assert_eq!(result.len(), 1);
}

#[test]
fn test_similarity_calculator() {
    // Identical strings
    let sim = SimilarityCalculator::calculate_similarity("hello", "hello");
    assert!((sim - 1.0).abs() < 1e-6);

    // Different strings — low similarity
    let sim = SimilarityCalculator::calculate_similarity("hello", "world");
    assert!(sim < 0.5, "expected similarity < 0.5, got {}", sim);

    // Both empty
    let sim = SimilarityCalculator::calculate_similarity("", "");
    assert!((sim - 1.0).abs() < 1e-6);

    // One empty
    let sim = SimilarityCalculator::calculate_similarity("hello", "");
    assert!((sim - 0.0).abs() < 1e-6);

    let sim = SimilarityCalculator::calculate_similarity("", "world");
    assert!((sim - 0.0).abs() < 1e-6);

    // Partially similar
    let sim = SimilarityCalculator::calculate_similarity("hello", "hallo");
    assert!(sim > 0.5 && sim < 1.0);
}

// ==================== chapter_detect ====================

#[test]
fn test_extract_chapters() {
    // Empty content
    let chapters = extract_chapters("", 10, "test_book");
    assert!(chapters.is_empty());

    // Chinese chapters
    let chapters = extract_chapters("第一章 引言\n第二章 主体\n", 10, "test_book");
    assert_eq!(chapters.len(), 2);
    assert!(chapters[0].title.contains("第一章"));
    assert!(chapters[1].title.contains("第二章"));
    // English chapters ("Chapter N" style) — the EN pattern captures
    // Chapter\s+\d+ with $ anchor. Both chapters are detected and receive
    // sequential indices (0, 1, …), regardless of the text-derived number.
    let chapters = extract_chapters("Chapter 1: Introduction\nChapter 2: Body\n", 10, "test_book");
    assert_eq!(chapters.len(), 2, "should find 2 English chapters");

    // Digit chapters ("N. Title" style)
    let chapters = extract_chapters("1. Intro\n2. Body\n", 10, "test_book");
    assert_eq!(chapters.len(), 2);

    // max_chapters limit
    let chapters = extract_chapters("第一章 引言\n第二章 主体\n第三章 结论\n", 2, "test_book");
    assert_eq!(chapters.len(), 2);
}


// ==================== char_width ====================

#[test]
fn test_char_width_table() {
    let cal = TypesetCalibration {
        dpr: 1.0,
        cjk_width: 16.0,
        ascii_width: 9.6,
        digit_width: 9.6,
        punct_width: 16.0,
        latin_ext_width: 11.2,
        other_width: 12.8,
    };
    let table = CharWidthTable::from_calibration(&cal);

    // CJK chars wider than ASCII
    let cjk_width = table.char_width('中');
    let ascii_width = table.char_width('a');
    assert!(
        cjk_width > ascii_width,
        "CJK width {} should be > ASCII width {}",
        cjk_width,
        ascii_width
    );

    // Digits same width as ASCII
    let digit_width = table.char_width('5');
    assert!(
        (digit_width - ascii_width).abs() < 1e-6,
        "digit width {} should ≈ ASCII width {}",
        digit_width,
        ascii_width
    );

    // CJK punctuation same as CJK
    let punct_width = table.char_width('\u{3002}'); // 。
    assert!(
        (punct_width - cjk_width).abs() < 1e-6,
        "CJK punctuation width {} should ≈ CJK width {}",
        punct_width,
        cjk_width
    );
}

#[test]
fn test_char_width_default_calibration() {
    // Create from default to ensure Default trait works
    let _table = CharWidthTable::from_calibration(&TypesetCalibration::default());
    // Just ensure no panic and basic width properties hold
    let table = CharWidthTable::from_calibration(&TypesetCalibration::default());
    assert!(table.char_width('a') > 0.0);
    assert!(table.char_width('中') > 0.0);
}

// ==================== css ====================

#[test]
fn test_parse_css() {
    // Valid CSS returns rules
    let rules = parse_css("p { color: red; }");
    assert!(!rules.is_empty(), "should parse at least one rule");
    assert_eq!(rules[0].selectors[0], "p");
    assert_eq!(rules[0].declarations.get("color").unwrap(), "red");

    // Multiple rules
    let rules = parse_css("p { color: red; }\ndiv { margin: 0; }");
    assert_eq!(rules.len(), 2);

    // Empty string
    let rules = parse_css("");
    assert!(rules.is_empty());

    // Invalid CSS doesn't panic
    let rules = parse_css("this is not valid css at all");
    // Should return whatever it can parse without panic
    assert!(rules.is_empty() || !rules.is_empty());
}

#[test]
fn test_build_style_map() {
    let rules = parse_css("p { color: red; }\n.title { font-size: 16px; }");
    let map = build_style_map(&rules);
    assert!(map.contains_key("p"));
    assert!(map.contains_key(".title"));

    // Empty rules
    let map = build_style_map(&[]);
    assert!(map.is_empty());
}

#[test]
fn test_resolve_font_size() {
    // Px unit
    assert_eq!(resolve_font_size("16px", 16.0), Some(16.0));

    // Em unit (relative to parent)
    let result = resolve_font_size("1.2em", 16.0);
    assert!(result.is_some());
    assert!((result.unwrap() - 19.2).abs() < 1e-6);

    // Named size
    assert_eq!(resolve_font_size("small", 16.0), Some(13.0));
    assert_eq!(resolve_font_size("medium", 16.0), Some(16.0));
    assert_eq!(resolve_font_size("large", 16.0), Some(18.0));

    // Pt unit
    let result = resolve_font_size("12pt", 16.0);
    assert!(result.is_some());
    assert!((result.unwrap() - 16.0).abs() < 0.01); // 12 * 1.333 ≈ 16.0

    // Percent unit
    let result = resolve_font_size("150%", 16.0);
    assert_eq!(result, Some(24.0));

    // Invalid value
    assert_eq!(resolve_font_size("invalid", 16.0), None);
}

#[test]
fn test_resolve_color() {
    // Hex color
    assert_eq!(resolve_color("#ff0000"), Some("#ff0000".to_string()));

    // Named color
    assert_eq!(resolve_color("red"), Some("#ff0000".to_string()));
    assert_eq!(resolve_color("blue"), Some("#0000ff".to_string()));
    assert_eq!(resolve_color("green"), Some("#008000".to_string()));

    // Invalid color
    assert_eq!(resolve_color("invalid"), None);
    assert_eq!(resolve_color(""), None);
}

#[test]
fn test_extract_inline_css() {
    // Text with style tags
    let css = extract_inline_css("<html><style>p { color: red; }</style></html>");
    assert!(!css.is_empty());
    assert!(css.contains("color: red"));

    // Multiple style tags
    let css =
        extract_inline_css("<style>p { color: red; }</style><style>div { margin: 0; }</style>");
    assert!(css.contains("color: red"));
    assert!(css.contains("margin: 0"));

    // Text without style tags
    let css = extract_inline_css("<html><body>Hello</body></html>");
    assert!(css.is_empty());

    // Empty string
    let css = extract_inline_css("");
    assert!(css.is_empty());
}

#[test]
fn test_resolve_float() {
    // Direct numeric string
    let result = resolve_float("1.5", 16.0);
    assert!(result.is_some());
    assert!((result.unwrap() - 1.5).abs() < 1e-6);

    // Normal keyword
    let result = resolve_float("normal", 16.0);
    assert!(result.is_some());
    assert!((result.unwrap() - 1.2).abs() < 1e-6);

    // Em unit
    let result = resolve_float("2em", 16.0);
    assert_eq!(result, Some(32.0));

    // Px unit
    let result = resolve_float("10px", 16.0);
    assert_eq!(result, Some(10.0));

    // Percent
    let result = resolve_float("50%", 16.0);
    assert_eq!(result, Some(8.0));

    // Invalid
    assert_eq!(resolve_float("invalid", 16.0), None);
}

#[test]
fn test_css_end_to_end() {
    // Parse CSS, build style map, then resolve values
    let css = "body { font-size: 16px; color: #333333; }";
    let rules = parse_css(css);
    assert_eq!(rules.len(), 1);

    let map = build_style_map(&rules);
    assert!(map.contains_key("body"));

    let body_rules = map.get("body").unwrap();
    assert_eq!(body_rules[0].declarations.get("font-size").unwrap(), "16px");
    assert_eq!(body_rules[0].declarations.get("color").unwrap(), "#333333");

    // Resolve values from parsed declarations
    let font_size_val =
        resolve_font_size(body_rules[0].declarations.get("font-size").unwrap(), 16.0);
    assert_eq!(font_size_val, Some(16.0));

    let color_val = resolve_color(body_rules[0].declarations.get("color").unwrap());
    assert_eq!(color_val, Some("#333333".to_string()));
}
