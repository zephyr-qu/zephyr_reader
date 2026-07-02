//! 阅读编排模块（crate-private）。
//!
//! 把 `api/core.rs` 中属于"阅读链"的部分（caches + pagination + session + chapter reads）抽出，
//! 留 `api/core.rs` 为薄 FFI 适配层。Dart/FRB 签名零改动。
//!
//! 内部模块划分：
//! - `provider_cache` — `PROVIDER_CACHE` LRU（章节内容 provider）
//! - `pagination_store` — `PaginationStore` 全局 LRU（plain / block 分页引擎 + 协调 API）
//! - `layout_cache` — 持久化分页结果（sled KV）读写
//! - `chapter_access` — 章节边界 + 格式识别 + 章节读取（Phase 1 迁边界/格式，Phase 4 迁读取）
//! - `pagination` — 分页 API（`paginate_chapter` / `paginate_all_content` / `get_page_content`）
//! - `session` — `PaginationSession` 生命周期
//! - `orchestrator` — `ReadingOrchestrator` 业务方法入口 + 全局单例
//! - `types` — FRB-exposed types（`PaginationSessionHandle`）
pub mod block_state;
pub mod chapter_access;
pub mod chapter_ir;
pub(crate) mod layout_cache;
pub mod orchestrator;
pub(crate) mod pagination;
pub(crate) mod pagination_store;
pub(crate) mod provider_cache;
pub(crate) mod session;
pub mod types;

// ── book_id_cache (inlined) ──
use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::LazyLock;

use lru::LruCache;

const BOOK_ID_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

pub type BookIdCache = LruCache<String, String>;

pub static BOOK_ID_CACHE: LazyLock<Mutex<BookIdCache>> =
    LazyLock::new(|| Mutex::new(LruCache::new(BOOK_ID_CACHE_CAPACITY)));

#[cfg(test)]
pub(crate) fn clear_for_test() {
    BOOK_ID_CACHE.lock().clear();
}
