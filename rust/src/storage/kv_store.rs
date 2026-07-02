//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据。
//! P1: `LayoutCache`（plain sled）已移除，仅保留 block sled 和 scroll IR sled。

use std::path::Path;

use crate::domain::AppError;

use super::models::{
    BlockLayoutCache, BLOCK_LAYOUT_CACHE_VERSION, LayoutCacheKey, ScrollIrCache,
};

const BLOCK_LAYOUT_TREE_NAME: &str = "block_layout_cache";
const SCROLL_IR_TREE_NAME: &str = "scroll_ir_cache";

/// KV 存储封装
pub struct KvStore {
    /// sled 数据库句柄 — 不会被直接读取，仅用于保活。
    /// 一旦 db 被 drop，tree 会成为悬空指针。
    #[allow(dead_code)]
    db: sled::Db,
    block_layout_cache: sled::Tree,
    scroll_ir_cache: sled::Tree,
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self, AppError> {
        let db = sled::open(path)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open sled database: {e}").into() })?;
        let block_layout_cache = db
            .open_tree(BLOCK_LAYOUT_TREE_NAME)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open block layout tree: {e}").into() })?;
        let scroll_ir_cache = db
            .open_tree(SCROLL_IR_TREE_NAME)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open scroll ir tree: {e}").into() })?;
        Ok(Self {
            db,
            block_layout_cache,
            scroll_ir_cache,
        })
    }

    /// 刷盘
    pub fn flush(&self) -> Result<(), AppError> {
        self.db
            .flush()
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to flush sled database: {e}").into() })?;
        Ok(())
    }

    /// 存储排版缓存
    ///
    /// 插入后不校验 —— 写入时始终是有效的。
    /// 存储块分页索引缓存（IR + BlockPaginateResult）。
    pub fn save_block_layout_cache(
        &self,
        key: &LayoutCacheKey,
        value: &BlockLayoutCache,
    ) -> Result<(), AppError> {
        debug_assert!(
            value.is_valid(key.config_hash),
            "BlockLayoutCache version/config_hash mismatch on save"
        );
        let bytes = bincode::encode_to_vec(value, bincode::config::standard())
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to serialize block cache: {e}").into() })?;
        self.block_layout_cache
            .insert(key.to_string(), bytes)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to insert block cache: {e}").into() })?;
        Ok(())
    }

    /// 获取块分页索引缓存；版本/config_hash 不匹配视为 miss。
    pub fn get_block_layout_cache(
        &self,
        key: &LayoutCacheKey,
    ) -> Result<Option<BlockLayoutCache>, AppError> {
        match self
            .block_layout_cache
            .get(key.to_string())
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read block cache: {e}").into() })?
        {
            Some(bytes) => match bincode::decode_from_slice::<BlockLayoutCache, _>(
                &bytes,
                bincode::config::standard(),
            ) {
                Ok((cache, _)) if cache.is_valid(key.config_hash) => Ok(Some(cache)),
                Ok(_) => Ok(None),
                Err(e) => {
                    tracing::warn!("BlockLayoutCache deserialize failed (corrupted?): {}", e);
                    Ok(None)
                }
            },
            None => Ok(None),
        }
    }

