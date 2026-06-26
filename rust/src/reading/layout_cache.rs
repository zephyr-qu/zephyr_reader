//! 排版结果持久化缓存（KV store）读写。
//!
//! 全章分页结果保存在 sled KV 中，跨进程复用，避免每次分页都重做 CPU 排版。
//! - plain 路径：`LayoutCache` → `Vec<PageContent>`
//! - block 路径（P3-6）：`BlockLayoutCache` → IR + `BlockPaginateResult`
//!
//! 缓存键 = `(book_id, chapter_index, chunk_index, config_hash)`，值 = 分页索引。
//!
//! 行为契约：
//! - `try_get`：仅查询，不写入。命中返回 `Some(pages)`；未命中 / 错误 / DB 不可用均返回 `None`。
//! - `try_save`：写入失败仅 warn，不影响阅读。
//! - 文件路径 → book_id 通过 `BookRepository::find_by_file_path` 反查，每本书一次。

use crate::domain::PageContent;
use crate::domain::{BlockPaginateResult, ChapterContentIr};
use crate::storage::models::{BlockLayoutCache, LayoutCache, LayoutCacheKey, ScrollIrCache};
use crate::storage::repos::{BookRepository, LayoutCacheRepository};
use crate::storage::storage_pool;

/// 尝试从持久化缓存获取分页结果。
///
/// 缓存键由 `(book_id, chapter_index, chunk_index, config_hash)` 组成。返回 `None` 当：
/// - DB 不可用 / 读取失败 / 找不到 book / 缓存 miss
pub(crate) async fn try_get_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
) -> Option<Vec<PageContent>> {
    let pool = match storage_pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] miss: pool unavailable: {e}");
            return None;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return None,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] miss: book lookup failed: {e}");
            return None;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id.clone(),
        chapter_index,
        chunk_index,
        config_hash,
    };
    let storage = crate::storage::storage()?;
    let kv = storage.kv();
    let cache_repo = LayoutCacheRepository::new(kv);
    match cache_repo.get_layout_cache(&cache_key) {
        Ok(Some(cache)) => {
            tracing::debug!("cache[{chunk_index:?}] HIT: {}", cache_key);
            Some(cache.pages)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] read failed: {}", e);
            None
        }
    }
}

/// 保存排版结果到缓存（写入失败不影响阅读）。
pub(crate) async fn try_save_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
    pages: Vec<PageContent>,
) {
    let storage = match crate::storage::storage() {
        Some(s) => s,
        None => return,
    };
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] save skipped: pool unavailable: {e}");
            return;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] save skipped: book lookup failed: {e}");
            return;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id,
        chapter_index,
        chunk_index,
        config_hash,
    };
    let cache = LayoutCache::new(config_hash, pages);
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_layout_cache(&cache_key, &cache) {
        tracing::warn!("cache[{chunk_index:?}] save failed: {}", e);
    }
}

async fn resolve_book_id(validated_path: &str, chunk_index: Option<u32>) -> Option<String> {
    let pool = storage_pool().ok()?;
    match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => Some(b.book_id),
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] miss: book lookup failed: {e}");
            None
        }
    }
}

fn layout_cache_key(
    book_id: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
) -> LayoutCacheKey {
    LayoutCacheKey {
        book_id: book_id.to_string(),
        chapter_index,
        chunk_index,
        config_hash,
    }
}

/// 尝试从 sled 加载块分页索引（IR + descriptors）。
/// `chunk_index` 为 `None` 时查询非 chunked 缓存；为 `Some(n)` 时查询第 n 个 chunk。
pub(crate) async fn try_get_block_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
) -> Option<(ChapterContentIr, BlockPaginateResult)> {
    let book_id = resolve_book_id(validated_path, chunk_index).await?;
    let cache_key = layout_cache_key(&book_id, chapter_index, chunk_index, config_hash);
    let storage = crate::storage::storage()?;
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    match cache_repo.get_block_layout_cache(&cache_key) {
        Ok(Some(cache)) => {
            tracing::debug!("block_cache[{}] HIT: {}", chunk_index.map_or("full".into(), |c| c.to_string()), cache_key);
            Some((cache.ir, cache.result))
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("block_cache[{}] read failed: {}", chunk_index.map_or("full".into(), |c| c.to_string()), e);
            None
        }
    }
}

/// 保存块分页索引到 sled（partial 或写入失败不影响阅读）。
/// `chunk_index` 为 `None` 时作为非 chunked 缓存保存；为 `Some(n)` 时保存第 n 个 chunk。
pub(crate) async fn try_save_block_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
    ir: ChapterContentIr,
    result: BlockPaginateResult,
) {
    if result.is_partial {
        return;
    }
    let Some(book_id) = resolve_book_id(validated_path, chunk_index).await else {
        return;
    };
    let Some(storage) = crate::storage::storage() else {
        return;
    };
    let cache_key = layout_cache_key(&book_id, chapter_index, chunk_index, config_hash);
    let cache = BlockLayoutCache::new(config_hash, ir, result);
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_block_layout_cache(&cache_key, &cache) {
        tracing::warn!("block_cache[{}] save failed: {}", chunk_index.map_or("full".into(), |c| c.to_string()), e);
    }
}

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
