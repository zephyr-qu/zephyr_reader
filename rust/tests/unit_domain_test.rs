//! 领域类型纯函数单元测试
//!
//! 测试 AppError、TypesetConfig、RichParagraph、RichTextSpan 等领域类型
//! 无需外部依赖，纯函数测试

use rust_lib_zephyr_reader::domain::types::rich_text::{RichParagraph, RichTextSpan, RichTextSpanData, SpanStyle};
use rust_lib_zephyr_reader::domain::types::typeset::{LanguageType, TypesetConfig};
use rust_lib_zephyr_reader::domain::AppError;

// ==================== AppError ====================

#[test]
fn test_apperror_display() {
    /// 断言错误的 Display 包含所有期望的子串，且 Debug 包含变体名。
    #[track_caller]
    fn check(err: AppError, variant: &str, expected: &[&str]) {
        let display = err.to_string();
        assert!(
            format!("{err:?}").contains(variant),
            "Debug '{err:?}' should contain variant '{variant}'"
        );
        for &s in expected {
            assert!(
                display.contains(s),
                "Display '{display}' should contain '{s}'"
            );
        }
    }

    check(AppError::FileNotFound { path: "/test/path".into() },           "FileNotFound",       &["File not found", "/test/path"]);
    check(AppError::FileReadError { path: "/path".into(), details: "denied".into() }, "FileReadError", &["File read error", "/path", "denied"]);
    check(AppError::FileWriteError { path: "/out".into(), details: "full".into() },   "FileWriteError", &["File write error", "/out", "full"]);
    check(AppError::UnsupportedFormat { format: "docx".into() },          "UnsupportedFormat",  &["docx", "Unsupported file format"]);
    check(AppError::EpubParseError { reason: "missing container.xml".into() },         "EpubParseError",  &["EPUB parse error", "missing container.xml"]);
    check(AppError::PdfParseError { reason: "invalid cross reference".into() },         "PdfParseError",   &["PDF parse error", "invalid cross reference"]);
    check(AppError::ChapterExtractError { index: 3, reason: "toc not found".into() },   "ChapterExtractError", &["Chapter 3", "toc not found"]);
    check(AppError::TypesetConfigError { reason: "font size out of range".into() },     "TypesetConfigError",  &["config error", "font size out of range"]);
    check(AppError::DatabaseError { reason: "connection timeout".into() },              "DatabaseError",       &["Database error", "connection timeout"]);
    check(AppError::NotFound { entity: "Book".into() },                   "NotFound",           &["Resource not found", "Book"]);
    check(AppError::SearchError { reason: "index not ready".into() },     "SearchError",        &["Search error", "index not ready"]);
    check(AppError::SecurityError { reason: "traversal".into(), path: "/etc/passwd".into() }, "SecurityError", &["Security error", "traversal", "/etc/passwd"]);
    check(AppError::InvalidInput { reason: "empty title".into() },        "InvalidInput",       &["Invalid input", "empty title"]);
    check(AppError::InternalError { reason: "null ptr".into() },           "InternalError",     &["Internal error", "null ptr"]);
    check(AppError::TaskPanic { task_name: "parser".into(), details: "overflow".into() }, "TaskPanic", &["Task panic", "parser", "overflow"]);
}

#[test]
fn test_apperror_storage_not_initialized() {
    let display = AppError::StorageNotInitialized.to_string();
    assert_eq!(display, "Storage not initialized. Call init() first.");
}

#[test]
fn test_apperror_other() {
    let err = AppError::Other("something went wrong".into());
    assert!(matches!(&err, AppError::Other(msg) if msg == "something went wrong"));
    assert_eq!(err.to_string(), "something went wrong");
}

#[test]
fn test_apperror_debug_and_display() {
    let err = AppError::InvalidInput { reason: "bad value".into() };
    let debug = format!("{err:?}");
    let display = format!("{err}");
    assert_ne!(debug, display, "Debug and Display output should differ");
    assert!(debug.contains("InvalidInput"));
    assert!(display.contains("Invalid input"));
}
// ==================== TypesetConfig ====================

#[test]
fn test_typeset_config_default() {
    let config = TypesetConfig::default();
    assert_eq!(config.page_width, 1080);
    assert_eq!(config.page_height, 1920);
    assert_eq!(config.font_size, 18);
    assert_eq!(config.line_spacing, 1.5);
    assert_eq!(config.letter_spacing, 0.0);
    assert_eq!(config.paragraph_spacing, 1.0);
    assert_eq!(config.first_line_indent, 2);
    assert_eq!(config.language, LanguageType::Auto);
    assert!(!config.enable_hyphenation);
    assert_eq!(config.font_family, "Noto Sans SC");
    assert!(config.calibration.is_none());
}

