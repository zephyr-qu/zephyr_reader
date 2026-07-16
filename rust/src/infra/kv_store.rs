// ============================================================
// 文件作用：KV 存储（redb），用于排版缓存等高频读写临时数据
//
// 公有类型/函数：
//   - KvStore — redb 封装
//   - new() / flush() — 生命周期
//   - save_ir_cache() / get_ir_cache() — IR 缓存
//   - delete_ir_cache_by_prefix() — 按 key 前缀批量删除
//
// 私有函数：
//   - enforce_scroll_ir_capacity() — 容量淘汰
// ============================================================

//! KV 存储（redb）
//!
//! 用于排版缓存等高频读写、可重建的临时数据。

use std::path::Path;

use crate::common::AppError;
use flutter_rust_bridge::frb;
use redb::{Database, ReadableTable, TableDefinition};

const SCROLL_IR_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("scroll_ir_cache");

/// redb 磁盘缓存条目上限。超过时按 key 顺序淘汰最旧。
const SCROLL_IR_MAX_ENTRIES: usize = 256;

/// KV 存储封装
#[frb(opaque)]
pub struct KvStore {
    db: Database,
}

/// Scroll IR 缓存格式版本。
pub const SCROLL_IR_CACHE_VERSION: u8 = 1;

/// Scroll 路径章 IR 缓存（无 config_hash 依赖；跨 session 复用 HTML 解析）。
#[derive(Debug, Clone, PartialEq, bincode::Encode, bincode::Decode)]
pub struct ScrollIrCache {
    pub version: u8,
    pub ir: crate::pipeline::ReaderChapterIr,
    pub created_at: i64,
}

impl ScrollIrCache {
    pub fn new(ir: crate::pipeline::ReaderChapterIr) -> Self {
        Self {
            version: SCROLL_IR_CACHE_VERSION,
            ir,
            created_at: chrono::Utc::now().timestamp(),
        }
    }

