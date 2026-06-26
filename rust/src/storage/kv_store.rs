//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据

use std::path::Path;

use crate::domain::AppError;

use super::models::{
    BlockLayoutCache, LAYOUT_CACHE_VERSION, LayoutCache, LayoutCacheKey, ScrollIrCache,
};

const LAYOUT_TREE_NAME: &str = "layout_cache";
const BLOCK_LAYOUT_TREE_NAME: &str = "block_layout_cache";
const SCROLL_IR_TREE_NAME: &str = "scroll_ir_cache";

/// KV 存储封装
pub struct KvStore {
    /// sled 数据库句柄 — 不会被直接读取，仅用于保活。
    /// `layout_cache` Tree 是从此 `Db` 打开的，sled 要求 Db 的存活期 >= Tree；
    /// 一旦 db 被 drop，layout_cache 会成为悬空指针。
    #[allow(dead_code)]
    db: sled::Db,
    layout_cache: sled::Tree,
    block_layout_cache: sled::Tree,
    scroll_ir_cache: sled::Tree,
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self, AppError> {
        let db = sled::open(path)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open sled database: {e}").into() })?;
        let layout_cache = db
            .open_tree(LAYOUT_TREE_NAME)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open layout tree: {e}").into() })?;
        let block_layout_cache = db
            .open_tree(BLOCK_LAYOUT_TREE_NAME)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open block layout tree: {e}").into() })?;
        let scroll_ir_cache = db
            .open_tree(SCROLL_IR_TREE_NAME)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to open scroll ir tree: {e}").into() })?;
        Ok(Self {
            db,
            layout_cache,
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
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, value: &LayoutCache) -> Result<(), AppError> {
        debug_assert!(
            value.is_valid(key.config_hash),
            "LayoutCache version/config_hash mismatch on save"
        );
        let bytes = bincode::encode_to_vec(value, bincode::config::standard())
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to serialize value: {e}").into() })?;
        self.layout_cache
            .insert(key.to_string(), bytes)
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to insert cache: {e}").into() })?;
        Ok(())
    }

    /// 获取排版缓存，自动校验版本和配置哈希
    ///
    /// 如果数据不存在、反序列化失败、版本不匹配或 config_hash 不一致，
    /// 均视为 miss（返回 None 且不抛异常）。
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<LayoutCache>, AppError> {
        match self
            .layout_cache
            .get(key.to_string())
            .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read cache: {e}").into() })?
        {
            Some(bytes) => {
                match bincode::decode_from_slice::<LayoutCache, _>(
                    &bytes,
                    bincode::config::standard(),
                ) {
                    Ok((cache, _)) if cache.is_valid(key.config_hash) => Ok(Some(cache)),
                    // 反序列化成功但校验失败 —— 静默丢弃脏数据
                    Ok(_) => Ok(None),
                    // 反序列化失败 —— 数据损坏，视为 miss
                    Err(e) => {
                        tracing::warn!("LayoutCache deserialize failed (corrupted?): {}", e);
                        Ok(None)
                    }
                }
            }
            None => Ok(None),
        }
    }

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

    /// 删除书籍的所有排版缓存
    pub fn delete_book_layout_cache(&self, book_id: &str) -> Result<(), AppError> {
        let prefix = format!("v{}:{}:", LAYOUT_CACHE_VERSION, book_id);
        Self::delete_tree_entries_with_book_prefix(&self.layout_cache, &prefix)?;
        Self::delete_tree_entries_with_book_prefix(&self.block_layout_cache, &prefix)?;
        Ok(())
    }

    /// 删除所有 v1 旧前缀的缓存（用于启动时一次性清理）
    pub fn delete_v1_cache(&self) -> Result<usize, AppError> {
        let mut count = 0;
        let keys: Vec<_> = self
            .layout_cache
            .scan_prefix(b"v1:")
            .keys()
            .filter_map(|k| k.ok())
            .collect();
        for key in keys {
            self.layout_cache
                .remove(key)
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to remove key: {e}").into() })?;
            count += 1;
        }
        Ok(count)
    }

    /// 清理过期缓存
    pub fn cleanup_expired_cache(&self, max_age_days: i64) -> Result<usize, AppError> {
        let cutoff = (chrono::Utc::now() - chrono::Duration::days(max_age_days)).timestamp();
        let mut count = 0;
        for item in self.layout_cache.iter() {
            let (key, value) = item
                .map_err(|e| AppError::DatabaseError { reason: format!("Failed to read from sled: {e}").into() })?;
            if let Ok((cache, _)) =
                bincode::decode_from_slice::<LayoutCache, _>(&value, bincode::config::standard())
            {
                if cache.created_at < cutoff {
                    self.layout_cache
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
    use crate::storage::models::LAYOUT_CACHE_VERSION;
    use tempfile::TempDir;

    fn test_key() -> LayoutCacheKey {
        LayoutCacheKey {
            book_id: "test_book".into(),
            chapter_index: 0,
            chunk_index: None,
            config_hash: 0xDEAD_BEEF,
        }
    }

    fn test_cache() -> LayoutCache {
        LayoutCache::new(
            0xDEAD_BEEF,
            vec![
                crate::domain::PageContent {
                    chapter_index: 0,
                    page_index: 0,
                    content: "page one".into(),
                    is_last_page: false,
                    start_offset: 0,
                    end_offset: 8,
                    first_paragraph_index: 0,
                    last_paragraph_index: 0,
                },
                crate::domain::PageContent {
                    chapter_index: 0,
                    page_index: 1,
                    content: "page two".into(),
                    is_last_page: true,
                    start_offset: 8,
                    end_offset: 16,
                    first_paragraph_index: 0,
                    last_paragraph_index: 0,
                },
            ],
        )
    }

    #[test]
    fn test_save_and_load() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();
        let cache = test_cache();

        store.save_layout_cache(&key, &cache).unwrap();
        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_some());
        let l = loaded.unwrap();
        assert_eq!(l.total_pages, 2);
        assert_eq!(l.pages.len(), 2);
    }

    #[test]
    fn test_delete_book_cache() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        store.save_layout_cache(&key, &test_cache()).unwrap();
        assert!(store.get_layout_cache(&key).unwrap().is_some());

        store.delete_book_layout_cache("test_book").unwrap();
        assert!(store.get_layout_cache(&key).unwrap().is_none());
    }

    #[test]
    fn test_get_miss_on_wrong_config_hash() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();

        store.save_layout_cache(&test_key(), &test_cache()).unwrap();

        let wrong_key = LayoutCacheKey {
            config_hash: 0xCAFE,
            ..test_key()
        };
        let loaded = store.get_layout_cache(&wrong_key).unwrap();
        assert!(loaded.is_none(), "wrong config_hash must return None");
    }

    #[test]
    fn test_get_miss_on_wrong_version() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        let bad_cache = LayoutCache {
            version: LAYOUT_CACHE_VERSION + 1,
            config_hash: key.config_hash,
            total_pages: 0,
            created_at: chrono::Utc::now().timestamp(),
            pages: vec![],
        };
        let bytes = bincode::encode_to_vec(&bad_cache, bincode::config::standard()).unwrap();
        store.layout_cache.insert(key.to_string(), bytes).unwrap();

        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_none(), "wrong version must return None");
    }

