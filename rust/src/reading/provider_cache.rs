//! `PROVIDER_CACHE` — `(file_path, chapter_index, format) → Arc<dyn ChapterContentProvider>` LRU。
//!
//! 章节内容提供器缓存，避免每次分页/章节读取都重新打开文件、解析目录、扫描 spine。
//! 容量 16，命中后直接 `Arc::clone` 出去。
//!
//! 行为契约（与 god module 阶段一致）：
//! - 命中：返回缓存值的 clone，不重新构建。
//! - 未命中：调用方在 `provider_cache` 之外构造 provider 后 put（去重由调用方保证）。
//! - `parking_lot::MutexGuard` 不是 Send，锁内只 `get`/`put`，不跨 `await`。

use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::{Arc, LazyLock};

use lru::LruCache;

use crate::domain::AppError;
use crate::parser::provider::ChapterContentProvider;
use crate::storage::models::BookFormat;

const PROVIDER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

// M9 fix: include `BookFormat` in the key. Without it, a cache hit
// for `(path, chapter_index)` could theoretically return a provider
// built for a different format if the file's format somehow changed
// (not currently possible — format is determined by file extension
// at import and never mutates — but the invariant should be explicit).
// Also: 3-tuple is `Eq + Hash` so the LRU key keeps the same
// behavior, and `BookFormat` is a small Copy enum.
pub(crate) type CacheKey = (String, i32, BookFormat);

pub(crate) static PROVIDER_CACHE: LazyLock<Mutex<LruCache<CacheKey, Arc<dyn ChapterContentProvider>>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(PROVIDER_CACHE_CAPACITY)));


/// 清空 provider LRU（仅供测试使用）。
pub(crate) fn clear_for_test() {
    PROVIDER_CACHE.lock().clear();
}

/// 从 LRU 缓存获取或创建 Provider
pub(crate) async fn get_or_create_provider(
    validated_path: &str,
    chapter_index: i32,
    format: &BookFormat,
) -> Result<Arc<dyn ChapterContentProvider>, AppError> {
    // M9 fix: include `format` in cache key (see CacheKey doc).
    let cache_key = (validated_path.to_string(), chapter_index, *format);
    {
        let mut cache = PROVIDER_CACHE.lock();
        if let Some(cached) = cache.get(&cache_key) {
            return Ok(cached.clone());
        }
    }

    let p: Arc<dyn ChapterContentProvider> = match format {
        BookFormat::Txt => {
            let path = validated_path.to_string();
            let provider = tokio::task::spawn_blocking(move || {
                crate::parser::txt::TxtContentProvider::open(&path)
            })
            .await
            .map_err(|e| AppError::TaskPanic { task_name: "txt provider".into(), details: e.to_string().into() })??;
            Arc::new(provider)
        }
        BookFormat::Epub => {
            // Fetch spine bounds from DB *before* spawn_blocking —
            // get_chapter_bounds is async (DB query).
            let (start_idx, end_idx) = super::chapter_access::get_chapter_bounds(validated_path, chapter_index).await?;
            // Detect stale pre-migration books: start/end both DEFAULT 0
            if start_idx == 0 && end_idx == 0 {
                return Err(AppError::StaleBookData {
                    message: "Chapter bounds missing. Please re-import this book.".into(),
                });
            }
            let path = validated_path.to_string();
            let provider = tokio::task::spawn_blocking(move || {
                crate::parser::epub::provider::EpubContentProvider::open_from_bounds(
                    &path, start_idx, end_idx,
                )
            })
            .await
            .map_err(|e| AppError::TaskPanic { task_name: "epub provider".into(), details: e.to_string().into() })??;
            Arc::new(provider)
        }
    };

    let mut cache = PROVIDER_CACHE.lock();
    if !cache.contains(&cache_key) {
        cache.put(cache_key, p.clone());
    }
    Ok(p)
}
