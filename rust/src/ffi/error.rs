//! FFI 错误类型定义
//! 统一错误处理，向 Flutter 侧暴露标准化错误

use flutter_rust_bridge::frb;
use rusqlite;
use thiserror::Error;

/// 解析器错误类型
///
/// 每个错误变体都有对应的错误码，便于 Flutter 侧分类处理。
/// 使用 `#[frb(non_opaque)]` 确保 Dart 侧可以正确模式匹配错误类型。
#[derive(Debug, Error)]
#[frb(non_opaque)]
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
    /// 对包含路径的错误进行脱敏处理，防止泄露系统路径信息
    pub fn user_message(&self) -> String {
        match self {
            Self::FileNotFound { path, .. } => {
                let safe_name = Self::sanitize_path(path);
                format!("文件不存在：{}", safe_name)
            }
            Self::FileReadError { path, message } => {
                let safe_name = Self::sanitize_path(path);
                format!("文件读取失败 [{}]：{}", safe_name, message)
            }
            Self::FileWriteError(msg) => {
                // 从消息中提取并脱敏路径
                Self::sanitize_error_message(msg)
            }
            _ => {
                let msg = self.to_string();
                // 对通用错误消息也进行路径脱敏
                Self::sanitize_error_message(&msg)
            }
        }
    }

    /// 路径脱敏辅助函数
    /// 仅保留文件名，去除完整路径
    fn sanitize_path(path: &str) -> String {
        std::path::Path::new(path)
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_else(|| "未知文件".to_string())
    }

    /// 对错误消息中的路径进行脱敏处理
    ///
    /// 扫描消息中可能包含的路径模式，将其替换为文件名。
    fn sanitize_error_message(msg: &str) -> String {
        // 如果消息不包含路径分隔符，直接返回
        if !msg.contains('/') && !msg.contains('\\') {
            return msg.to_string();
        }

        // 使用正则替换所有路径段为文件名
        // 简单策略：提取消息中最后一个路径分隔符后的内容作为"文件名"
        let filename = if msg.contains('\\') {
            msg.rsplit('\\').next().unwrap_or(msg)
        } else {
            msg.rsplit('/').next().unwrap_or(msg)
        };

        // 如果文件名包含扩展名且长度合理，说明提取到了文件名
        if filename.contains('.') && filename.len() < 100 {
            // 用文件名替换完整的路径
            // 由于消息格式多样，最安全的方式是返回文件名 + 上下文
            filename.to_string()
        } else {
            // 无法提取文件名，返回原始消息
            msg.to_string()
        }
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
        ParserError::FileWriteError(format!("写入失败 [{}]：{}", path.into(), message.into()))
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

impl From<anyhow::Error> for ParserError {
    fn from(err: anyhow::Error) -> Self {
        ParserError::InternalError(err.to_string())
    }
}

impl From<rusqlite::Error> for ParserError {
    fn from(err: rusqlite::Error) -> Self {
        ParserError::InternalError(format!("数据库错误: {}", err))
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

    #[test]
    fn test_file_write_error_variant() {
        let error = ParserError::file_write_error("/path/to/file.txt", "磁盘已满");
        assert_eq!(error.error_code(), "FILE_WRITE_ERROR");
        let msg = error.user_message();
        // 验证消息包含关键信息（脱敏后）
        assert!(msg.contains("file.txt") || msg.contains("磁盘已满"));
        // 验证完整路径已被脱敏
        assert!(!msg.contains("/path/to/file.txt"));
    }
}
