//! `ReadingOrchestrator` — 阅读编排器（薄壳）。
//!
//! 设计目的：把 god module `api/core.rs` 的 LRU 缓存 + 分页 + session + 章节读取逻辑全部抽到
//! 内部 `reading/` 模块；`api/core.rs` 退化为薄 FFI 适配层（validate path → orchestrator method）。
//!
//! 全局单例（LazyLock）匹配现有 FFI 语义——所有状态都在进程内全局，FFI 无构造器入口，强行 DI 没意义。
//! 各子模块（session/pagination/chapter_access/*_cache）独立持有自己的全局状态；orchestrator 仅
//! 提供"业务方法名 + 测试清理入口"，不引入额外适配层抽象。

use std::collections::HashMap;
use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::domain::{AppError, ChapterContentIr, PageBlockSlice, PaginateResult, TypesetConfig};
use crate::reading::types::PaginationSessionHandle;
use crate::api::core::{ChapterContent, FirstSpineResult};
use crate::storage::repos::BookRepository;
use crate::storage::storage_pool;


use super::chapter_access;

/// 阅读编排器全局单例（`LazyLock`），所有业务方法都通过 `ReadingOrchestrator::global()` 进入。
pub struct ReadingOrchestrator {
    // Phase 1 持有：chapter_access（get_chapter_bounds + format_from_file_path）
    // Phase 2+ 增加：pagination, session
    _marker: std::marker::PhantomData<()>,
}

