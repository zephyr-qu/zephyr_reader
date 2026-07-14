// ============================================================
// 文件作用：IR 缓存仓储，管理 Scroll IR 缓存的读写和失效
//
// 公有类型/函数：
//   - IrCacheRepository — IR 缓存仓储结构体
//   - save_scroll_ir_cache() / get_scroll_ir_cache() — IR 缓存
//   - invalidate_book_cache() — 使书籍 IR 缓存失效
// ============================================================

use std::sync::Arc;

use crate::domain::AppError;

use super::super::kv_store::KvStore;
use super::super::models::ScrollIrCache;

/// IR 缓存仓储
pub struct IrCacheRepository {
    kv: Arc<KvStore>,
}

impl IrCacheRepository {
    /// 创建 IR 缓存仓储
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 保存 IR 缓存
    pub fn save_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        cache: &ScrollIrCache,
    ) -> Result<(), AppError> {
        self.kv
            .save_ir_cache(file_path, chapter_index, cache)
    }

    /// 获取 IR 缓存
    pub fn get_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<Option<ScrollIrCache>, AppError> {
        self.kv.get_ir_cache(file_path, chapter_index)
    }

    /// 使指定书籍的所有 IR 缓存失效
    /// 块分页 sled 缓存已移除；scroll IR 按 file_path+chapter_index 键存储，
    /// 不会被 book 删除影响（孤立条目无害）。
    pub fn invalidate_book_cache(&self, _book_id: &str) -> Result<(), AppError> {
        Ok(())
    }
}