#[test]
fn test_typeset_config_validate_valid() {
    let config = TypesetConfig::default();
    assert!(config.validate().is_ok(), "default config should be valid");
}

#[test]
fn test_typeset_config_validate_invalid_width() {
    // Below min
    let err = TypesetConfig {
        page_width: 50,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "page_width=50 should be invalid");

    // Above max
    let err = TypesetConfig {
        page_width: 20000,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "page_width=20000 should be invalid");
}

#[test]
fn test_typeset_config_validate_invalid_font_size() {
    // Below min
    let err = TypesetConfig {
        font_size: 5,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "font_size=5 should be invalid");

    // Above max
    let err = TypesetConfig {
        font_size: 200,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "font_size=200 should be invalid");
}

#[test]
fn test_typeset_config_validate_invalid_spacing() {
    // Below min
    let err = TypesetConfig {
        line_spacing: 0.1,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "line_spacing=0.1 should be invalid");

    // Above max
    let err = TypesetConfig {
        line_spacing: 10.0,
        ..TypesetConfig::default()
    }
    .validate();
    assert!(err.is_err(), "line_spacing=10.0 should be invalid");
}

#[test]
fn test_typeset_config_validate_and_fix() {
    // page_width clamped to min
    let fixed = TypesetConfig {
        page_width: 50,
        ..TypesetConfig::default()
    }
    .validate_and_fix();
    assert_eq!(fixed.page_width, 100, "page_width should be clamped to 100");

    // line_spacing clamped to max
    let fixed = TypesetConfig {
        line_spacing: 10.0,
        ..TypesetConfig::default()
    }
    .validate_and_fix();
    assert_eq!(
        fixed.line_spacing, 5.0,
        "line_spacing should be clamped to 5.0"
    );
}

#[test]
fn test_typeset_config_validate_and_report_invalid() {
    let report = TypesetConfig {
        page_width: 50,
        line_spacing: 10.0,
        ..TypesetConfig::default()
    }
    .validate_and_report();
    assert!(
        !report.fixes.is_empty(),
        "invalid config should produce fixes"
    );
    assert_eq!(report.fixed_config.page_width, 100);
    assert_eq!(report.fixed_config.line_spacing, 5.0);
}

#[test]
fn test_typeset_config_validate_and_report_valid() {
    let config = TypesetConfig::default();
    let report = config.validate_and_report();
    assert!(report.fixes.is_empty(), "valid config should have no fixes");
    assert_eq!(report.fixed_config.page_width, config.page_width);
}

#[test]
fn test_typeset_config_hash_same() {
    let config1 = TypesetConfig::default();
    let config2 = TypesetConfig::default();
    assert_eq!(
        config1.config_hash(),
        config2.config_hash(),
        "same config should produce same hash"
    );
}

#[test]
fn test_typeset_config_hash_different() {
    let hash_default = TypesetConfig::default().config_hash();
    let hash_other = TypesetConfig {
        font_size: 20,
        ..TypesetConfig::default()
    }
    .config_hash();
    assert_ne!(
        hash_default, hash_other,
        "different configs should produce different hashes"
    );
}

#[test]
fn test_typeset_config_hash_deterministic() {
    let config = TypesetConfig::default();
    let hash1 = config.config_hash();
    let hash2 = config.config_hash();
    assert_eq!(hash1, hash2, "hash should be deterministic");
}

// ==================== RichParagraph ====================

#[test]
fn test_rich_paragraph_plain() {
    let para = RichParagraph::plain("Hello".to_string(), 2);
    assert!(!para.is_heading);
    assert_eq!(para.heading_level, 0);
    assert_eq!(para.indent, 2);
    assert!(!para.is_image);
    assert_eq!(para.spans.len(), 1);
    assert!(para.spans[0].is_plain());
    assert_eq!(para.spans[0].text(), "Hello");
    assert_eq!(para.full_text(), "Hello");
}

#[test]
fn test_rich_paragraph_heading() {
    let para = RichParagraph::heading("Title".to_string(), 1);
    assert!(para.is_heading);
    assert_eq!(para.heading_level, 1);
    assert_eq!(para.indent, 0);
    assert_eq!(para.spans.len(), 1);
    assert!(!para.spans[0].is_plain());
}

