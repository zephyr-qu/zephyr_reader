//! `BLOCK_CACHE` — `(file_path, chapter_index, config_hash) → BlockPaginationState` LRU。
//!
//! 与 [`super::streamer_cache::STREAMER_CACHE`] 并行；含 Image 块的全章分页走块路径时使用。

use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::LazyLock;

use lru::LruCache;

use super::block_state::BlockPaginationState;

const BLOCK_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

pub(crate) type BlockCacheKey = (String, i32, u64);

pub(crate) static BLOCK_CACHE: LazyLock<Mutex<LruCache<BlockCacheKey, BlockPaginationState>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(BLOCK_CACHE_CAPACITY)));

pub(crate) fn put_block_state(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
    state: BlockPaginationState,
) {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    BLOCK_CACHE.lock().put(key.clone(), state);
    // Block 路径生效时驱逐 stale plain streamer，避免 get_page_content 误读。
    super::streamer_cache::STREAMER_CACHE.lock().pop(&key);
}

/// 是否已有块分页状态（`get_page_content` 优先 block 路径）。
pub(crate) fn has_block_state(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> bool {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    BLOCK_CACHE.lock().peek(&key).is_some()
}

pub(crate) fn pop_block_state(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> Option<BlockPaginationState> {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    BLOCK_CACHE.lock().pop(&key)
}
