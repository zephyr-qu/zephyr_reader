// ============================================================
// 文件作用：章节 IR 加载（EPUB spine / TXT 字节界），
//           优先命中 sled scroll_ir_cache，miss 时解析。
//
// 公有类型/函数：
//   - load_chapter_content_ir() — 加载整章 IR
//   - try_get_scroll_ir_cached() (私有) — sled IR 缓存读取
//   - try_save_scroll_ir_cached() (私有) — sled IR 缓存写入
// ============================================================

//! 章节 IR 加载（EPUB spine / TXT 字节界）。
//! IR 缓存逻辑（原 layout_cache）内联于此——缓存 `ChapterContentIr`
//! 避免每次 scroll 重解析 EPUB HTML，非排版缓存。

use crate::domain::{AppError, ChapterContentIr};
use crate::storage::models::{BookFormat, ScrollIrCache};
use crate::storage::repos::LayoutCacheRepository;

use super::chapter_access::{format_from_file_path, get_chapter_bounds};

/// 加载整章 IR（与 `get_chapter_content_rich` / `get_chapter_content_ir` 边界一致）。
///
/// 优先命中 sled `scroll_ir_cache`，miss 时解析并异步写回缓存。
pub async fn load_chapter_content_ir(
    validated_path: &str,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    // 1. Try sled cache
    if let Some(cached) = try_get_scroll_ir_cached(validated_path, chapter_index).await
    {
        return Ok(cached);
    }

    // 2. Cache miss — parse
    let format = format_from_file_path(validated_path)?;
    let (start, end) = get_chapter_bounds(validated_path, chapter_index).await?;
    let path = validated_path.to_string();

    let ir = match format {
        BookFormat::Epub => {
            tokio::task::spawn_blocking(move || {
                crate::parser::epub::get_chapter_content_ir(&path, start, end)
            })
            .await
            .map_err(|e| AppError::TaskPanic {
                task_name: "load_chapter_ir:epub".into(),
                details: e.to_string(),
            })?
        }
        BookFormat::Txt => {
            tokio::task::spawn_blocking(move || {
                crate::parser::txt::get_chapter_content_ir(&path, start, end)
            })
            .await
            .map_err(|e| AppError::TaskPanic {
                task_name: "load_chapter_ir:txt".into(),
                details: e.to_string(),
            })?
        }
    }?;

    // 3. Write-back to cache (fire-and-forget; failure is non-fatal)
    try_save_scroll_ir_cached(validated_path, chapter_index, &ir).await;

    Ok(ir)
}

/// 尝试从 sled 加载 Scroll IR 缓存（无 config_hash 依赖）。
async fn try_get_scroll_ir_cached(
    validated_path: &str,
    chapter_index: i32,
) -> Option<ChapterContentIr> {
    let storage = crate::storage::storage()?;
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    match cache_repo.get_scroll_ir_cache(validated_path, chapter_index) {
        Ok(Some(cache)) => {
            tracing::debug!(
                "scroll_ir_cache HIT: {}#{}",
                validated_path,
                chapter_index,
            );
            Some(cache.ir)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("scroll_ir_cache read failed: {}", e);
            None
        }
    }
}

/// 保存 Scroll IR 到 sled（写入失败不影响阅读）。
async fn try_save_scroll_ir_cached(
    validated_path: &str,
    chapter_index: i32,
    ir: &ChapterContentIr,
) {
    let Some(storage) = crate::storage::storage() else {
        return;
    };
    let cache = ScrollIrCache::new(ir.clone());
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_scroll_ir_cache(validated_path, chapter_index, &cache) {
        tracing::warn!("scroll_ir_cache save failed: {}", e);
    }
}
