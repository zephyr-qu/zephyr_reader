use flutter_rust_bridge::frb;
use thiserror::Error;

#[derive(Debug, Error)]
#[frb(non_opaque)]
pub enum AppError {
    // ========== 文件错误 ==========
    #[error("File not found: {path}")]
    FileNotFound { path: String },

    #[error("File read error: {path} - {details}")]
    FileReadError { path: String, details: String },

    #[error("Unsupported file format: {format}")]
    UnsupportedFormat { format: String },

    // ========== 解析错误 ==========
    #[error("EPUB parse error: {reason}")]
    EpubParseError { reason: String },

    #[error("PDF parse error: {reason}")]
    PdfParseError { reason: String },

    #[error("Chapter {index} extract error: {reason}")]
    ChapterExtractError { index: i32, reason: String },

    // ========== 配置错误 ==========
    #[error("Typeset config error: {reason}")]
    TypesetConfigError { reason: String },

    // ========== 数据库错误 ==========
    #[error("Database error: {reason}")]
    DatabaseError { reason: String },
    // ========== 存储未初始化 ==========
    #[error("Storage not initialized. Call init() first.")]
    StorageNotInitialized,
    // ========== 搜索错误 ==========
    #[error("Search error: {reason}")]
    SearchError { reason: String },

    // ========== 安全错误 ==========
    #[error("Security error: {reason} (path: {path})")]
    SecurityError { reason: String, path: String },

    // ========== 其他错误 ==========
    #[error("Invalid input: {reason}")]
    InvalidInput { reason: String },

    #[error("Internal error: {reason}")]
    InternalError { reason: String },

    #[error("Task panic in {task_name}: {details}")]
    TaskPanic { task_name: String, details: String },

    #[error("{0}")]
    Other(String),
}

impl AppError {
    /// 文件未找到
    pub fn file_not_found(path: impl Into<String>) -> Self {
        Self::FileNotFound { path: path.into() }
    }

    /// 文件读取错误
    pub fn file_read_error(path: impl Into<String>, details: impl Into<String>) -> Self {
        Self::FileReadError {
            path: path.into(),
            details: details.into(),
        }
    }

    /// 不支持的文件格式
    pub fn unsupported_format(format: impl Into<String>) -> Self {
        Self::UnsupportedFormat {
            format: format.into(),
        }
    }

    /// EPUB 解析错误
    pub fn epub_parse_error(reason: impl Into<String>) -> Self {
        Self::EpubParseError {
            reason: reason.into(),
        }
    }

    /// 配置错误
    pub fn config_error(reason: impl Into<String>) -> Self {
        Self::TypesetConfigError {
            reason: reason.into(),
        }
    }

    /// PDF 解析错误
    pub fn pdf_parse_error(reason: impl Into<String>) -> Self {
        Self::PdfParseError {
            reason: reason.into(),
        }
    }

    /// 文件写入错误
    pub fn file_write_error(path: impl Into<String>, details: impl Into<String>) -> Self {
        Self::InternalError {
            reason: format!("file write failed at {}: {}", path.into(), details.into()),
        }
    }

    /// 章节提取错误
    pub fn chapter_extract_error(index: i32, reason: impl Into<String>) -> Self {
        Self::ChapterExtractError {
            index,
            reason: reason.into(),
        }
    }

    /// 数据库错误
    pub fn database_error(reason: impl Into<String>) -> Self {
        Self::DatabaseError {
            reason: reason.into(),
        }
    }

    /// 存储未初始化
    pub fn storage_not_initialized() -> Self {
        Self::StorageNotInitialized
    }

    /// 搜索错误
    pub fn search_error(reason: impl Into<String>) -> Self {
        Self::SearchError {
            reason: reason.into(),
        }
    }

    /// 安全错误
    pub fn security_error(reason: impl Into<String>, path: impl Into<String>) -> Self {
        Self::SecurityError {
            reason: reason.into(),
            path: path.into(),
        }
    }

    /// 无效输入
    pub fn invalid_input(reason: impl Into<String>) -> Self {
        Self::InvalidInput {
            reason: reason.into(),
        }
    }

    /// 内部错误
    pub fn internal(reason: impl Into<String>) -> Self {
        Self::InternalError {
            reason: reason.into(),
        }
    }

    /// 任务 panic（spawn_blocking 等异步任务崩溃）
    pub fn task_panic(task_name: impl Into<String>, details: impl Into<String>) -> Self {
        Self::TaskPanic {
            task_name: task_name.into(),
            details: details.into(),
        }
    }

    /// 其他错误
    pub fn other(reason: impl Into<String>) -> Self {
        Self::Other(reason.into())
    }

    /// 获取错误码（用于 Flutter 展示）
    pub fn code(&self) -> &'static str {
        match self {
            Self::FileNotFound { .. } => "FILE_NOT_FOUND",
            Self::FileReadError { .. } => "FILE_READ_ERROR",
            Self::UnsupportedFormat { .. } => "UNSUPPORTED_FORMAT",
            Self::EpubParseError { .. } => "EPUB_PARSE_ERROR",
            Self::PdfParseError { .. } => "PDF_PARSE_ERROR",
            Self::ChapterExtractError { .. } => "CHAPTER_EXTRACT_ERROR",
            Self::TypesetConfigError { .. } => "TYPESET_CONFIG_ERROR",
            Self::DatabaseError { .. } => "DATABASE_ERROR",
            Self::StorageNotInitialized => "STORAGE_NOT_INITIALIZED",
            Self::SearchError { .. } => "SEARCH_ERROR",
            Self::SecurityError { .. } => "SECURITY_ERROR",
            Self::InvalidInput { .. } => "INVALID_INPUT",
            Self::InternalError { .. } => "INTERNAL_ERROR",
            Self::TaskPanic { .. } => "TASK_PANIC",
            Self::Other(_) => "OTHER_ERROR",
        }
    }

    /// 获取错误消息（用于 Flutter 展示）
    pub fn message(&self) -> String {
        self.to_string()
    }
}

impl From<anyhow::Error> for AppError {
    fn from(err: anyhow::Error) -> Self {
        Self::InternalError {
            reason: err.to_string(),
        }
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        Self::DatabaseError {
            reason: err.to_string(),
        }
    }
}