#[test]
fn test_rich_paragraph_image() {
    let data = vec![1, 2, 3];
    let para = RichParagraph::image(data, "alt text".to_string());
    assert!(para.is_image);
    assert!(para.spans.is_empty());
    assert_eq!(para.image_data, vec![1, 2, 3]);
    assert_eq!(para.image_alt.as_deref(), Some("alt text"));
    assert!(para.image_src.is_none());
    assert!(para.full_text().is_empty());
}

#[test]
fn test_rich_paragraph_image_placeholder() {
    let para =
        RichParagraph::image_placeholder("images/photo.jpg".to_string(), "a photo".to_string());
    assert!(para.is_image);
    assert!(para.spans.is_empty());
    assert_eq!(para.image_src.as_deref(), Some("images/photo.jpg"));
    assert_eq!(para.image_alt.as_deref(), Some("a photo"));
    assert!(para.image_data.is_empty());
}

// ==================== RichTextSpan ====================

#[test]
fn test_rich_text_span_text() {
    let span = RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
        text: "plain".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "plain");

    let span = RichTextSpan::Styled(SpanStyle::Bold, RichTextSpanData {
        text: "bold".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "bold");

    let span = RichTextSpan::Styled(SpanStyle::Italic, RichTextSpanData {
        text: "italic".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "italic");

    let span = RichTextSpan::Styled(SpanStyle::BoldItalic, RichTextSpanData {
        text: "bolditalic".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "bolditalic");

    let span = RichTextSpan::Styled(SpanStyle::Underline, RichTextSpanData {
        text: "underline".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "underline");

    let span = RichTextSpan::Styled(SpanStyle::Strikethrough, RichTextSpanData {
        text: "strike".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "strike");

    let span = RichTextSpan::Styled(SpanStyle::Code, RichTextSpanData {
        text: "code".into(),
        font_size: None,
        color: None,
    });
    assert_eq!(span.text(), "code");

    let span = RichTextSpan::Link {
        data: RichTextSpanData {
            text: "click me".into(),
            font_size: None,
            color: None,
        },
        url: "https://example.com".into(),
    };
    assert_eq!(span.text(), "click me");
}

#[test]
fn test_rich_text_span_is_plain() {
    let plain = RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
        text: "x".into(),
        font_size: None,
        color: None,
    });
    assert!(plain.is_plain());

    let bold = RichTextSpan::Styled(SpanStyle::Bold, RichTextSpanData {
        text: "x".into(),
        font_size: None,
        color: None,
    });
    assert!(!bold.is_plain());
}

#[test]
fn test_rich_text_span_with_css() {
    let span = RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
        text: "styled".into(),
        font_size: None,
        color: None,
    });
    let styled = span.with_css(Some(20.0), Some("#ff0000".into()));
    assert_eq!(styled.font_size(), Some(20.0));
    let dbg = format!("{styled:?}");
    assert!(
        dbg.contains("#ff0000"),
        "color should be set in debug output"
    );
}

#[test]
fn test_rich_text_span_font_size() {
    let mut span = RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
        text: "resize".into(),
        font_size: Some(14.0),
        color: None,
    });
    assert_eq!(span.font_size(), Some(14.0));

    span.set_font_size(Some(18.0));
    assert_eq!(span.font_size(), Some(18.0));

    span.set_font_size(None);
    assert_eq!(span.font_size(), None);
}

#[test]
fn test_rich_text_span_font_size_all_variants() {
    let variants: [RichTextSpan; 8] = [
        RichTextSpan::Styled(SpanStyle::Plain, RichTextSpanData {
            text: "p".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::Bold, RichTextSpanData {
            text: "b".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::Italic, RichTextSpanData {
            text: "i".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::BoldItalic, RichTextSpanData {
            text: "bi".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::Underline, RichTextSpanData {
            text: "u".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::Strikethrough, RichTextSpanData {
            text: "s".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Styled(SpanStyle::Code, RichTextSpanData {
            text: "c".into(),
            font_size: Some(10.0),
            color: None,
        }),
        RichTextSpan::Link {
            data: RichTextSpanData {
                text: "l".into(),
                font_size: Some(10.0),
                color: None,
            },
            url: "http://x.com".into(),
        },
    ];
    for v in &variants {
        assert_eq!(v.font_size(), Some(10.0));
    }
}
