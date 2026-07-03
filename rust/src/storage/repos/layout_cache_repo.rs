use std::sync::Arc;

use crate::domain::AppError;

use super::super::kv_store::KvStore;
use super::super::models::{BlockLayoutCache, LayoutCacheKey, ScrollIrCache};

/// 排版缓存仓储 — 委托 KvStore 操作（P1: plain sled 已移除）
pub struct LayoutCacheRepository {
    kv: Arc<KvStore>,
}

impl LayoutCacheRepository {
    /// 创建排版缓存仓储
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 保存块分页索引缓存
    pub fn save_block_layout_cache(
        &self,
        key: &LayoutCacheKey,
        cache: &BlockLayoutCache,
    ) -> Result<(), AppError> {
        self.kv.save_block_layout_cache(key, cache)
    }

    /// 获取块分页索引缓存
    pub fn get_block_layout_cache(
        &self,
        key: &LayoutCacheKey,
    ) -> Result<Option<BlockLayoutCache>, AppError> {
        self.kv.get_block_layout_cache(key)
    }

    /// 保存 Scroll IR 缓存
    pub fn save_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        cache: &ScrollIrCache,
    ) -> Result<(), AppError> {
        self.kv.save_scroll_ir_cache(file_path, chapter_index, cache)
    }

    /// 获取 Scroll IR 缓存
    pub fn get_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<Option<ScrollIrCache>, AppError> {
        self.kv.get_scroll_ir_cache(file_path, chapter_index)
    }

    /// 使指定书籍的所有排版缓存失效
    pub fn invalidate_book_cache(&self, book_id: &str) -> Result<(), AppError> {
        self.kv.delete_book_layout_cache(book_id)
    }
}


