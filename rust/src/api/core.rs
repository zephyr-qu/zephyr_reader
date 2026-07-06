pub(crate) use crate::domain::{AppError, ChapterContentIr, PageBlockSlice, TypesetConfig};
use crate::domain::{PageContent, PaginateResult};
use crate::parser::registry::parser_for_file;
use crate::storage::models::BookFormat;
use crate::storage::repos::{BookRepository, ChapterRepository};
use crate::storage::storage_pool;
pub use crate::reading::types::PaginationSessionHandle;
use crate::reading::orchestrator::ReadingOrchestrator;
use crate::utils::security::validate_file_path;
use flutter_rust_bridge::frb;
/// 章节内容枚举
#[derive(Debug, Clone)]
#[frb(dart_metadata=("freezed"))]
pub enum ChapterContent {
    Raw(String),
    Pages(Vec<PageContent>),
}
/// 首段 spine 快速提取结果
#[derive(Debug, Clone)]
#[frb]
pub struct FirstSpineResult {
    pub text: String,
}
const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;
// ==================== 导入与解析 ====================
/// 解析书籍文件：验证路径、检查大小限制、选择解析器、保存元数据。
pub async fn parse_book(file_path: String) -> Result<String, AppError> {
    tracing::info!("[parse_book] start: file_path={}", file_path);
    let validated_path = validate_file_path(&file_path)?;
    let metadata = tokio::fs::metadata(&validated_path)
        .await
        .map_err(|e| AppError::FileReadError { path: validated_path.clone(), details: e.to_string() })?;
    if metadata.len() > MAX_FILE_SIZE {
        return Err(AppError::SecurityError { reason: format!(
            "file size exceeds limit (max {} MB)", MAX_FILE_SIZE / 1024 / 1024
        ), path: validated_path });
    }
    let pool = storage_pool()?;
    if let Some(existing) = BookRepository::find_by_file_path(&pool, &validated_path).await? {
        return Ok(existing.book_id);
    }
    let parser = parser_for_file(&validated_path)?;
    let result = parser.parse(&validated_path).await?;
    BookRepository::save(&pool, &result.book_info).await?;
    BookRepository::save_metadata(&pool, &result.book_info).await?;
    ChapterRepository::save(&pool, &result.book_info.book_id, &result.chapters).await?;
    Ok(result.book_info.book_id)
}
/// 快速获取章节首段文本（仅读第一个 spine，不做分页）。
#[frb]
pub async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<FirstSpineResult, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_first_spine_only(file_path, chapter_index)
        .await
}
/// 获取章节前 N 字符（惰性转换，只读取必要的 spine）。
#[frb]
pub async fn get_chapter_partial(
    file_path: String,
    chapter_index: i32,
    max_chars: u64,
) -> Result<String, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_partial(file_path, chapter_index, max_chars)
        .await
}
/// 获取指定章节的原始文本内容。
#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
    config: Option<TypesetConfig>,
) -> Result<ChapterContent, AppError> {
    ReadingOrchestrator::global()
        .get_chapter(file_path, chapter_index, config)
        .await
}
/// Lightweight pagination — descriptor-only, text on demand via [get_page_content].
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb]
pub async fn paginate_chapter(
    book_id: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    ReadingOrchestrator::global()
        .paginate_chapter(book_id, chapter_index, config, max_chars)
        .await
}
/// Fetch single page text synchronously from streamer/block cache.
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb(sync)]
pub fn get_page_content(
    book_id: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<String, AppError> {
    ReadingOrchestrator::global()
        .get_page_content(book_id, chapter_index, config_hash, page_index)
}
/// M5.1：从 `PAGINATION_ENGINE_CACHE` 取单页块（staging 预渲染）。
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb(sync)]
pub fn get_page_blocks(
    book_id: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Result<Vec<PageBlockSlice>, AppError> {
    ReadingOrchestrator::global()
        .get_page_blocks(book_id, chapter_index, config_hash, page_index)
}
/// Create pagination session with initial pagination.
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb]
pub async fn create_pagination_session(
    book_id: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    ReadingOrchestrator::global()
        .create_pagination_session(book_id, chapter_index, config, max_chars)
        .await
}
/// Create session by adopting existing streamer from cache.
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb]
pub async fn create_pagination_session_adopt(
    book_id: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    ReadingOrchestrator::global()
        .create_pagination_session_adopt(book_id, chapter_index, config)
        .await
}
/// Re-paginate session with new config in-place.
#[frb]
pub async fn repaginate_session(
    handle: PaginationSessionHandle,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    ReadingOrchestrator::global()
        .repaginate_session(handle, config, max_chars)
        .await
}

/// Apply Flutter TextPainter metrics to an existing session (P4-4 / ADR-013).
#[frb]
pub async fn apply_session_calibration(
    handle: PaginationSessionHandle,
    calibration: crate::domain::types::typeset::TypesetCalibration,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    ReadingOrchestrator::global()
        .apply_session_calibration(handle, calibration, max_chars)
        .await
}
/// Expand session to full chapter.
#[frb]
pub async fn paginate_session_full(
    handle: PaginationSessionHandle,
    config: Option<TypesetConfig>,
) -> Result<PaginateResult, AppError> {
    ReadingOrchestrator::global()
        .paginate_session_full(handle, config)
        .await
}
/// Get page content by session handle (sync).
#[frb(sync)]
pub fn get_session_page_content(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<String, AppError> {
    ReadingOrchestrator::global()
        .get_session_page_content(handle, page_index)
}
/// M3.2：页内块列表（`ContentBlocks` 模式有效）。
#[frb(sync)]
pub fn get_session_page_blocks(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<Vec<PageBlockSlice>, AppError> {
    ReadingOrchestrator::global()
        .get_session_page_blocks(handle, page_index)
}
/// M3.4：章级 charOffset → pageIndex。
#[frb(sync)]
pub fn session_char_offset_to_page_index(
    handle: PaginationSessionHandle,
    char_offset: i32,
) -> Result<i32, AppError> {
    ReadingOrchestrator::global()
        .session_char_offset_to_page_index(handle, char_offset)
}
/// Dispose pagination session.
#[frb(sync)]
pub fn dispose_pagination_session(
    handle: PaginationSessionHandle,
) -> Result<(), AppError> {
    ReadingOrchestrator::global()
        .dispose_pagination_session(handle)
}
/// Expose `TypesetConfig::config_hash()` to Dart.
#[frb(sync)]
pub fn compute_config_hash(config: TypesetConfig) -> u64 {
    config.config_hash()
}
/// Check if format supports chunked pagination.
/// M2: `book_id` 替代 `file_path`（ADR-014）。
#[frb(sync)]
pub fn supports_chunked_pagination(book_id: String) -> bool {
    // M2: resolve book_id → format via DB（同步调用，用 spawn_blocking 内的 runtime）
    tokio::runtime::Handle::try_current().map_or(false, |handle| {
        handle.block_on(async {
            let pool = match storage_pool() {
                Ok(p) => p,
                Err(_) => return false,
            };
            match BookRepository::find_by_id(&pool, &book_id).await {
                Ok(Some(book)) => matches!(book.format, BookFormat::Txt | BookFormat::Epub),
                _ => false,
            }
        })
    })
}

/// P4-1：加载整章 ContentBlock IR + plain 投影（scroll 路径；不创建 session）。
#[frb]
pub async fn get_chapter_content_ir(
    file_path: String,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    ReadingOrchestrator::global()
        .get_chapter_content_ir(file_path, chapter_index)
        .await
}
