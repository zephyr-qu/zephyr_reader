//! FFI 错误类型定义
//! 统一错误处理，向 Flutter 侧暴露标准化错误

use flutter_rust_bridge::frb;
use thiserror::Error;

/// 解析器错误类型
///
/// 每个错误变体都有对应的错误码，便于 Flutter 侧分类处理
#[derive(Debug, Clone, Error)]
#[frb]
pub enum ParserError {
    /// 文件不存在
    #[error("文件不存在：{path} ({reason})")]
    FileNotFound { path: String, reason: String },

    /// 文件读取失败
    #[error("读取文件失败 [{path}]：{message}")]
    FileReadError { path: String, message: String },

    /// 编码检测失败
    #[error("编码检测失败：{0}")]
    EncodingError(String),

    /// EPUB 解析失败
    #[error("EPUB 解析失败：{0}")]
    EpubParseError(String),

    /// PDF 解析失败
    #[error("PDF 解析失败：{0}")]
    PdfParseError(String),

    /// TXT 解析失败
    #[error("TXT 解析失败：{0}")]
    TxtParseError(String),

    /// 章节提取失败
    #[error("章节提取失败：{0}")]
    ChapterExtractError(String),

    /// 排版处理失败
    #[error("排版处理失败：{0}")]
    Typeset(String),

    /// 流式加载失败
    #[error("流式加载失败：{0}")]
    StreamError(String),

    /// 不支持的文件格式
    #[error("不支持的文件格式：{0}")]
    UnsupportedFormat(String),

    /// 文件写入失败
    #[error("文件写入失败：{0}")]
    FileWriteError(String),

    /// 内部错误
    #[error("内部错误：{0}")]
    InternalError(String),

    /// 配置错误
    #[error("配置错误：{0}")]
    ConfigError(String),

    /// 页面提取失败
    #[error("页面提取失败：{0}")]
    PageExtractError(String),

    /// 文本提取失败
    #[error("文本提取失败：{0}")]
    TextExtractError(String),

    /// 其他错误（通用错误消息）
    #[error("错误：{0}")]
    Other(String),

    /// 安全错误（路径遍历攻击等）
    #[error("安全错误：{0}")]
    SecurityError(String),
}

impl ParserError {
    /// 获取错误码（用于 Flutter 侧分类处理）
    ///
    /// # 示例
    ///
    /// ```rust
    /// use rust_lib_zephyr_reader::ffi::ParserError;
    ///
    /// let error = ParserError::file_not_found("test.txt");
    /// assert_eq!(error.error_code(), "FILE_NOT_FOUND");
    /// ```
    pub fn error_code(&self) -> &'static str {
        match self {
            Self::FileNotFound { .. } => "FILE_NOT_FOUND",
            Self::FileReadError { .. } => "FILE_READ_ERROR",
            Self::EncodingError(_) => "ENCODING_ERROR",
            Self::EpubParseError(_) => "EPUB_PARSE_ERROR",
            Self::PdfParseError(_) => "PDF_PARSE_ERROR",
            Self::TxtParseError(_) => "TXT_PARSE_ERROR",
            Self::ChapterExtractError(_) => "CHAPTER_EXTRACT_ERROR",
            Self::Typeset(_) => "TYPESET_ERROR",
            Self::StreamError(_) => "STREAM_ERROR",
            Self::UnsupportedFormat(_) => "UNSUPPORTED_FORMAT",
            Self::FileWriteError(_) => "FILE_WRITE_ERROR",
            Self::InternalError(_) => "INTERNAL_ERROR",
            Self::ConfigError(_) => "CONFIG_ERROR",
            Self::PageExtractError(_) => "PAGE_EXTRACT_ERROR",
            Self::TextExtractError(_) => "TEXT_EXTRACT_ERROR",
            Self::Other(_) => "OTHER_ERROR",
            Self::SecurityError(_) => "SECURITY_ERROR",
        }
    }

    /// 获取用户友好的错误消息（中文）
    pub fn user_message(&self) -> String {
        self.to_string()
    }

    /// 创建文件不存在错误
    pub fn file_not_found(path: impl Into<String>) -> Self {
        ParserError::FileNotFound {
            path: path.into(),
            reason: "文件不存在".to_string(),
        }
    }

    /// 创建文件读取错误（字符串消息）
    pub fn file_read_error(path: impl Into<String>, message: impl Into<String>) -> Self {
        ParserError::FileReadError {
            path: path.into(),
            message: message.into(),
        }
    }

    /// 创建文件写入错误
    pub fn file_write_error(path: impl Into<String>, message: impl Into<String>) -> Self {
        ParserError::FileReadError {
            path: path.into(),
            message: format!("写入失败：{}", message.into()),
        }
    }
}

