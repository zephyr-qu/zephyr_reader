use std::sync::Arc;

use crate::domain::AppError;

use super::super::kv_store::KvStore;
use super::super::models::{BlockLayoutCache, LayoutCache, LayoutCacheKey, ScrollIrCache};

/// 排版缓存仓储 — 委托 KvStore 操作
pub struct LayoutCacheRepository {
    kv: Arc<KvStore>,
}

impl LayoutCacheRepository {
    /// 创建排版缓存仓储
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 保存排版缓存
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, cache: &LayoutCache) -> Result<(), AppError> {
        self.kv.save_layout_cache(key, cache)
    }

    /// 获取排版缓存
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<LayoutCache>, AppError> {
        self.kv.get_layout_cache(key)
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

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use super::*;
    use crate::storage::models::LayoutCache;
    use crate::storage::models::LayoutCacheKey;
    use crate::domain::PageContent;
    use tempfile::TempDir;

    #[test]
    fn invalidate_book_cache_removes_entries() {
        let dir = TempDir::new().unwrap();
        let kv = Arc::new(KvStore::new(dir.path()).unwrap());

        let key = LayoutCacheKey {
            book_id: "book1".into(),
            chapter_index: 0,
            chunk_index: None,
            config_hash: 0x1234,
        };
        let cache = LayoutCache::new(
            0x1234,
            vec![PageContent {
                chapter_index: 0,
                page_index: 0,
                content: "test page".into(),
                is_last_page: true,
                start_offset: 0,
                end_offset: 9,
                first_paragraph_index: 0,
                last_paragraph_index: 0,
            }],
        );
        kv.save_layout_cache(&key, &cache).unwrap();
        assert!(kv.get_layout_cache(&key).unwrap().is_some());

        let repo = LayoutCacheRepository::new(kv.clone());
        repo.invalidate_book_cache("book1").unwrap();

        assert!(kv.get_layout_cache(&key).unwrap().is_none());
    }
}