    pub fn is_valid(&self) -> bool {
        self.version == SCROLL_IR_CACHE_VERSION
    }
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self, AppError> {
        let db = Database::create(path).map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to open redb database: {e}"),
        })?;
        // 确保表存在
        let write_tx = db.begin_write().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to begin write tx: {e}"),
        })?;
        write_tx
            .open_table(SCROLL_IR_TABLE)
            .map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to open ir table: {e}"),
            })?;
        write_tx.commit().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to commit table creation: {e}"),
        })?;
        Ok(Self { db })
    }

    /// 刷盘（redb 自动 WAL，此方法为兼容旧接口保留）
    pub fn flush(&self) -> Result<(), AppError> {
        // redb 在 commit 时会自动刷盘
        Ok(())
    }

    /// 存储 IR 缓存（key = `{file_path}#{chapter_index}`）。
    pub fn save_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        value: &ScrollIrCache,
    ) -> Result<(), AppError> {
        let key = format!("{}#{}", file_path, chapter_index);
        let bytes = bincode::encode_to_vec(value, bincode::config::standard()).map_err(|e| {
            AppError::DatabaseError {
                reason: format!("Failed to serialize ir: {e}"),
            }
        })?;
        let write_tx = self.db.begin_write().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to begin write tx: {e}"),
        })?;
        {
            let mut table =
                write_tx
                    .open_table(SCROLL_IR_TABLE)
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to open ir table: {e}"),
                    })?;
            table
                .insert(&*key, bytes.as_slice())
                .map_err(|e| AppError::DatabaseError {
                    reason: format!("Failed to insert ir cache: {e}"),
                })?;
        }
        write_tx.commit().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to commit ir cache: {e}"),
        })?;
        self.enforce_scroll_ir_capacity()?;
        Ok(())
    }

    /// 获取 IR 缓存；版本不匹配视为 miss。
    pub fn get_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<Option<ScrollIrCache>, AppError> {
        let key = format!("{}#{}", file_path, chapter_index);
        let read_tx = self.db.begin_read().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to begin read tx: {e}"),
        })?;
        let table = read_tx
            .open_table(SCROLL_IR_TABLE)
            .map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to open ir table: {e}"),
            })?;
        match table
            .get(key.as_str())
            .map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to read ir cache: {e}"),
            })? {
            Some(bytes) => {
                match bincode::decode_from_slice::<ScrollIrCache, _>(
                    bytes.value(),
                    bincode::config::standard(),
                ) {
                    Ok((cache, _)) if cache.is_valid() => Ok(Some(cache)),
                    Ok(_) => Ok(None),
                    Err(e) => {
                        tracing::warn!("ScrollIrCache deserialize failed (corrupted?): {}", e);
                        Ok(None)
                    }
                }
            }
            None => Ok(None),
        }
    }

    /// 按 key 前缀删除所有 IR 缓存条目（用于删书时清缓存）。
    pub fn delete_ir_cache_by_prefix(&self, prefix: &str) -> Result<(), AppError> {
        let write_tx = self.db.begin_write().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to begin write tx: {e}"),
        })?;
        {
            let mut table =
                write_tx
                    .open_table(SCROLL_IR_TABLE)
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to open ir table: {e}"),
                    })?;
            // redb range is [start, end); use prefix as start and a high bound
            let keys_to_remove: Vec<String> = table
                .range(prefix..)
                .map_err(|e| AppError::DatabaseError {
                    reason: format!("Failed to scan ir cache: {e}"),
                })?
                .take_while(|r| r.as_ref().is_ok_and(|(k, _)| k.value().starts_with(prefix)))
                .filter_map(|r| r.ok())
                .map(|(k, _)| k.value().to_string())
                .collect();
            for key in &keys_to_remove {
                table
                    .remove(key.as_str())
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to remove ir cache key: {e}"),
                    })?;
            }
        }
        write_tx.commit().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to commit cache deletion: {e}"),
        })?;
        Ok(())
    }

    /// 容量淘汰：当 scroll_ir_cache 条目超过上限时，按版本号淘汰无效条目，再按 key 顺序淘汰最旧。
    fn enforce_scroll_ir_capacity(&self) -> Result<(), AppError> {
        let write_tx = self.db.begin_write().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to begin eviction write tx: {e}"),
        })?;
        {
            let mut table =
                write_tx
                    .open_table(SCROLL_IR_TABLE)
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to open ir table: {e}"),
                    })?;
            let mut total = 0usize;
            let mut valid_keys: Vec<String> = Vec::new();
            let mut stale_keys: Vec<String> = Vec::new();
            for item in table.iter().map_err(|e| AppError::DatabaseError {
                reason: format!("Failed to iterate ir table: {e}"),
            })? {
                total += 1;
                let (key_bytes, value_bytes) = item.map_err(|e| AppError::DatabaseError {
                    reason: format!("Failed to read from redb: {e}"),
                })?;
                if let Ok((cache, _)) = bincode::decode_from_slice::<ScrollIrCache, _>(
                    value_bytes.value(),
                    bincode::config::standard(),
                ) {
                    if cache.is_valid() {
                        valid_keys.push(key_bytes.value().to_string());
                    } else {
                        stale_keys.push(key_bytes.value().to_string());
                    }
                }
            }
            if total <= SCROLL_IR_MAX_ENTRIES {
                // Drop write_tx without commit to avoid unnecessary WAL write
                return Ok(());
            }
            for key in &stale_keys {
                table
                    .remove(key.as_str())
                    .map_err(|e| AppError::DatabaseError {
                        reason: format!("Failed to evict stale ir: {e}"),
                    })?;
            }
            let remaining = total - stale_keys.len();
            if remaining > SCROLL_IR_MAX_ENTRIES {
                let to_evict = remaining - SCROLL_IR_MAX_ENTRIES;
                for key in valid_keys.iter().take(to_evict) {
                    table
                        .remove(key.as_str())
                        .map_err(|e| AppError::DatabaseError {
                            reason: format!("Failed to evict ir: {e}"),
                        })?;
                }
                tracing::info!(
                    "Evicted {to_evict} scroll_ir_cache entries (stale: {stale_count}, was {total}, max {SCROLL_IR_MAX_ENTRIES})",
                    stale_count = stale_keys.len()
                );
            } else if !stale_keys.is_empty() {
                tracing::info!(
                    "Evicted {stale_count} stale scroll_ir_cache entries (was {total}, now {remaining})",
                    stale_count = stale_keys.len()
                );
            }
        }
        write_tx.commit().map_err(|e| AppError::DatabaseError {
            reason: format!("Failed to commit eviction: {e}"),
        })?;
        Ok(())
    }
}
