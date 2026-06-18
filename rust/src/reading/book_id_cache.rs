//! `BOOK_ID_CACHE` — `file_path → book_id` LRU。
//!
//! 文件路径 → book_id 在单次会话中不变（导入时 `parse_book` 已写入 DB），缓存避免每次分页/读取都
//! `find_by_file_path` 查 DB。容量 16。
//!
//! 行为契约：
//! - 命中：返回缓存 book_id 的 clone。
//! - 未命中：调用方在锁外查 DB 后 `put`。
//! - `parking_lot::MutexGuard` 不是 Send，锁内只 `get`/`put`，不跨 `await`。

use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::LazyLock;

use lru::LruCache;

const BOOK_ID_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

pub(crate) type BookIdCache = LruCache<String, String>;  // file_path → book_id

pub static BOOK_ID_CACHE: LazyLock<Mutex<BookIdCache>> =
    LazyLock::new(|| Mutex::new(LruCache::new(BOOK_ID_CACHE_CAPACITY)));

/// 命中则返回 book_id 的 clone；未命中返回 None。
#[allow(dead_code)] // Phase 2+ 接入
pub(crate) fn get_book_id(validated_path: &str) -> Option<String> {
    let mut cache = BOOK_ID_CACHE.lock();
    cache.get(validated_path).cloned()
}

/// 写入 book_id 缓存。
#[allow(dead_code)] // Phase 2+ 接入
pub(crate) fn put_book_id(validated_path: &str, book_id: String) {
    let mut cache = BOOK_ID_CACHE.lock();
    cache.put(validated_path.to_string(), book_id);
}
pub(crate) fn clear_for_test() {
    BOOK_ID_CACHE.lock().clear();
}
