//! 领域类型纯函数单元测试
//!
//! 测试 AppError、RichParagraph、RichTextSpan 等领域类型
//! 无需外部依赖，纯函数测试

use rust_lib_zephyr_reader::domain::types::rich_text::{
    RichParagraph, RichTextSpan, RichTextSpanData, SpanStyle,
};
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

    check(
        AppError::FileNotFound {
            path: "/test/path".into(),
        },
        "FileNotFound",
        &["File not found", "/test/path"],
    );
    check(
        AppError::FileReadError {
            path: "/path".into(),
            details: "denied".into(),
        },
        "FileReadError",
        &["File read error", "/path", "denied"],
    );
    check(
        AppError::FileWriteError {
            path: "/out".into(),
            details: "full".into(),
        },
        "FileWriteError",
        &["File write error", "/out", "full"],
    );
    check(
        AppError::UnsupportedFormat {
            format: "docx".into(),
        },
        "UnsupportedFormat",
        &["docx", "Unsupported file format"],
    );
    check(
        AppError::EpubParseError {
            reason: "missing container.xml".into(),
        },
        "EpubParseError",
        &["EPUB parse error", "missing container.xml"],
    );
    check(
        AppError::ChapterExtractError {
            index: 3,
            reason: "toc not found".into(),
        },
        "ChapterExtractError",
        &["Chapter 3", "toc not found"],
    );
    check(
        AppError::DatabaseError {
            reason: "connection timeout".into(),
        },
        "DatabaseError",
        &["Database error", "connection timeout"],
    );
    check(
        AppError::NotFound {
            entity: "Book".into(),
        },
        "NotFound",
        &["Resource not found", "Book"],
    );
    check(
        AppError::SearchError {
            reason: "index not ready".into(),
        },
        "SearchError",
        &["Search error", "index not ready"],
    );
    check(
        AppError::SecurityError {
            reason: "traversal".into(),
            path: "/etc/passwd".into(),
        },
        "SecurityError",
        &["Security error", "traversal", "/etc/passwd"],
    );
    check(
        AppError::InvalidInput {
            reason: "empty title".into(),
        },
        "InvalidInput",
        &["Invalid input", "empty title"],
    );
    check(
        AppError::InternalError {
            reason: "null ptr".into(),
        },
        "InternalError",
        &["Internal error", "null ptr"],
    );
    check(
        AppError::TaskPanic {
            task_name: "parser".into(),
            details: "overflow".into(),
        },
        "TaskPanic",
        &["Task panic", "parser", "overflow"],
    );
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
    let err = AppError::InvalidInput {
        reason: "bad value".into(),
    };
    let debug = format!("{err:?}");
    let display = format!("{err}");
    assert_ne!(debug, display, "Debug and Display output should differ");
    assert!(debug.contains("InvalidInput"));
    assert!(display.contains("Invalid input"));
}
