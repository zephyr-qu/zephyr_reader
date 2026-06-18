//! `PaginationSession` 生命周期：entry storage + 原子 repaginate + dispose。
//!
//! Phase 3 实施：迁自 `api/core.rs` 的 session 相关 FFI 与内部 helper。

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::domain::{AppError, PaginateResult, TypesetConfig};
use crate::reading::pagination::paginate_chapter;
use crate::reading::streamer_cache::STREAMER_CACHE;
use crate::reading::types::PaginationSessionHandle;
use crate::text::PageStreamer;
use crate::utils::security::validate_file_path;

/// Server-side pagination session entry (file/chapter/config binding).
#[derive(Clone)]
pub(crate) struct PaginationSessionEntry {
    pub(crate) file_path: String,
    pub(crate) chapter_index: i32,
    pub(crate) config: TypesetConfig,
    pub(crate) streamer: PageStreamer,
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

/// Internal helper: re-paginate a session and atomically update config + streamer.
///
/// `config` should already be validated. The old streamer cache entry is
/// evicted when the (path, chapter, hash) key changes, mirroring the dispose
/// strategy so orphans cannot accumulate.
pub(crate) async fn apply_session_repagination(
    session_id: u64,
    entry: PaginationSessionEntry,
    config: Option<TypesetConfig>,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let config = config
        .map(|c| c.validate_and_fix())
        .unwrap_or_else(|| entry.config.clone());
    let old_key = (
        entry.file_path.clone(),
        entry.chapter_index,
        entry.config.config_hash(),
    );

    let result = paginate_chapter(
        entry.file_path.clone(),
        entry.chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let new_key = (
        entry.file_path.clone(),
        entry.chapter_index,
        result.config_hash,
    );
    let streamer = STREAMER_CACHE
        .lock()
        .get(&new_key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("page streamer for session {session_id}"),
        })?;

    if old_key != new_key {
        STREAMER_CACHE.lock().pop(&old_key);
    }

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: entry.file_path,
            chapter_index: entry.chapter_index,
            config,
            streamer,
        },
    );

    Ok(result)
}

/// Create a pagination session and run initial pagination for the chapter.
///
/// Stores `(file_path, chapter_index, config_hash)` server-side so Dart can
/// fetch page text via [get_session_page_content] without repeating path/config args.
pub(crate) async fn create_pagination_session(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let result = paginate_chapter(
        validated_path.clone(),
        chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let session_id = allocate_session_id();
    let streamer_key = (validated_path.clone(), chapter_index, result.config_hash);
    let streamer = STREAMER_CACHE
        .lock()
        .get(&streamer_key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("page streamer for session {session_id}"),
        })?;

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: validated_path,
            chapter_index,
            config,
            streamer,
        },
    );

    Ok((PaginationSessionHandle { session_id }, result))
}

/// Create a pagination session by adopting an existing streamer from cache.
///
/// 1. Look up `STREAMER_CACHE[(path, chapter_index, config_hash)]`
/// 2. **Hit**: allocate a new session id + bind the cached `PageStreamer`,
///    return its descriptors (**no** `paginate_chapter` call).
/// 3. **Miss**: return `AppError::NotFound` — the caller should fall back to
///    `create_pagination_session` + normal load.
pub(crate) async fn create_pagination_session_adopt(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let key = (validated_path.clone(), chapter_index, config_hash);

    let streamer = STREAMER_CACHE
        .lock()
        .get(&key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!(
                "page streamer for chapter {chapter_index} (config_hash={config_hash:016x})"
            ),
        })?;

    let descriptors = streamer.get_descriptors();
    let is_partial = streamer.is_partial;

    let session_id = allocate_session_id();
    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: validated_path,
            chapter_index,
            config,
            streamer,
        },
    );

    Ok((
        PaginationSessionHandle { session_id },
        PaginateResult {
            descriptors,
            config_hash,
            is_partial,
        },
    ))
}

/// Re-paginate an existing session with a new config in-place.
/// `max_chars` is `None` to expand to full chapter.
pub(crate) async fn repaginate_session(
    handle: PaginationSessionHandle,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    apply_session_repagination(handle.session_id, entry, Some(config), max_chars).await
}

/// Expand session to full chapter.
/// `config = None` reuses the entry's stored config; `Some(c)` swaps in new
/// config first (delegates to [repaginate_session]).
pub(crate) async fn paginate_session_full(
    handle: PaginationSessionHandle,
    config: Option<TypesetConfig>,
) -> Result<PaginateResult, AppError> {
    if let Some(cfg) = config {
        return repaginate_session(handle, cfg, None).await;
    }
    let entry = lookup_pagination_session(handle.session_id)?;
    apply_session_repagination(handle.session_id, entry, None, None).await
}

/// Get page content by session handle (sync).
/// Throws `AppError` if session not found.
pub(crate) fn get_session_page_content(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<String, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    Ok(entry
        .streamer
        .get_page(page_index as usize, entry.chapter_index)
        .map(|p| p.content)
        .unwrap_or_default())
}

/// Dispose pagination session.
pub(crate) fn dispose_pagination_session(
    handle: PaginationSessionHandle,
) -> Result<(), AppError> {
    let entry = SESSION_MAP
        .lock()
        .remove(&handle.session_id)
        .ok_or_else(|| AppError::NotFound {
            entity: format!("pagination session {}", handle.session_id),
        })?;

    // Evict the streamer from STREAMER_CACHE — the entry holds its own clone
    let streamer_key = (entry.file_path, entry.chapter_index, entry.config.config_hash());
    STREAMER_CACHE.lock().pop(&streamer_key);

    Ok(())
}
