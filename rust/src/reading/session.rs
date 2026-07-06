//! `PaginationSession` 生命周期：entry storage + 原子 repaginate + dispose。
//!
//! Phase 3 实施：迁自 `api/core.rs` 的 session 相关 FFI 与内部 helper。
//! M3：单路径 — `BlockPaginationState`（含 Image IR）。

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::domain::{
    AppError, ChapterPaginationMode, PageBlockSlice, PaginateResult, TypesetConfig,
};
use crate::reading::pagination::paginate_chapter;
use crate::reading::pagination_store::PaginationEngine;
use crate::reading::pagination_store::{PaginationKey, PaginationStore};
use crate::reading::types::PaginationSessionHandle;
use crate::utils::security::validate_file_path;

/// Server-side pagination session entry (book/chapter/config binding).
/// M2: `book_id` 新增（ADR-014），`file_path` 保留为内部文件操作使用。
#[derive(Clone)]
pub(crate) struct PaginationSessionEntry {
    pub(crate) book_id: String,
    pub(crate) file_path: String,
    pub(crate) chapter_index: i32,
    pub(crate) config: TypesetConfig,
    pub(crate) engine: PaginationEngine,
}

impl PaginationSessionEntry {
    fn config_hash(&self) -> u64 {
        self.config.config_hash()
    }

    fn cache_key(&self) -> PaginationKey {
        PaginationKey::new(&self.book_id, self.chapter_index, self.config_hash())
    }
}

static NEXT_SESSION_ID: AtomicU64 = AtomicU64::new(1);

static SESSION_MAP: LazyLock<Mutex<HashMap<u64, PaginationSessionEntry>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub(crate) fn allocate_session_id() -> u64 {
    NEXT_SESSION_ID.fetch_add(1, Ordering::Relaxed)
}

pub(crate) fn lookup_pagination_session(
    session_id: u64,
) -> Result<PaginationSessionEntry, AppError> {
    SESSION_MAP
        .lock()
        .get(&session_id)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("pagination session {session_id}"),
        })
}

fn engine_from_paginate_result(
    book_id: &str,
    chapter_index: i32,
    result: &PaginateResult,
    old_key: Option<PaginationKey>,
) -> Result<PaginationEngine, AppError> {
    let key = PaginationKey::new(book_id, chapter_index, result.config_hash);
    PaginationStore::global().attach_for_session(
        &key,
        result.mode,
        old_key.as_ref(),
    )
}

/// Internal helper: re-paginate a session and atomically update config + engine.
pub(crate) async fn apply_session_repagination(
    session_id: u64,
    entry: PaginationSessionEntry,
    config: Option<TypesetConfig>,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let config = config
        .map(|c| c.validate_and_fix())
        .unwrap_or_else(|| entry.config.clone());
    let old_key = entry.cache_key();

    let result = paginate_chapter(
        &entry.book_id,
        entry.file_path.clone(),
        entry.chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let engine = engine_from_paginate_result(
        &entry.book_id,
        entry.chapter_index,
        &result,
        Some(old_key),
    )?;

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            book_id: entry.book_id,
            file_path: entry.file_path,
            chapter_index: entry.chapter_index,
            config,
            engine,
        },
    );

    Ok(result)
}

/// Create a pagination session and run initial pagination for the chapter.
/// M2: `book_id` 用于 PaginationKey，`file_path` 由 orchestrator 预解析（ADR-014）。
pub(crate) async fn create_pagination_session(
    book_id: String,
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let result = paginate_chapter(
        &book_id,
        validated_path.clone(),
        chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let session_id = allocate_session_id();
    let engine = engine_from_paginate_result(
        &book_id,
        chapter_index,
        &result,
        None,
    )?;

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            book_id: book_id.clone(),
            file_path: validated_path,
            chapter_index,
            config,
            engine,
        },
    );

    Ok((PaginationSessionHandle { session_id }, result))
}

/// Create a pagination session by adopting an existing engine from cache.
/// M2: `book_id` 用于 PaginationKey，`file_path` 由 orchestrator 预解析（ADR-014）。
pub(crate) async fn create_pagination_session_adopt(
    book_id: String,
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let key = PaginationKey::new(&book_id, chapter_index, config_hash);

    let Some(engine) = PaginationStore::global().clone_for_adopt(&key) else {
        return Err(AppError::NotFound {
            entity: PaginationStore::entity(chapter_index, config_hash),
        });
    };

    let (descriptors, is_partial, mode) = match &engine {
    PaginationEngine::Block(state) => {
            let result = state.to_paginate_result(config_hash);
            (
                result.descriptors,
                result.is_partial,
                ChapterPaginationMode::ContentBlocks,
            )
        }
    };

    let session_id = allocate_session_id();
    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            book_id: book_id.clone(),
            file_path: validated_path,
            chapter_index,
            config,
            engine,
        },
    );

    Ok((
        PaginationSessionHandle { session_id },
        PaginateResult {
            descriptors,
            config_hash,
            is_partial,
            mode,
        },
    ))
}