    #[test]
    fn test_get_ignores_corrupted_data() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        store
            .layout_cache
            .insert(key.to_string(), b"not bincode data".to_vec())
            .unwrap();

        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_none(), "corrupted data must return None");
    }

    #[test]
    fn test_delete_v1_cache() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();

        store
            .layout_cache
            .insert("v1:old_book:0:abc", b"dummy")
            .unwrap();
        store.save_layout_cache(&test_key(), &test_cache()).unwrap();

        let deleted = store.delete_v1_cache().unwrap();
        assert_eq!(deleted, 1, "should delete exactly 1 v1 key");

        assert!(store.get_layout_cache(&test_key()).unwrap().is_some());
    }

    #[test]
    fn test_cleanup_expired() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        let old_cache = LayoutCache {
            created_at: (chrono::Utc::now() - chrono::Duration::days(100)).timestamp(),
            ..test_cache()
        };
        store.save_layout_cache(&key, &old_cache).unwrap();

        let fresh_key = LayoutCacheKey {
            chapter_index: 1,
            ..test_key()
        };
        store.save_layout_cache(&fresh_key, &test_cache()).unwrap();

        let removed = store.cleanup_expired_cache(30).unwrap();
        assert_eq!(removed, 1, "should remove 1 expired entry");

        assert!(store.get_layout_cache(&key).unwrap().is_none());
        assert!(store.get_layout_cache(&fresh_key).unwrap().is_some());
    }

    #[test]
    fn test_paginate_cache_roundtrip() {
        use crate::domain::TypesetConfig;
        use crate::text::paginate_all;

        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let config = TypesetConfig::default();
        let config_hash = config.config_hash();

        let key = LayoutCacheKey {
            book_id: "test".into(),
            chapter_index: 0,
            chunk_index: None,
            config_hash,
        };

        let content =
            "This is a test content that should be paginated into multiple pages for testing."
                .to_string();
        let pages = paginate_all(content, 0, config);
        assert!(!pages.is_empty(), "should have at least one page");

        let cache = LayoutCache::new(config_hash, pages.clone());
        store.save_layout_cache(&key, &cache).unwrap();

        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_some());
        let loaded = loaded.unwrap();
        assert_eq!(loaded.pages.len(), pages.len());
        assert_eq!(loaded.config_hash, config_hash);
    }

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