    /// 存储 Scroll IR 缓存（key = `{file_path}#{chapter_index}`）。
    pub fn save_scroll_ir_cache(
        &self,
        file_path: &str,
        chapter_index: i32,
        value: &ScrollIrCache,
    ) -> Result<(), AppError> {
        let key = format!("{}#{}", file_path, chapter_index);
        let bytes = bincode::encode_to_vec(value, bincode::config::standard())
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to serialize scroll ir: {e}").into() })?;
        self.scroll_ir_cache
            .insert(key, bytes)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to insert scroll ir cache: {e}").into() })?;
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
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read scroll ir cache: {e}").into() })?
        {
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

    fn delete_tree_entries_with_book_prefix(
        tree: &sled::Tree,
        prefix: &str,
    ) -> Result<(), AppError> {
        for key in tree.scan_prefix(prefix.as_bytes()).keys() {
            let key = key
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read key: {e}").into() })?;
            tree.remove(key)
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to remove cache: {e}").into() })?;
        }
        Ok(())
    }

    /// 删除书籍的所有排版缓存（P1: 仅清理 block sled）
    pub fn delete_book_layout_cache(&self, book_id: &str) -> Result<(), AppError> {
        let prefix = format!("v{}:{}:", BLOCK_LAYOUT_CACHE_VERSION, book_id);
        Self::delete_tree_entries_with_book_prefix(&self.block_layout_cache, &prefix)?;
        Ok(())
    }

    /// 删除所有 v1 旧前缀的缓存（用于启动时一次性清理）
    /// P1: 仅清理 block sled 的 v1 条目。
    pub fn delete_v1_cache(&self) -> Result<usize, AppError> {
        let mut count = 0;
        let keys: Vec<_> = self
            .block_layout_cache
            .scan_prefix(b"v1:")
            .keys()
            .filter_map(|k| k.ok())
            .collect();
        for key in keys {
            self.block_layout_cache
                .remove(key)
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to remove key: {e}").into() })?;
            count += 1;
        }
        Ok(count)
    }

    /// 清理过期缓存（P1: 仅清理 block sled）
    pub fn cleanup_expired_cache(&self, max_age_days: i64) -> Result<usize, AppError> {
        let cutoff = (chrono::Utc::now() - chrono::Duration::days(max_age_days)).timestamp();
        let mut count = 0;
        for item in self.block_layout_cache.iter() {
            let (key, value) = item
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read from sled: {e}").into() })?;
            if let Ok((cache, _)) =
                bincode::decode_from_slice::<BlockLayoutCache, _>(&value, bincode::config::standard())
            {
                if cache.created_at < cutoff {
                    self.block_layout_cache
                        .remove(key)
                        .map_err(|e| AppError::DatabaseError { reason: format!("Failed to remove key: {e}").into() })?;
                    count += 1;
                }
            }
        }
        Ok(count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_block_layout_cache_roundtrip() {
        use crate::domain::{
            BlockJoinedPlainBuilder, BlockPaginateResult, BlockPageDescriptor, BlockPlainRange,
            TextBlockStyle,
        };

        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let config_hash = 0xABCD_EF01_u64;
        let key = LayoutCacheKey {
            book_id: "block_book".into(),
            chapter_index: 0,
            chunk_index: None,
            config_hash,
        };

        let mut builder = BlockJoinedPlainBuilder::new();
        builder.push_text("Hello".into(), TextBlockStyle::default());
        builder.push_image("img1".into(), None);
        let ir = builder.finish();
        let result = BlockPaginateResult::new(
            vec![BlockPageDescriptor::new(
                0,
                0,
                2,
                BlockPlainRange::new(0, 8),
                true,
            )],
            config_hash,
            false,
        );
        let cache = BlockLayoutCache::new(config_hash, ir.clone(), result.clone());
        store.save_block_layout_cache(&key, &cache).unwrap();

        let loaded = store.get_block_layout_cache(&key).unwrap().expect("block cache hit");
        assert_eq!(loaded.ir.plain_text, ir.plain_text);
        assert_eq!(loaded.result.descriptors.len(), 1);
        assert_eq!(loaded.config_hash, config_hash);
    }

    #[test]
    fn test_delete_book_cache() {
        use crate::domain::{
            BlockJoinedPlainBuilder, BlockPaginateResult, BlockPageDescriptor, BlockPlainRange,
            TextBlockStyle,
        };

        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let config_hash = 0xABCD_EF01_u64;
        let key = LayoutCacheKey {
            book_id: "test_book".into(),
            chapter_index: 0,
            chunk_index: None,
            config_hash,
        };

        let mut builder = BlockJoinedPlainBuilder::new();
        builder.push_text("Hello".into(), TextBlockStyle::default());
        let ir = builder.finish();
        let result = BlockPaginateResult::new(
            vec![BlockPageDescriptor::new(0, 0, 1, BlockPlainRange::new(0, 5), true)],
            config_hash,
            false,
        );
        let cache = BlockLayoutCache::new(config_hash, ir.clone(), result);
        store.save_block_layout_cache(&key, &cache).unwrap();
        assert!(store.get_block_layout_cache(&key).unwrap().is_some());

        store.delete_book_layout_cache("test_book").unwrap();
        assert!(store.get_block_layout_cache(&key).unwrap().is_none());
    }

    #[test]
    fn block_layout_cache_v1_is_stale() {
        use crate::domain::{
            BlockJoinedPlainBuilder, BlockPaginateResult, BlockPageDescriptor, BlockPlainRange,
            TextBlockStyle,
        };

        let mut builder = BlockJoinedPlainBuilder::new();
        builder.push_text("Hi".into(), TextBlockStyle::default());
        let ir = builder.finish();
        let result = BlockPaginateResult::new(
            vec![BlockPageDescriptor::new(0, 0, 1, BlockPlainRange::new(0, 2), true)],
            1,
            false,
        );
        let stale = BlockLayoutCache {
            version: 1,
            config_hash: 1,
            ir,
            result,
            total_pages: 1,
            created_at: 0,
        };
        assert!(!stale.is_valid(1));
    }
}