/// Re-paginate an existing session with a new config in-place.
pub(crate) async fn repaginate_session(
    handle: PaginationSessionHandle,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    apply_session_repagination(handle.session_id, entry, Some(config), max_chars).await
}

/// Apply Flutter-measured calibration to an existing session and repaginate in-place.
pub(crate) async fn apply_session_calibration(
    handle: PaginationSessionHandle,
    calibration: crate::domain::types::typeset::TypesetCalibration,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    let mut config = entry.config.clone();
    config.calibration = Some(calibration);
    apply_session_repagination(handle.session_id, entry, Some(config), max_chars).await
}

/// Expand session to full chapter.
///
/// P0: 当 session 持有 partial `BlockPaginationState` 时，直接用缓存的完整 IR
/// 调用 `expand_to_full`，避免重新从磁盘加载 IR 再分页。
pub(crate) async fn paginate_session_full(
    handle: PaginationSessionHandle,
    config: Option<TypesetConfig>,
) -> Result<PaginateResult, AppError> {
    if let Some(cfg) = config {
        return repaginate_session(handle, cfg, None).await;
    }
    let mut entry = lookup_pagination_session(handle.session_id)?;
    let session_id = handle.session_id;

    // P0: partial block state → 用缓存的完整 IR expand，跳过磁盘 IO
    if let PaginationEngine::Block(ref state) = entry.engine
        && state.is_partial {
            let mut state = state.clone();
            let result = state.expand_to_full(entry.config.clone()).await?;
            // 同步更新 PaginationStore LRU（path API / adopt 需要）
            let cache_key = entry.cache_key();
            PaginationStore::global().put(
                cache_key,
                PaginationEngine::Block(state.clone()),
            );
            entry.engine = PaginationEngine::Block(state);
            SESSION_MAP.lock().insert(session_id, entry);
            return Ok(result);
        }

    apply_session_repagination(session_id, entry, None, None).await
}

fn session_page_entity(page_index: i32) -> String {
    format!("session page {page_index}")
}

/// Get page content by session handle (sync).
pub(crate) fn get_session_page_content(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<String, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    match &entry.engine {
        PaginationEngine::Block(state) => state
            .page_plain_text(page_index as usize)
            .ok_or_else(|| AppError::NotFound {
                entity: session_page_entity(page_index),
            }),
    }
}

/// M3.2：按 session 获取页内块列表（`ContentBlocks` 模式）。
pub(crate) fn get_session_page_blocks(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<Vec<PageBlockSlice>, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    match &entry.engine {
        PaginationEngine::Block(state) => state
            .page_blocks(page_index as usize)
            .ok_or_else(|| AppError::NotFound {
                entity: session_page_entity(page_index),
            }),
    }
}

/// M3.4：`charOffset` → `pageIndex`（block 模式精确；plain 模式用 descriptor 字节 offset 近似）。
pub(crate) fn session_char_offset_to_page_index(
    handle: PaginationSessionHandle,
    char_offset: i32,
) -> Result<i32, AppError> {
    if char_offset < 0 {
        return Err(AppError::InvalidInput {
            reason: "char_offset must be non-negative".into(),
        });
    }
    let offset = char_offset as u32;
    let entry = lookup_pagination_session(handle.session_id)?;
    match &entry.engine {
        PaginationEngine::Block(state) => state
            .char_offset_to_page_index(offset)
            .ok_or_else(|| AppError::NotFound {
                entity: format!("page for char_offset {char_offset}"),
            }),
    }
}

/// Dispose pagination session.
pub(crate) fn dispose_pagination_session(
    handle: PaginationSessionHandle,
) -> Result<(), AppError> {
    let mut session_map = SESSION_MAP.lock();
    let session_id = handle.session_id;
    let cache_key = session_map
        .get(&session_id)
        .map(|e| e.cache_key())
        .ok_or_else(|| AppError::NotFound {
            entity: format!("pagination session {}", session_id),
        })?;

    PaginationStore::global().evict(&cache_key);
    session_map.remove(&session_id);
    Ok(())
}
