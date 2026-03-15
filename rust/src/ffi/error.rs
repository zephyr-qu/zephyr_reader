//! FFI 错误类型定义
//! 统一错误处理，向 Flutter 侧暴露标准化错误

use flutter_rust_bridge::frb;

/// 解析器错误类型
#[derive(Debug, Clone)]
#[frb]
pub enum ParserError {
    /// 文件不存在
    FileNotFound { path: String },
    /// 文件读取失败
    FileReadError { path: String, message: String },
    /// 编码检测失败
    EncodingError(String),
    /// EPUB 解析失败
    EpubParseError(String),
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
    /// 内部错误
    InternalError(String),
}

impl ParserError {
    /// 创建文件不存在错误
    pub fn file_not_found(path: impl Into<String>) -> Self {
        ParserError::FileNotFound { path: path.into() }
    }

    /// 创建文件读取错误（字符串消息）
    pub fn file_read_error(path: impl Into<String>, message: impl Into<String>) -> Self {
        ParserError::FileReadError {
            path: path.into(),
            message: message.into(),
        }
    }
}

impl From<std::io::Error> for ParserError {
    fn from(err: std::io::Error) -> Self {
        use std::io::ErrorKind;
        match err.kind() {
            ErrorKind::NotFound => ParserError::FileNotFound {
                path: "未知文件".to_string(),
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
#[derive(Debug, Clone)]
#[frb]
pub enum TypesetError {
    /// 无效的排版参数
    InvalidParameter(String),
    /// 文本处理失败
    TextProcessError(String),
}

/// 结果类型别名
/// 在函数返回类型中使用 Result<T, ParserError> 的简写
pub type ApiResult<T> = std::result::Result<T, ParserError>;
