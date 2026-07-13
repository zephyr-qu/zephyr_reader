//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据。

use std::path::Path;

use crate::domain::AppError;

use super::models::ScrollIrCache;

const SCROLL_IR_TREE_NAME: &str = "scroll_ir_cache";

/// sled 磁盘缓存条目上限。超过时按版本/key 顺序淘汰。
const SCROLL_IR_MAX_ENTRIES: usize = 256;

/// KV 存储封装
pub struct KvStore {
    /// sled 数据库句柄 — 不会被直接读取，仅用于保活。
    /// 一旦 db 被 drop，tree 会成为悬空指针。
    #[allow(dead_code)]
    db: sled::Db,
    scroll_ir_cache: sled::Tree,
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self, AppError> {
        let db = sled::open(path).map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to open sled database: {e}"),
        })?;
        let scroll_ir_cache =
            db.open_tree(SCROLL_IR_TREE_NAME)
                .map_err(|e| AppError::DatabaseError {
                    reason: format!("Failed to open scroll ir tree: {e}"),
                })?;
        Ok(Self {
            db,
            scroll_ir_cache,
        })
    }

    /// 刷盘
    pub fn flush(&self) -> Result<(), AppError> {
        self.db.flush().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to flush sled database: {e}"),
        })?;
        Ok(())
    }

    /// 存储 Scroll IR 缓存（key = `{file_path}#{chapter_index}`）。
    pub fn save_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        value: &ScrollIrCache,
    ) -> Result<(), AppError> {
        let key = format!("{}#{}", file_path, chapter_index);
        let bytes = bincode::encode_to_vec(value, bincode::config::standard()).map_err(|e| {
            AppError::DatabaseError {
                reason: format!("Failed to serialize scroll ir: {e}"),
            }
        })?;
        self.scroll_ir_cache
            .insert(key, bytes)
            .map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to insert scroll ir cache: {e}"),
            })?;
        self.enforce_scroll_ir_capacity()?;
        Ok(())
    }

    /// 获取 Scroll IR 缓存；版本不匹配视为 miss。
    pub fn get_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<Option<ScrollIrCache>, AppError> {
        let key = format!("{}#{}", file_path, chapter_index);
        match self
            .scroll_ir_cache
            .get(&key)
            .map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to read scroll ir cache: {e}"),
            })? {
            Some(bytes) => match bincode::decode_from_slice::<ScrollIrCache, _>(
                &bytes,
                bincode::config::standard(),
            ) {
                Ok((cache, _)) if cache.is_valid() => Ok(Some(cache)),
                Ok(_) => Ok(None),
                Err(e) => {
                    tracing::warn!("ScrollIrCache deserialize failed (corrupted?): {}", e);
                    Ok(None)
                }
            },
            None => Ok(None),
        }
    }

    /// 容量淘汰：当 scroll_ir_cache 条目超过上限时，按版本号淘汰无效条目，再按 key 顺序淘汰最旧。
    fn enforce_scroll_ir_capacity(&self) -> Result<(), AppError> {
        let len = self.scroll_ir_cache.len();
        if len <= SCROLL_IR_MAX_ENTRIES {
            return Ok(());
        }
        let mut valid_keys: Vec<sled::IVec> = Vec::new();
        let mut stale_keys: Vec<sled::IVec> = Vec::new();
        for item in self.scroll_ir_cache.iter() {
            let (key, value) = item.map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to read from sled: {e}"),
            })?;
            if let Ok((cache, _)) =
                bincode::decode_from_slice::<ScrollIrCache, _>(&value, bincode::config::standard())
            {
                if cache.is_valid() {
                    valid_keys.push(key);
                } else {
                    stale_keys.push(key);
                }
            }
        }
        for key in &stale_keys {
            self.scroll_ir_cache
                .remove(key)
                .map_err(|e| AppError::DatabaseError {
                    reason: format!("Failed to evict stale scroll ir: {e}"),
                })?;
        }
        let remaining = self.scroll_ir_cache.len();
        if remaining > SCROLL_IR_MAX_ENTRIES {
            let to_evict = remaining - SCROLL_IR_MAX_ENTRIES;
            for key in valid_keys.iter().take(to_evict) {
                self.scroll_ir_cache
                    .remove(key)
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to evict scroll ir: {e}"),
                    })?;
            }
            tracing::info!(
                "Evicted {to_evict} scroll_ir_cache entries (stale: {stale_count}, was {len}, max {SCROLL_IR_MAX_ENTRIES})",
                stale_count = stale_keys.len()
            );
        } else if !stale_keys.is_empty() {
            tracing::info!(
                "Evicted {stale_count} stale scroll_ir_cache entries (was {len}, now {remaining})",
                stale_count = stale_keys.len()
            );
        }
        Ok(())
    }
}
