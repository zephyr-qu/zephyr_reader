//! FFI 错误类型定义
//! 统一错误处理，向 Flutter 侧暴露标准化错误

use flutter_rust_bridge::frb;

/// 解析器错误类型
///
/// 每个错误变体都有对应的错误码，便于 Flutter 侧分类处理
#[derive(Debug, Clone)]
#[frb]
pub enum ParserError {
    /// 文件不存在
    FileNotFound { path: String, reason: String },
    /// 文件读取失败
    FileReadError { path: String, message: String },
    /// 编码检测失败
    EncodingError(String),
    /// EPUB 解析失败
    EpubParseError(String),
    /// PDF 解析失败
    PdfParseError(String),
    /// TXT 解析失败
    TxtParseError(String),
    /// 章节提取失败
    ChapterExtractError(String),
    /// 排版处理失败
    Typeset(String),
    /// 流式加载失败
    StreamError(String),
    /// 不支持的文件格式
    UnsupportedFormat(String),
    /// 文件写入失败
    FileWriteError(String),
    /// 内部错误
    InternalError(String),
    /// 配置错误
    ConfigError(String),
    /// 页面提取失败
    PageExtractError(String),
    /// 文本提取失败
    TextExtractError(String),
    /// 其他错误（通用错误消息）
    Other(String),
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
        }
    }

    /// 获取用户友好的错误消息
    ///
    /// # 示例
    ///
    /// ```rust
    /// use rust_lib_zephyr_reader::ffi::ParserError;
    ///
    /// let error = ParserError::file_not_found("test.txt");
    /// let msg = error.user_message();
    /// assert!(msg.contains("文件不存在"));
    /// ```
    pub fn user_message(&self) -> String {
        match self {
            Self::FileNotFound { path, reason } => {
                format!("文件不存在：{} ({})", path, reason)
            }
            Self::FileReadError { path, message } => {
                format!("读取文件失败 [{}]：{}", path, message)
            }
            Self::EncodingError(msg) => {
                format!("编码检测失败：{}", msg)
            }
            Self::EpubParseError(msg) => {
                format!("EPUB 解析失败：{}", msg)
            }
            Self::PdfParseError(msg) => {
                format!("PDF 解析失败：{}", msg)
            }
            Self::TxtParseError(msg) => {
                format!("TXT 解析失败：{}", msg)
            }
            Self::ChapterExtractError(msg) => {
                format!("章节提取失败：{}", msg)
            }
            Self::Typeset(msg) => {
                format!("排版处理失败：{}", msg)
            }
            Self::StreamError(msg) => {
                format!("流式加载失败：{}", msg)
            }
            Self::UnsupportedFormat(msg) => {
                format!("不支持的文件格式：{}", msg)
            }
            Self::FileWriteError(msg) => {
                format!("文件写入失败：{}", msg)
            }
            Self::InternalError(msg) => {
                format!("内部错误：{}", msg)
            }
            Self::ConfigError(msg) => {
                format!("配置错误：{}", msg)
            }
            Self::PageExtractError(msg) => {
                format!("页面提取失败：{}", msg)
            }
            Self::TextExtractError(msg) => {
                format!("文本提取失败：{}", msg)
            }
            Self::Other(msg) => {
                format!("错误：{}", msg)
            }
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

impl std::fmt::Display for ParserError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.user_message())
    }
}

// EPUB 错误转换
impl From<String> for ParserError {
    fn from(err: String) -> Self {
        ParserError::EpubParseError(err)
    }
}

/// 排版错误类型
#[derive(Debug, Clone)]
#[frb]
pub enum TypesetError {
    /// 无效的排版参数
    InvalidParameter(String),
    /// 文本处理失败
    TextProcessError(String),
}

/// 排版配置错误类型
#[derive(Debug, Clone)]
#[frb]
pub enum TypesetConfigError {
    /// 无效的参数
    InvalidParameter(String),
}

impl std::fmt::Display for TypesetConfigError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidParameter(msg) => write!(f, "排版配置错误：{}", msg),
        }
    }
}

/// 结果类型别名
/// 在函数返回类型中使用 Result<T, ParserError> 的简写
pub type ApiResult<T> = std::result::Result<T, ParserError>;
