//! `PaginationStore` — `(file_path, chapter_index, config_hash) → PaginationEngine` LRU。
//!
//! Phase 2.5：合并原 `STREAMER_CACHE` + `BLOCK_CACHE`；本模块提供统一协调 API。
//!
//! 所有权契约：
//! - `paginate_chapter`：`put` 留副本供 path API / staging
//! - `create_pagination_session`：`attach_for_session`（pop → session 持有，clone 回 LRU）
//! - `create_pagination_session_adopt`：`clone_for_adopt`，session + LRU 各一份
//! - `dispose`：`evict` 移除 LRU 条目

use std::marker::PhantomData;
use std::num::NonZeroUsize;
use std::sync::LazyLock;

use lru::LruCache;
use parking_lot::Mutex;

use crate::domain::{AppError, ChapterPaginationMode, PaginateResult};

use crate::reading::block_state::BlockPaginationState;
use crate::text::PageStreamer;

/// Session / 内存 LRU 持有的分页引擎。
#[derive(Clone)]
pub(crate) enum PaginationEngine {
    Plain(PageStreamer),
    Block(BlockPaginationState),
}


const PAGINATION_ENGINE_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

/// LRU 键：canonical `file_path` + 章索引 + 排版 config hash。
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub(crate) struct PaginationKey {
    pub file_path: String,
    pub chapter_index: i32,
    pub config_hash: u64,
}

impl PaginationKey {
    pub fn new(validated_path: &str, chapter_index: i32, config_hash: u64) -> Self {
        Self {
            file_path: validated_path.to_string(),
            chapter_index,
            config_hash,
        }
    }
}

static PAGINATION_ENGINE_CACHE: LazyLock<Mutex<LruCache<PaginationKey, PaginationEngine>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(PAGINATION_ENGINE_CACHE_CAPACITY)));

static STORE: LazyLock<PaginationStore> = LazyLock::new(PaginationStore::new);

/// 分页引擎内存 LRU 的全局协调入口。
pub(crate) struct PaginationStore {
    _marker: PhantomData<()>,
}

impl PaginationStore {
    const fn new() -> Self {
        Self {
            _marker: PhantomData,
        }
    }

    pub(crate) fn global() -> &'static Self {
        &STORE
    }

    pub(crate) fn entity(chapter_index: i32, config_hash: u64) -> String {
        format!("pagination engine for chapter {chapter_index} (config_hash={config_hash:016x})")
    }

    pub(crate) fn clone_for_adopt(&self, key: &PaginationKey) -> Option<PaginationEngine> {
        PAGINATION_ENGINE_CACHE.lock().get(key).cloned()
    }

    pub(crate) fn put(&self, key: PaginationKey, engine: PaginationEngine) {
        PAGINATION_ENGINE_CACHE.lock().put(key, engine);
    }

    pub(crate) fn pop(&self, key: &PaginationKey) -> Option<PaginationEngine> {
        PAGINATION_ENGINE_CACHE.lock().pop(key)
    }

    pub(crate) fn evict(&self, key: &PaginationKey) {
        PAGINATION_ENGINE_CACHE.lock().pop(key);
    }

    /// 清空内存 LRU（测试用：验证 sled 跨 session 命中）。
