// ============================================================
// 文件作用：应用程序统一错误类型定义
//
// 公有类型/函数：
//   - enum AppError — 所有可能的应用错误，按功能域分组
//   - impl From<sqlx::Error> for AppError — sqlx 错误到 AppError 的转换
//
// 使用说明：
//   添加新变体时请同时：
//   1. 在 enum 中定义变体及 #[error] 格式化字符串
//   2. 添加 /// doc comment 说明触发场景和字段含义
//   3. 在 frb_generated.rs 的 decode/encode/sse 中注册（运行 codegen）
//   4. Dart 侧 AppErrorMapper 添加对应映射
// ============================================================

use flutter_rust_bridge::frb;
use thiserror::Error;

/// 应用程序统一错误类型。
///
/// 枚举所有可能的应用程序错误，按功能域分组：
/// - 文件操作错误（未找到、读取失败、格式不支持）
/// - 解析错误（EPUB/TXT/章节提取）
/// - 配置错误、数据库错误、搜索错误
/// - 安全错误、输入验证错误等
///
/// 每个变体附带 #[error(...)]  宏定义用户可读的错误消息，
/// 以及 /// doc comment 说明触发场景和字段含义。
///
/// 使用 [thiserror::Error] 派生，自动实现 [std::error::Error]。
/// 标注 `#[frb(non_opaque)]` 允许 Dart 侧接收此错误类型。
#[derive(Debug, Error, PartialEq, Eq)]
#[frb(non_opaque)]
pub enum AppError {
    // ========== 文件错误 ==========
    /// 文件未找到：指定路径的文件在文件系统中不存在。
    /// 用于 EPUB/TXT 解析、封面提取等需要读取文件的场景。
    #[error("File not found: {path}")]
    FileNotFound { path: String },

    /// 文件读取失败：文件存在但 IO 操作出错（权限、损坏、磁盘等）。
    /// 用于安全路径验证、数据库文件复制、EPUB/TXT 文件读取等场景。
    #[error("File read error: {path} - {details}")]
    FileReadError { path: String, details: String },

    /// 文件写入失败：创建目录或写入文件时 IO 操作出错。
    /// 用于备份、封面缓存、图片处理输出等场景。
    #[error("File write error: {path} - {details}")]
    FileWriteError { path: String, details: String },

    /// 不支持的格式：传入的文件扩展名不在注册的解析器列表中。
    /// 当前支持 EPUB 和 TXT。
    #[error("Unsupported file format: {format}")]
    UnsupportedFormat { format: String },

    // ========== 解析错误 ==========
    /// EPUB 解析失败：解压、元数据提取、正文渲染中出现结构化错误。
    /// 可能原因：损坏的 EPUB、缺失 spine/NCX、资源引用错误。
    #[error("EPUB parse error: {reason}")]
    EpubParseError { reason: String },

    /// 章节提取失败：按索引提取 EPUB/TXT 的某个章节时出错。
    /// index 为目标章节序号（0-based）；reason 为失败原因。
    #[error("Chapter {index} extract error: {reason}")]
    ChapterExtractError { index: i32, reason: String },

    /// 章节体积过大：超过 2MB 上限，建议重新导入。
    /// 主要用于 EPUB 嵌入式字体/大图导致的单章膨胀。
    #[error("Chapter too large ({size_bytes} bytes, max 2MB). Consider re-importing: {details}")]
    ChapterTooLarge { size_bytes: usize, details: String },

    // ========== 数据库错误 ==========
    /// 数据库操作失败：SQLite/Sled 的查询、迁移、KV 存取出错。
    /// 涵盖连接池、迁移脚本、键值存储、实体仓库等所有 DB 层调用。
    #[error("Database error: {reason}")]
    DatabaseError { reason: String },

    // ========== 实体未找到 ==========
    /// 资源不存在：请求的实体（书、章节、封面等）在存储中未找到。
    /// entity 字段描述未找到的对象类型（如 "book"）。
    #[error("Resource not found: {entity}")]
    NotFound { entity: String },

    // ========== 存储未初始化 ==========
    /// 存储未初始化：在调用 init() 之前尝试使用存储层。
    #[error("Storage not initialized. Call init() first.")]
    StorageNotInitialized,

    // ========== 搜索错误 ==========
    /// 搜索出错：FTS5 引擎查询、索引、配置失败。
    #[error("Search error: {reason}")]
    SearchError { reason: String },

    // ========== 安全错误 ==========
    /// 安全检查未通过：文件路径穿越、格式验证等防注入机制拦截。
    /// reason 说明违规原因，path 为被检查的文件路径。
    #[error("Security error: {reason} (path: {path})")]
    SecurityError { reason: String, path: String },

    // ========== 存储数据过时 ==========
    /// 书本数据过时：当前持有的数据版本与存储不一致。
    /// 触发调用方刷新数据后重试。
    #[error("Stale book data: {message}")]
    StaleBookData { message: String },

    // ========== 其他错误 ==========
    /// 输入校验失败：传入参数不满足格式、范围或约束要求。
    /// 用于 API 入参校验、备份元数据验证、图片尺寸检查等场景。
    #[error("Invalid input: {reason}")]
    InvalidInput { reason: String },

    /// 内部错误：不应发生的运行时逻辑错误（已初始化的存储再次初始化、
    /// 时间戳格式错误、序列化失败等），暗示编码缺陷或竞态条件。
    #[error("Internal error: {reason}")]
    InternalError { reason: String },

    /// 任务恐慌：tokio::spawn 的异步任务因 panic 而崩溃。
    /// 用于双语对齐、MDict 查找、章节 IR 构建等跨线程操作。
    #[error("Task panic in {task_name}: {details}")]
    TaskPanic { task_name: String, details: String },

    /// 其他通用错误：兜底变体，不匹配任何分类的错误。
    /// 尽量优先使用上文的具名变体以保留类型信息。
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
            reason: format!("[{}] {}", category, err),
        }
    }
}
