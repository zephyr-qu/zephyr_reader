//! `ReadingOrchestrator` — 阅读编排器（薄壳）。
//!
//! 内部功能模块：
//! - `chapter_access` — 章节边界 + 格式识别 + 章节读取
//! - `chapter_ir` — ContentBlock IR 加载
//! - `provider_cache` — `PROVIDER_CACHE` LRU（章节内容 provider）
//! - `pagination_store` — `PaginationStore` 全局 LRU（分页引擎缓存）
//! - `layout_cache` — 持久化分页结果（sled KV）读写

use std::collections::HashMap;
use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::domain::{AppError, ChapterContentIr, TypesetConfig};
use crate::api::types::{ChapterContent, FirstSpineResult};
use crate::storage::repos::BookRepository;
use crate::storage::storage_pool;

use super::chapter_access;

/// 阅读编排器全局单例（`LazyLock`），所有业务方法都通过 `ReadingOrchestrator::global()` 进入。
pub struct ReadingOrchestrator {
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

    /// 存储 Flutter 预计算的行断点。
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

    /// 清理 PROVIDER_CACHE + BOOK_ID_CACHE + 分页内存 LRU + line_breaks（集成测试用）。
    pub fn clear_caches_for_test(&self) {
        super::provider_cache::clear_for_test();
        super::clear_for_test();
        super::pagination_store::PaginationStore::global().clear_lru_for_test();
        LINE_BREAKS_STORE.lock().clear();
    }
}

/// 全局行断点缓存 (book_id, chapter_index, config_hash) → Vec<u32>。
pub(crate) static LINE_BREAKS_STORE: LazyLock<Mutex<HashMap<(String, i32, u64), Vec<u32>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
