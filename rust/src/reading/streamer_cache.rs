//! `STREAMER_CACHE` — `(file_path, chapter_index, config_hash) → PageStreamer` LRU。
//!
//! 分页结果缓存：保存分页后的 `PageStreamer`（惰性按页返回文本），容量 4。
//! 用于「同一章节不同请求间共享分页结果」与「session dispose 时清理」。
//!
//! 行为契约：
//! - `put` 直接覆盖（不会因并发 put 而丢值，调用方负责去重）。
//! - `get` / `pop` / `contains` 都只持锁一瞬间。
//! - `parking_lot::MutexGuard` 不是 Send，锁内仅 `get`/`put`/`pop`/`contains`，不跨 `await`。

use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::LazyLock;

use lru::LruCache;

use crate::text::PageStreamer;

// M7 fix: 4 → 16 匹配 PROVIDER_CACHE。13 个 pagination_session_test
// 并行下 4 不够,频繁 LRU 淘汰导致测试 flake("NotFound: page streamer
// for session N")。真实用户多 chapter 翻页同样受益。
const STREAMER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

pub(crate) type StreamerKey = (String, i32, u64);

pub(crate) static STREAMER_CACHE: LazyLock<Mutex<LruCache<StreamerKey, PageStreamer>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(STREAMER_CACHE_CAPACITY)));

/// 插入或覆盖指定 key 的 streamer。
#[allow(dead_code)] // Phase 2 接入：替代 core.rs 内的 STREAMER_CACHE.lock().put
pub(crate) fn put_streamer(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
    streamer: PageStreamer,
) {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    STREAMER_CACHE.lock().put(key, streamer);
}

/// 获取指定 key 的 streamer（克隆，调用方拥有独立 PageStreamer）。
#[allow(dead_code)] // Phase 2 接入
pub(crate) fn get_streamer(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> Option<PageStreamer> {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    STREAMER_CACHE.lock().get(&key).cloned()
}

/// 检查 key 是否存在。
#[allow(dead_code)] // Phase 2 接入
pub(crate) fn contains_streamer(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> bool {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    STREAMER_CACHE.lock().contains(&key)
}

/// 弹出指定 key 的 streamer（dispose/repaginate 旧 key 时使用）。
#[allow(dead_code)] // Phase 2 接入
pub(crate) fn pop_streamer(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> Option<PageStreamer> {
    let key = (validated_path.to_string(), chapter_index, config_hash);
    STREAMER_CACHE.lock().pop(&key)
}
