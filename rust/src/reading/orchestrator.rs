//! `ReadingOrchestrator` — 阅读编排器（薄壳）。
//!
//! 设计目的：把 god module `api/core.rs` 的 LRU 缓存 + 分页 + session + 章节读取逻辑全部抽到
//! 内部 `reading/` 模块；`api/core.rs` 退化为薄 FFI 适配层（validate path → orchestrator method）。
//!
//! 全局单例（LazyLock）匹配现有 FFI 语义——所有状态都在进程内全局，FFI 无构造器入口，强行 DI 没意义。
//! 各子模块（session/pagination/chapter_access/*_cache）独立持有自己的全局状态；orchestrator 仅
//! 提供"业务方法名 + 测试清理入口"，不引入额外适配层抽象。

use std::sync::LazyLock;

use crate::domain::{AppError, PageContent, PaginateResult, TypesetConfig};
use crate::reading::types::PaginationSessionHandle;
use crate::api::core::{ChapterContent, FirstSpineResult};

use super::chapter_access;

/// 阅读编排器全局单例（`LazyLock`），所有业务方法都通过 `ReadingOrchestrator::global()` 进入。
pub struct ReadingOrchestrator {
    // Phase 1 持有：chapter_access（get_chapter_bounds + format_from_file_path）
    // Phase 2+ 增加：pagination, session
    _marker: std::marker::PhantomData<()>,
}

impl ReadingOrchestrator {
    /// 获取全局单例。
    #[allow(dead_code)] // Phase 2+ 接入
    pub fn global() -> &'static Self {
        static INSTANCE: LazyLock<ReadingOrchestrator> = LazyLock::new(|| ReadingOrchestrator {
            _marker: std::marker::PhantomData,
        });
        &INSTANCE
    }

    /// 从 DB 获取章节边界信息（TXT/MD 的文件字节偏移，EPUB/PDF 的 spine/页索引）。
    #[allow(dead_code)] // Phase 2+ 接入
    pub async fn get_chapter_bounds(
        &self,
        validated_path: &str,
        chapter_index: i32,
    ) -> Result<(i32, i32), AppError> {
        chapter_access::get_chapter_bounds(validated_path, chapter_index).await
    }

    /// 分页排版指定文件的所有章节。
    pub async fn paginate_all_content(
        &self,
        file_path: String,
        chapter_index: i32,
        config: TypesetConfig,
    ) -> Result<Vec<PageContent>, AppError> {
        super::pagination::paginate_all_content(file_path, chapter_index, config).await
    }

    /// 轻量级分页排版（只获取页面描述符，文本按需加载）。
    pub async fn paginate_chapter(
        &self,
        file_path: String,
        chapter_index: i32,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<PaginateResult, AppError> {
        super::pagination::paginate_chapter(file_path, chapter_index, config, max_chars).await
    }

    /// 按需获取单页内容（同步，纯内存操作）。
    pub fn get_page_content(
        &self,
        file_path: String,
        chapter_index: i32,
        config_hash: u64,
        page_index: i32,
    ) -> String {
        super::pagination::get_page_content(file_path, chapter_index, config_hash, page_index)
    }

    /// Create a pagination session and run initial pagination for the chapter.
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
    pub async fn create_pagination_session(
        &self,
        file_path: String,
        chapter_index: i32,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
        super::session::create_pagination_session(file_path, chapter_index, config, max_chars).await
    }

    /// Create a pagination session by adopting an existing streamer from cache.
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
    pub async fn create_pagination_session_adopt(
        &self,
        file_path: String,
        chapter_index: i32,
        config: TypesetConfig,
    ) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
        super::session::create_pagination_session_adopt(file_path, chapter_index, config).await
    }

    /// Re-paginate an existing session with a new config in-place.
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
    pub async fn repaginate_session(
        &self,
        handle: PaginationSessionHandle,
        config: TypesetConfig,
        max_chars: Option<u64>,
    ) -> Result<PaginateResult, AppError> {
        super::session::repaginate_session(handle, config, max_chars).await
    }

    /// Expand session to full chapter.
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
    pub async fn paginate_session_full(
        &self,
        handle: PaginationSessionHandle,
        config: Option<TypesetConfig>,
    ) -> Result<PaginateResult, AppError> {
        super::session::paginate_session_full(handle, config).await
    }

    /// Get page content by session handle (sync).
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
    pub fn get_session_page_content(
        &self,
        handle: PaginationSessionHandle,
        page_index: i32,
    ) -> Result<String, AppError> {
        super::session::get_session_page_content(handle, page_index)
    }

    /// Dispose pagination session.
    #[allow(dead_code)] // Phase 3 — FFI delegates in api/core.rs bridge usage
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

    /// 清理 PROVIDER_CACHE + BOOK_ID_CACHE（测试用）。
    pub fn clear_caches_for_test(&self) {
        super::provider_cache::clear_for_test();
        super::book_id_cache::clear_for_test();
    }
}