#[cfg(test)]
    pub fn clear_lru_for_test(&self) {
        PAGINATION_ENGINE_CACHE.lock().clear();
    }

    /// config 变更时驱逐旧 key（repaginate）。
    pub(crate) fn evict_if_replaced(&self, prior: Option<&PaginationKey>, new_key: &PaginationKey) {
        if let Some(old) = prior {
            if old != new_key {
                self.evict(old);
            }
        }
    }

    /// Pop → 只读借用 → put back（path API 单页读取用）。
    pub(crate) fn with_engine<R>(
        &self,
        key: &PaginationKey,
        f: impl FnOnce(&PaginationEngine) -> Result<R, AppError>,
    ) -> Result<R, AppError> {
        let engine = self.pop(key).ok_or_else(|| AppError::NotFound {
            entity: Self::entity(key.chapter_index, key.config_hash),
        })?;
        let result = f(&engine);
        self.put(key.clone(), engine);
        result
    }

    /// Pop → 检查/变换 → 按需 put back；用于 `paginate_chapter` cache hit 探测。
    pub(crate) fn with_popped<R>(
        &self,
        key: &PaginationKey,
        f: impl FnOnce(PaginationEngine) -> (PaginationEngine, Option<R>),
    ) -> Option<R> {
        let engine = self.pop(key)?;
        let (engine, result) = f(engine);
        self.put(key.clone(), engine);
        result
    }

    /// 全章 block 引擎 cache hit（非 partial）。
    pub(crate) fn try_block_full_hit(&self, key: &PaginationKey) -> Option<PaginateResult> {
        self.with_popped(key, |engine| match engine {
            PaginationEngine::Block(state) if !state.is_partial => {
                let result = state.to_paginate_result(key.config_hash);
                (PaginationEngine::Block(state), Some(result))
            }
            other => (other, None),
        })
    }

    /// 全章 plain 引擎 cache hit（非 partial）。
    pub(crate) fn try_plain_full_hit(&self, key: &PaginationKey) -> Option<PaginateResult> {
        self.with_popped(key, |engine| match engine {
            PaginationEngine::Plain(streamer) if !streamer.is_partial => {
                let descriptors = streamer.get_descriptors();
                (
                    PaginationEngine::Plain(streamer),
                    Some(PaginateResult {
                        descriptors,
                        config_hash: key.config_hash,
                        is_partial: false,
                        mode: ChapterPaginationMode::PlainText,
                    }),
                )
            }
            other => (other, None),
        })
    }

    /// Session 绑定：从 LRU pop 引擎，校验 mode，clone 回 LRU 供 path API / adopt。
    pub(crate) fn attach_for_session(
        &self,
        key: &PaginationKey,
        expected_mode: ChapterPaginationMode,
        prior_key: Option<&PaginationKey>,
    ) -> Result<PaginationEngine, AppError> {
        self.evict_if_replaced(prior_key, key);

        let engine = self.pop(key).ok_or_else(|| AppError::NotFound {
            entity: format!(
                "pagination engine (config_hash={:016x})",
                key.config_hash
            ),
        })?;

        let mode_ok = matches!(
            (&engine, expected_mode),
            (PaginationEngine::Block(_), ChapterPaginationMode::ContentBlocks)
                | (PaginationEngine::Plain(_), ChapterPaginationMode::PlainText)
        );
        if !mode_ok {
            self.put(key.clone(), engine);
            return Err(AppError::InternalError {
                reason: format!(
                    "pagination engine mode mismatch: cache vs expected_mode={expected_mode:?}"
                )
                .into(),
            });
        }

        self.put(key.clone(), engine.clone());
        Ok(engine)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::reading::block_state::BlockPaginationState;
    use crate::domain::TextBlockStyle;
    use crate::domain::{BlockJoinedPlainBuilder, TypesetConfig};
    use crate::text::paginate_chapter_ir;

    fn make_key(file_path: &str, chapter_index: i32, config_hash: u64) -> PaginationKey {
        PaginationKey::new(file_path, chapter_index, config_hash)
    }

    fn make_block_engine() -> PaginationEngine {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Hello World".into(), TextBlockStyle::default());
        let ir = b.finish();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config);
        let state = BlockPaginationState::new(ir, result, false);
        PaginationEngine::Block(state)
    }

    fn make_partial_block_engine() -> PaginationEngine {
        let mut b = BlockJoinedPlainBuilder::new();
        b.push_text("Partial".into(), TextBlockStyle::default());
        let ir = b.finish();
        let config = TypesetConfig::default();
        let result = paginate_chapter_ir(&ir, config);
        let state = BlockPaginationState::new(ir, result, true);
        PaginationEngine::Block(state)
    }

    fn setup() {
        PaginationStore::global().clear_lru_for_test();
    }

    #[test]
    fn put_and_pop_roundtrip() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/book.txt", 0, 0xABCD);
        let engine = make_block_engine();

        store.put(key.clone(), engine.clone());
        let popped = store.pop(&key);

        assert!(popped.is_some());
        // After pop, cache should be empty
        assert!(store.pop(&key).is_none());
    }

    #[test]
    fn pop_nonexistent_returns_none() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/no/such.txt", 99, 0);

        assert!(store.pop(&key).is_none());
    }

    #[test]
    fn evict_removes_entry() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/evict.txt", 0, 0x1234);
        store.put(key.clone(), make_block_engine());

        store.evict(&key);
        assert!(store.pop(&key).is_none());
    }

    #[test]
    fn clone_for_adopt_does_not_remove() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/adopt.txt", 0, 0x5678);
        store.put(key.clone(), make_block_engine());

        let cloned = store.clone_for_adopt(&key);
        assert!(cloned.is_some());
        // Engine should still be in cache after clone_for_adopt
        assert!(store.pop(&key).is_some());
    }

    #[test]
    fn evict_if_replaced_different_key() {
        setup();
        let store = PaginationStore::global();
        let old_key = make_key("/test/old.txt", 0, 0x1111);
        let new_key = make_key("/test/new.txt", 0, 0x2222);
        store.put(old_key.clone(), make_block_engine());

        store.evict_if_replaced(Some(&old_key), &new_key);
        assert!(store.pop(&old_key).is_none());
    }

    #[test]
    fn evict_if_replaced_same_key_keeps() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/same.txt", 0, 0x3333);
        store.put(key.clone(), make_block_engine());

        store.evict_if_replaced(Some(&key), &key);
        assert!(store.pop(&key).is_some());
    }

    #[test]
    fn try_block_full_hit_returns_result() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/full.txt", 0, 0x4444);
        store.put(key.clone(), make_block_engine());

        let hit = store.try_block_full_hit(&key);
        assert!(hit.is_some(), "complete block engine should be a full hit");
        let result = hit.unwrap();
        assert!(!result.is_partial);
        assert_eq!(result.mode, ChapterPaginationMode::ContentBlocks);
    }

    #[test]
    fn try_block_full_hit_partial_returns_none() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/partial.txt", 0, 0x5555);
        store.put(key.clone(), make_partial_block_engine());

        let hit = store.try_block_full_hit(&key);
        assert!(hit.is_none(), "partial engine should not be a full hit");
    }

    #[test]
    fn try_block_full_hit_nonexistent_returns_none() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/miss.txt", 0, 0x6666);

        assert!(store.try_block_full_hit(&key).is_none());
    }

    #[test]
    fn with_engine_reads_then_restores() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/with_eng.txt", 0, 0x7777);
        store.put(key.clone(), make_block_engine());

        let result = store.with_engine(&key, |_engine| Ok::<_, AppError>(42));
        assert_eq!(result.unwrap(), 42);

        // Engine should be restored to cache
        assert!(store.pop(&key).is_some());
    }

    #[test]
    fn with_engine_nonexistent_returns_not_found() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/no_eng.txt", 0, 0x8888);

        let result: Result<i32, AppError> = store.with_engine(&key, |_| Ok(42));
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), AppError::NotFound { .. }));
    }

    #[test]
    fn attach_for_session_block_mode_ok() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/session.txt", 0, 0x9999);
        store.put(key.clone(), make_block_engine());

        let engine = store.attach_for_session(&key, ChapterPaginationMode::ContentBlocks, None);
        assert!(engine.is_ok());
        // Engine should be cloned back for path API use
        assert!(store.pop(&key).is_some());
    }

    #[test]
    fn attach_for_session_mode_mismatch_returns_error() {
        setup();
        let store = PaginationStore::global();
        let key = make_key("/test/mismatch.txt", 0, 0xAAAA);
        store.put(key.clone(), make_block_engine());

        let engine = store.attach_for_session(&key, ChapterPaginationMode::PlainText, None);
        assert!(engine.is_err());
        // Engine should be restored on mismatch
        assert!(store.pop(&key).is_some());
    }

    #[test]
    fn lru_evicts_oldest_when_full() {
        setup();
        let store = PaginationStore::global();
        // Fill cache to capacity (16) and then add one more
        for i in 0..=16 {
            let key = make_key(&format!("/test/lru_{}.txt", i), 0, 0xBBBB);
            store.put(key, make_block_engine());
        }

        // The first entry (i=0) should be evicted
        let first_key = make_key("/test/lru_0.txt", 0, 0xBBBB);
        assert!(store.pop(&first_key).is_none());

        // The most recent entry (i=16) should still be present
        let last_key = make_key("/test/lru_16.txt", 0, 0xBBBB);
        assert!(store.pop(&last_key).is_some());
    }
}
