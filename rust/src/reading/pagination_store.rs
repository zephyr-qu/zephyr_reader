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

use super::pagination_engine::PaginationEngine;

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
