//! 领域类型纯函数单元测试
//!
//! 测试 AppError、TypesetConfig、RichParagraph、RichTextSpan 等领域类型
//! 无需外部依赖，纯函数测试

use rust_lib_zephyr_reader::domain::types::rich_text::{RichParagraph, RichTextSpan, RichTextSpanData, SpanStyle};
use rust_lib_zephyr_reader::domain::types::typeset::{LanguageType, TypesetConfig};
use rust_lib_zephyr_reader::domain::AppError;

// ==================== AppError ====================

#[test]
fn test_apperror_file_not_found() {
    let err = AppError::file_not_found("/test/path");
    assert!(matches!(&err, AppError::FileNotFound { path } if path == "/test/path"));
    let display = err.to_string();
    assert!(display.contains("File not found"));
    assert!(display.contains("/test/path"));
}

#[test]
fn test_apperror_file_read_error() {
    let err = AppError::file_read_error("/path/to/file.txt", "permission denied");
    assert!(matches!(&err, AppError::FileReadError { path, details }
        if path == "/path/to/file.txt" && details == "permission denied"));
    let display = err.to_string();
    assert!(display.contains("File read error"));
    assert!(display.contains("/path/to/file.txt"));
    assert!(display.contains("permission denied"));
}

#[test]
fn test_apperror_file_write_error() {
    let err = AppError::file_write_error("/output.txt", "disk full");
    assert!(matches!(&err, AppError::FileWriteError { path, details }
        if path == "/output.txt" && details == "disk full"));
    let display = err.to_string();
    assert!(display.contains("File write error"));
    assert!(display.contains("/output.txt"));
    assert!(display.contains("disk full"));
}

#[test]
fn test_apperror_unsupported_format() {
    let err = AppError::unsupported_format("docx");
    assert!(matches!(&err, AppError::UnsupportedFormat { format } if format == "docx"));
    let display = err.to_string();
    assert!(display.contains("docx"));
    assert!(display.contains("Unsupported file format"));
}

#[test]
fn test_apperror_epub_parse_error() {
    let err = AppError::epub_parse_error("missing container.xml");
    assert!(
        matches!(&err, AppError::EpubParseError { reason } if reason == "missing container.xml")
    );
    let display = err.to_string();
    assert!(display.contains("EPUB parse error"));
    assert!(display.contains("missing container.xml"));
}

#[test]
fn test_apperror_pdf_parse_error() {
    let err = AppError::pdf_parse_error("invalid cross reference");
    assert!(
        matches!(&err, AppError::PdfParseError { reason } if reason == "invalid cross reference")
    );
    let display = err.to_string();
    assert!(display.contains("PDF parse error"));
    assert!(display.contains("invalid cross reference"));
}

#[test]
fn test_apperror_chapter_extract_error() {
    let err = AppError::chapter_extract_error(3, "table of contents not found");
    assert!(
        matches!(&err, AppError::ChapterExtractError { index, reason }
        if *index == 3 && reason == "table of contents not found")
    );
    let display = err.to_string();
    assert!(display.contains("Chapter 3"));
    assert!(display.contains("table of contents not found"));
}

#[test]
fn test_apperror_config_error() {
    let err = AppError::config_error("font size out of range");
    assert!(
        matches!(&err, AppError::TypesetConfigError { reason } if reason == "font size out of range")
    );
    let display = err.to_string();
    assert!(display.contains("config error"));
    assert!(display.contains("font size out of range"));
}

#[test]
fn test_apperror_database_error() {
    let err = AppError::database_error("connection timeout");
    assert!(matches!(&err, AppError::DatabaseError { reason } if reason == "connection timeout"));
    let display = err.to_string();
    assert!(display.contains("Database error"));
    assert!(display.contains("connection timeout"));
}

#[test]
fn test_apperror_not_found() {
    let err = AppError::not_found("Book");
    assert!(matches!(&err, AppError::NotFound { entity } if entity == "Book"));
    let display = err.to_string();
    assert!(display.contains("Resource not found"));
    assert!(display.contains("Book"));
}

#[test]
fn test_apperror_storage_not_initialized() {
    let err = AppError::storage_not_initialized();
    assert!(matches!(&err, AppError::StorageNotInitialized));
    let display = err.to_string();
    assert_eq!(display, "Storage not initialized. Call init() first.");
}

#[test]
fn test_apperror_search_error() {
    let err = AppError::search_error("index not ready");
    assert!(matches!(&err, AppError::SearchError { reason } if reason == "index not ready"));
    let display = err.to_string();
    assert!(display.contains("Search error"));
    assert!(display.contains("index not ready"));
}

#[test]
fn test_apperror_security_error() {
    let err = AppError::security_error("path traversal detected", "/etc/passwd");
    assert!(matches!(&err, AppError::SecurityError { reason, path }
        if reason == "path traversal detected" && path == "/etc/passwd"));
    let display = err.to_string();
    assert!(display.contains("Security error"));
    assert!(display.contains("path traversal detected"));
    assert!(display.contains("/etc/passwd"));
}

#[test]
fn test_apperror_invalid_input() {
    let err = AppError::invalid_input("empty book title");
    assert!(matches!(&err, AppError::InvalidInput { reason } if reason == "empty book title"));
    let display = err.to_string();
    assert!(display.contains("Invalid input"));
    assert!(display.contains("empty book title"));
}

#[test]
fn test_apperror_internal() {
    let err = AppError::internal("unexpected null pointer");
    assert!(
        matches!(&err, AppError::InternalError { reason } if reason == "unexpected null pointer")
    );
    let display = err.to_string();
    assert!(display.contains("Internal error"));
    assert!(display.contains("unexpected null pointer"));
}

#[test]
fn test_apperror_task_panic() {
    let err = AppError::task_panic("pdf_parser", "stack overflow");
    assert!(matches!(&err, AppError::TaskPanic { task_name, details }
        if task_name == "pdf_parser" && details == "stack overflow"));
    let display = err.to_string();
    assert!(display.contains("Task panic"));
    assert!(display.contains("pdf_parser"));
    assert!(display.contains("stack overflow"));
}

#[test]
fn test_apperror_other() {
    let err = AppError::other("something went wrong");
    assert!(matches!(&err, AppError::Other(msg) if msg == "something went wrong"));
    let display = err.to_string();
    assert_eq!(display, "something went wrong");
}

#[test]
fn test_apperror_debug_and_display() {
    let err = AppError::invalid_input("bad value");
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
