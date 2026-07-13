use std::sync::Arc;

use crate::domain::AppError;

use super::super::kv_store::KvStore;
use super::super::models::ScrollIrCache;

/// 排版缓存仓储
pub struct LayoutCacheRepository {
    kv: Arc<KvStore>,
}

impl LayoutCacheRepository {
    /// 创建排版缓存仓储
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 保存 Scroll IR 缓存
    pub fn save_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        cache: &ScrollIrCache,
    ) -> Result<(), AppError> {
        self.kv
            .save_scroll_ir_cache(file_path, chapter_index, cache)
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
    /// 块分页 sled 缓存已移除；scroll IR 按 file_path+chapter_index 键存储，
    /// 不会被 book 删除影响（孤立条目无害）。
    pub fn invalidate_book_cache(&self, _book_id: &str) -> Result<(), AppError> {
        Ok(())
    }
}