/// IO 错误上下文，保留原始路径信息
pub struct IoErrorWithContext {
    pub path: String,
    pub error: std::io::Error,
}

impl From<IoErrorWithContext> for ParserError {
    fn from(ctx: IoErrorWithContext) -> Self {
        use std::io::ErrorKind;
        match ctx.error.kind() {
            ErrorKind::NotFound => ParserError::FileNotFound {
                path: ctx.path,
                reason: "文件不存在".to_string(),
            },
            ErrorKind::PermissionDenied => ParserError::FileReadError {
                path: ctx.path,
                message: format!("权限被拒绝：{}", ctx.error),
            },
            ErrorKind::InvalidData => ParserError::EncodingError(ctx.error.to_string()),
            _ => ParserError::FileReadError {
                path: ctx.path,
                message: ctx.error.to_string(),
            },
        }
    }
}

/// 创建带上下文的 IO 错误
pub fn io_error(path: impl Into<String>, error: std::io::Error) -> ParserError {
    IoErrorWithContext {
        path: path.into(),
        error,
    }
    .into()
}

impl From<std::io::Error> for ParserError {
    fn from(err: std::io::Error) -> Self {
        use std::io::ErrorKind;
        match err.kind() {
            ErrorKind::NotFound => ParserError::FileNotFound {
                path: "未知文件".to_string(),
                reason: "文件不存在".to_string(),
            },
            ErrorKind::PermissionDenied => ParserError::FileReadError {
                path: "未知文件".to_string(),
                message: err.to_string(),
            },
            ErrorKind::InvalidData => ParserError::EncodingError(err.to_string()),
            _ => ParserError::FileReadError {
                path: "未知文件".to_string(),
                message: err.to_string(),
            },
        }
    }
}

// EPUB 错误转换
impl From<String> for ParserError {
    fn from(err: String) -> Self {
        ParserError::EpubParseError(err)
    }
}

/// 排版错误类型
#[derive(Debug, Clone, Error)]
#[frb]
pub enum TypesetError {
    /// 无效的排版参数
    #[error("无效的排版参数：{0}")]
    InvalidParameter(String),
    /// 文本处理失败
    #[error("文本处理失败：{0}")]
    TextProcessError(String),
}

/// 排版配置错误类型
#[derive(Debug, Clone, Error)]
#[frb]
pub enum TypesetConfigError {
    /// 无效的参数
    #[error("排版配置错误：{0}")]
    InvalidParameter(String),
}

/// 结果类型别名
/// 在函数返回类型中使用 Result<T, ParserError> 的简写
pub type ApiResult<T> = std::result::Result<T, ParserError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parser_error_error_code() {
        let error = ParserError::file_not_found("test.txt");
        assert_eq!(error.error_code(), "FILE_NOT_FOUND");

        let error = ParserError::EncodingError("UTF-8".to_string());
        assert_eq!(error.error_code(), "ENCODING_ERROR");

        let error = ParserError::UnsupportedFormat("xyz".to_string());
        assert_eq!(error.error_code(), "UNSUPPORTED_FORMAT");
    }

    #[test]
    fn test_parser_error_user_message() {
        let error = ParserError::file_not_found("test.txt");
        let msg = error.user_message();
        assert!(msg.contains("文件不存在"));
        assert!(msg.contains("test.txt"));

        let error = ParserError::SecurityError("路径遍历".to_string());
        let msg = error.user_message();
        assert!(msg.contains("安全错误"));
    }

    #[test]
    fn test_io_error_conversion() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
        let parser_err: ParserError = io_err.into();
        assert_eq!(parser_err.error_code(), "FILE_NOT_FOUND");

        let io_err = std::io::Error::new(std::io::ErrorKind::PermissionDenied, "access denied");
        let parser_err: ParserError = io_err.into();
        assert_eq!(parser_err.error_code(), "FILE_READ_ERROR");
    }

    #[test]
    fn test_display_impl() {
        let error = ParserError::InternalError("test".to_string());
        let display_str = format!("{}", error);
        assert!(display_str.contains("内部错误"));
    }

    #[test]
    fn test_io_error_with_context() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "not found");
        let error = io_error("/path/to/file.txt", io_err);
        assert_eq!(error.error_code(), "FILE_NOT_FOUND");
    }
}