impl ReadingOrchestrator {
    /// 获取全局单例。
    pub fn global() -> &'static Self {
        static INSTANCE: LazyLock<ReadingOrchestrator> = LazyLock::new(|| ReadingOrchestrator {
            _marker: std::marker::PhantomData,
        });
        &INSTANCE
    }

    /// M2: 从 book_id 解析 file_path（ADR-014 — handle-based 统一）。
    async fn resolve_book_path(book_id: &str) -> Result<String, AppError> {
        // 复用已有的 chapter_access::BOOK_ID_CACHE 方向（path→book_id）暂不满足需求；
        // M2 反向解析走 DB 主键查询，后续若热点明显可补 book_id→path 缓存。
        let pool = storage_pool()?;
        let book = BookRepository::find_by_id(&pool, book_id)
            .await?
            .ok_or_else(|| AppError::NotFound {
                entity: format!("book {book_id}"),
            })?;
        Ok(book.file_path)
    }

    /// 从 DB 获取章节边界信息（TXT 的文件字节偏移，EPUB 的 spine 索引）。
    pub async fn get_chapter_bounds(
        &self,
        validated_path: &str,
        chapter_index: i32,
    ) -> Result<(i32, i32), AppError> {
        chapter_access::get_chapter_bounds(validated_path, chapter_index).await
    }

    /// 轻量级分页排版（只获取页面描述符，文本按需加载）。
    /// M2: book_id 替代 file_path（ADR-014）。
    pub async fn paginate_chapter(
        &self,
        book_id: String,
        chapter_index: i32,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<PaginateResult, AppError> {
        let file_path = Self::resolve_book_path(&book_id).await?;
        super::pagination::paginate_chapter(&book_id, file_path, chapter_index, config, max_chars).await
    }

    /// 按需获取单页内容（同步，纯内存操作）。
    pub fn get_page_content(
        &self,
        book_id: String,
        chapter_index: i32,
        config_hash: u64,
        page_index: i32,
    ) -> Result<String, AppError> {
        super::pagination::get_page_content(&book_id, chapter_index, config_hash, page_index)
    }

    /// 从 `PAGINATION_ENGINE_CACHE` 按需取页块（staging 预渲染用）。
    pub fn get_page_blocks(
        &self,
        book_id: String,
        chapter_index: i32,
        config_hash: u64,
        page_index: i32,
    ) -> Result<Vec<PageBlockSlice>, AppError> {
        super::pagination::get_page_blocks(&book_id, chapter_index, config_hash, page_index)
    }

    /// Create a pagination session and run initial pagination for the chapter.
    /// M2: book_id 替代 file_path（ADR-014）。
    pub async fn create_pagination_session(
        &self,
        book_id: String,
        chapter_index: i32,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
        let file_path = Self::resolve_book_path(&book_id).await?;
        super::session::create_pagination_session(book_id, file_path, chapter_index, config, max_chars).await
    }

    /// Create a pagination session by adopting an existing streamer from cache.
    /// M2: book_id 替代 file_path（ADR-014）。
    pub async fn create_pagination_session_adopt(
        &self,
        book_id: String,
        chapter_index: i32,
        config: TypesetConfig,
    ) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
        let file_path = Self::resolve_book_path(&book_id).await?;
        super::session::create_pagination_session_adopt(book_id, file_path, chapter_index, config).await
    }

    /// Re-paginate an existing session with a new config in-place.
    pub async fn repaginate_session(
        &self,
        handle: PaginationSessionHandle,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<PaginateResult, AppError> {
        super::session::repaginate_session(handle, config, max_chars).await
    }

    /// Apply Flutter TextPainter calibration to an existing session.
    pub async fn apply_session_calibration(
        &self,
        handle: PaginationSessionHandle,
        calibration: crate::domain::types::typeset::TypesetCalibration,
        max_chars: Option<u64>,
    ) -> Result<PaginateResult, AppError> {
        super::session::apply_session_calibration(handle, calibration, max_chars).await
    }

    /// Expand session to full chapter.
    pub async fn paginate_session_full(
        &self,
        handle: PaginationSessionHandle,
        config: Option<TypesetConfig>,
    ) -> Result<PaginateResult, AppError> {
        super::session::paginate_session_full(handle, config).await
    }

    /// Get page content by session handle (sync).
    pub fn get_session_page_content(
        &self,
        handle: PaginationSessionHandle,
        page_index: i32,
    ) -> Result<String, AppError> {
        super::session::get_session_page_content(handle, page_index)
    }

    /// M3.2：页内块列表（block 模式）。
    pub fn get_session_page_blocks(
        &self,
        handle: PaginationSessionHandle,
        page_index: i32,
    ) -> Result<Vec<PageBlockSlice>, AppError> {
        super::session::get_session_page_blocks(handle, page_index)
    }

    /// M3.4：章级 charOffset → pageIndex。
    pub fn session_char_offset_to_page_index(
        &self,
        handle: PaginationSessionHandle,
        char_offset: i32,
    ) -> Result<i32, AppError> {
        super::session::session_char_offset_to_page_index(handle, char_offset)
    }

    /// Dispose pagination session.
    pub fn dispose_pagination_session(
        &self,
        handle: PaginationSessionHandle,
    ) -> Result<(), AppError> {
        super::session::dispose_pagination_session(handle)
    }
    /// 获取章节首段文本。
    pub async fn get_chapter_first_spine_only(
        &self,
        file_path: String,
        chapter_index: i32,
    ) -> Result<FirstSpineResult, AppError> {
        super::chapter_access::get_chapter_first_spine_only(file_path, chapter_index).await
    }

    /// 获取章节前 N 字符。
    pub async fn get_chapter_partial(
        &self,
        file_path: String,
        chapter_index: i32,
        max_chars: u64,
    ) -> Result<String, AppError> {
        super::chapter_access::get_chapter_partial(file_path, chapter_index, max_chars).await
    }

    /// 获取指定章节内容。
    pub async fn get_chapter(
        &self,
        file_path: String,
        chapter_index: i32,
        config: Option<TypesetConfig>,
    ) -> Result<ChapterContent, AppError> {
        super::chapter_access::get_chapter(file_path, chapter_index, config).await
    }

    /// P4-1：加载整章 IR（scroll / 块渲染；不创建 pagination session）。
    /// M2: book_id 替代 file_path（ADR-014）。
    pub async fn get_chapter_content_ir(
        &self,
        book_id: String,
        chapter_index: i32,
    ) -> Result<ChapterContentIr, AppError> {
        let file_path = Self::resolve_book_path(&book_id).await?;
        super::chapter_ir::load_chapter_content_ir(&file_path, chapter_index).await
    }

    /// Phase 2: 存储 Flutter 预计算的行断点。
    pub fn store_line_breaks(
        &self,
        book_id: String,
        chapter_index: i32,
        config_hash: u64,
        line_breaks: Vec<u32>,
    ) -> Result<(), AppError> {
        let mut store = LINE_BREAKS_STORE.lock();
        store.insert((book_id, chapter_index, config_hash), line_breaks);
        Ok(())
    }

    /// Phase 2: 获取预存储的行断点（供 paginate_chapter 使用）。
    pub fn take_line_breaks(
        &self,
        book_id: &str,
        chapter_index: i32,
        config_hash: u64,
    ) -> Option<Vec<u32>> {
        let mut store = LINE_BREAKS_STORE.lock();
        store.remove(&(book_id.to_string(), chapter_index, config_hash))
    }

    /// 清理 PROVIDER_CACHE + BOOK_ID_CACHE + 分页内存 LRU + line_breaks（集成测试用）。
    pub fn clear_caches_for_test(&self) {
        super::provider_cache::clear_for_test();
        super::clear_for_test();
        super::pagination_store::PaginationStore::global().clear_lru_for_test();
        LINE_BREAKS_STORE.lock().clear();
    }
}

/// Phase 6: 全局行断点缓存 (book_id, chapter_index, config_hash) → Vec<u32>。
pub(crate) static LINE_BREAKS_STORE: LazyLock<Mutex<HashMap<(String, i32, u64), Vec<u32>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

