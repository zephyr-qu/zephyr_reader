pub(crate) use crate::domain::{AppError, PageBlockSlice, TypesetConfig};
use crate::domain::{PageContent, PaginateResult};
use crate::parser::registry::parser_for_file;
use crate::reading::chapter_access::format_from_file_path;
use crate::storage::models::BookFormat;
use crate::storage::repos::{BookRepository, ChapterRepository};
use crate::storage::storage_pool;
pub use crate::reading::types::PaginationSessionHandle;
use crate::reading::orchestrator::ReadingOrchestrator;
pub use crate::text::PageStreamer;
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
        .map_err(|e| AppError::FileReadError { path: validated_path.clone().into(), details: e.to_string().into() })?;
    if metadata.len() > MAX_FILE_SIZE {
        return Err(AppError::SecurityError { reason: format!(
            "file size exceeds limit (max {} MB)", MAX_FILE_SIZE / 1024 / 1024
        ).into(), path: validated_path.into() });
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
/// 分页排版指定文件的所有章节（完整排版结果）。
#[frb]
pub async fn paginate_all_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<PageContent>, AppError> {
    ReadingOrchestrator::global()
        .paginate_all_content(file_path, chapter_index, config)
        .await
}
/// Lightweight pagination — descriptor-only, text on demand via [get_page_content].
#[frb]
pub async fn paginate_chapter(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    ReadingOrchestrator::global()
        .paginate_chapter(file_path, chapter_index, config, max_chars)
        .await
}
/// Fetch single page text synchronously from streamer cache.
#[frb(sync)]
pub fn get_page_content(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> String {
    ReadingOrchestrator::global()
        .get_page_content(file_path, chapter_index, config_hash, page_index)
}
/// M5.1：从 BLOCK_CACHE 取单页块（staging 预渲染）。
#[frb(sync)]
pub fn get_page_blocks(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> Vec<PageBlockSlice> {
    ReadingOrchestrator::global()
        .get_page_blocks(file_path, chapter_index, config_hash, page_index)
}
/// M5.1：章是否含 Image 块（决定 staging 全章 vs partial 分页）。
#[frb]
pub async fn chapter_has_image_blocks(
    file_path: String,
    chapter_index: i32,
) -> Result<bool, AppError> {
    ReadingOrchestrator::global()
        .chapter_has_image_blocks(file_path, chapter_index)
        .await
}
/// Create pagination session with initial pagination.
#[frb]
pub async fn create_pagination_session(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    ReadingOrchestrator::global()
        .create_pagination_session(file_path, chapter_index, config, max_chars)
        .await
}
/// Create session by adopting existing streamer from cache.
#[frb]
pub async fn create_pagination_session_adopt(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    ReadingOrchestrator::global()
        .create_pagination_session_adopt(file_path, chapter_index, config)
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
#[frb(sync)]
pub fn supports_chunked_pagination(file_path: String) -> bool {
    matches!(
        format_from_file_path(&file_path),
        Ok(BookFormat::Txt | BookFormat::Epub)
    )
}
