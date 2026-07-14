// ============================================================
// 文件作用：排版结果持久化缓存（sled KV store）读写。
//
// 公有类型/函数：（无，模块为 crate-private）
//
// 私有函数：
//   - try_get_scroll_ir_cached() — 从 sled 加载 Scroll IR 缓存
//   - try_save_scroll_ir_cached() — 保存 Scroll IR 到 sled
// ============================================================

//! 排版结果持久化缓存（KV store）读写。
//!
//! 行为契约：
//! - `try_get`：仅查询，不写入。命中返回 `Some(…)`；未命中 / 错误 / DB 不可用均返回 `None`。
//! - `try_save`：写入失败仅 warn，不影响阅读。

use crate::domain::ChapterContentIr;
use crate::storage::models::ScrollIrCache;
use crate::storage::repos::LayoutCacheRepository;

/// 尝试从 sled 加载 Scroll IR 缓存（无 config_hash 依赖）。
///
/// 命中返回 ；miss / 版本不匹配 / 存储不可用均返回 。
pub(crate) async fn try_get_scroll_ir_cached(
    validated_path: &str,
    chapter_index: i32,
) -> Option<ChapterContentIr> {
    let storage = crate::storage::storage()?;
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    match cache_repo.get_scroll_ir_cache(validated_path, chapter_index) {
        Ok(Some(cache)) => {
            tracing::debug!(
                "scroll_ir_cache HIT: {}#{}",
                validated_path,
                chapter_index
            );
            Some(cache.ir)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("scroll_ir_cache read failed: {}", e);
            None
        }
    }
}

/// 保存 Scroll IR 到 sled（写入失败不影响阅读）。
pub(crate) async fn try_save_scroll_ir_cached(
    validated_path: &str,
    chapter_index: i32,
    ir: &ChapterContentIr,
) {
    let Some(storage) = crate::storage::storage() else {
        return;
    };
    let cache = ScrollIrCache::new(ir.clone());
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_scroll_ir_cache(validated_path, chapter_index, &cache) {
        tracing::warn!("scroll_ir_cache save failed: {}", e);
    }
}
