use flutter_rust_bridge::frb;
use thiserror::Error;

/// 应用程序统一错误类型。
///
/// 枚举所有可能的应用程序错误，按功能域分组：
/// - 文件操作错误（未找到、读取失败、格式不支持）
/// - 解析错误（EPUB/PDF/章节提取）
/// - 配置错误、数据库错误、搜索错误
/// - 安全错误、输入验证错误等
/// 使用 [thiserror::Error] 派生，自动实现 [std::error::Error]。
/// 标注 `#[frb(non_opaque)]` 允许 Dart 侧接收此错误类型。
#[derive(Debug, Error, PartialEq, Eq)]
#[frb(non_opaque)]
pub enum AppError {


    // ========== 文件错误 ==========
    #[error("File not found: {path}")]
    FileNotFound { path: String },

    #[error("File read error: {path} - {details}")]
    FileReadError { path: String, details: String },

    #[error("File write error: {path} - {details}")]
    FileWriteError { path: String, details: String },

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
    // ========== 实体未找到 ==========
    #[error("Resource not found: {entity}")]
    NotFound { entity: String },
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


impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        // 保留 sqlx 变体分类信息，便于日志/调试区分连接/查询/协议/类型/编码错误
        let category = match &err {
            sqlx::Error::Configuration(_) => "Configuration",
            sqlx::Error::Database(_) => "Database",
            sqlx::Error::Io(_) => "Io",
            sqlx::Error::Tls(_) => "Tls",
            sqlx::Error::Protocol(_) => "Protocol",
            sqlx::Error::RowNotFound => "RowNotFound",
            sqlx::Error::TypeNotFound { .. } => "TypeNotFound",
            sqlx::Error::ColumnIndexOutOfBounds { .. } => "ColumnIndexOutOfBounds",
            sqlx::Error::ColumnNotFound(_) => "ColumnNotFound",
            sqlx::Error::ColumnDecode { .. } => "ColumnDecode",
            sqlx::Error::Encode(_) => "Encode",
            sqlx::Error::Decode(_) => "Decode",
            sqlx::Error::AnyDriverError(_) => "AnyDriverError",
            sqlx::Error::PoolTimedOut => "PoolTimedOut",
            sqlx::Error::PoolClosed => "PoolClosed",
            sqlx::Error::WorkerCrashed => "WorkerCrashed",
            _ => "Other",
        };
        Self::DatabaseError {
            reason: format!("[{}] {}", category, err).into(),
        }
    }
}
