// ============================================================
// 文件作用：阅读编排模块（crate-private），将 api/reader.rs 中属于"阅读链"的
//           部分（caches + pagination + session + chapter reads）抽出。
//
// 公有类型/函数：
//   - BookIdCache — book_id 的 LRU 缓存类型（pub type）
//   - BOOK_ID_CACHE — book_id 全局 LRU 缓存（LazyLock）
//
// 私有函数：
//   - clear_for_test() — 清空 BOOK_ID_CACHE（集成测试用）
// ============================================================

//! 阅读编排模块（crate-private）。
//!
//! 把 `api/reader.rs` 中属于"阅读链"的部分（caches + pagination + session + chapter reads）抽出，
//! 留 `api/reader.rs` 为薄 FFI 适配层。Dart/FRB 签名零改动。
//!
//! 内部模块划分：
//! - `provider_cache` — `PROVIDER_CACHE` LRU（章节内容 provider）
//! - `layout_cache` — 持久化分页结果（sled KV）读写
//! - `chapter_access` — 章节边界 + 格式识别 + 章节读取
//! - `chapter_ir` — ContentBlock IR 加载
//! - `orchestrator` — `ReadingOrchestrator` 业务方法入口 + 全局单例
pub mod chapter_access;
pub mod chapter_ir;
pub mod orchestrator;
pub(crate) mod provider_cache;
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

pub(crate) fn clear_for_test() {
    BOOK_ID_CACHE.lock().clear();
}
