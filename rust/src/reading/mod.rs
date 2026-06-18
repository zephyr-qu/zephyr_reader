//! 阅读编排模块（crate-private）。
//!
//! 把 `api/core.rs` 中属于"阅读链"的部分（caches + pagination + session + chapter reads）抽出，
//! 留 `api/core.rs` 为薄 FFI 适配层。Dart/FRB 签名零改动。
//!
//! 内部模块划分：
//! - `book_id_cache` — `BOOK_ID_CACHE` LRU（file_path → book_id）
//! - `provider_cache` — `PROVIDER_CACHE` LRU（章节内容 provider）
//! - `streamer_cache` — `STREAMER_CACHE` LRU（分页结果 streamer）
//! - `layout_cache` — 持久化分页结果（sled KV）读写
//! - `chapter_access` — 章节边界 + 格式识别 + 章节读取（Phase 1 迁边界/格式，Phase 4 迁读取）
//! - `pagination` — 分页 API（`paginate_chapter` / `paginate_all_content` / `get_page_content`）
//! - `session` — `PaginationSession` 生命周期
//! - `orchestrator` — `ReadingOrchestrator` 业务方法入口 + 全局单例
//! - `types` — FRB-exposed types（`PaginationSessionHandle`）

pub mod book_id_cache;
pub mod chapter_access;
pub(crate) mod layout_cache;
pub mod orchestrator;
pub(crate) mod pagination;
pub(crate) mod provider_cache;
pub(crate) mod session;
pub(crate) mod streamer_cache;
pub mod types;
