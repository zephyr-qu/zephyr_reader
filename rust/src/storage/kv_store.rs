//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据

use std::path::Path;

use anyhow::{Context, Result};

use super::models::{LayoutCache, LayoutCacheKey, LAYOUT_CACHE_VERSION};

const LAYOUT_TREE_NAME: &str = "layout_cache";

/// KV 存储封装
pub struct KvStore {
    #[allow(dead_code)]
    db: sled::Db,
    layout_cache: sled::Tree,
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self> {
        let db = sled::open(path).context("Failed to open sled database")?;
        let layout_cache = db.open_tree(LAYOUT_TREE_NAME)?;
        Ok(Self { db, layout_cache })
    }

    /// 刷盘
    pub fn flush(&self) -> Result<()> {
        self.db.flush().context("Failed to flush sled database")?;
        Ok(())
    }

    /// 存储排版缓存
    ///
    /// 插入后不校验 —— 写入时始终是有效的。
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, value: &LayoutCache) -> Result<()> {
        debug_assert!(
            value.is_valid(key.config_hash),
            "LayoutCache version/config_hash mismatch on save"
        );
        let bytes = bincode::serialize(value).context("Failed to serialize value")?;
        self.layout_cache.insert(key.to_string(), bytes)?;
        Ok(())
    }

    /// 获取排版缓存，自动校验版本和配置哈希
    ///
    /// 如果数据不存在、反序列化失败、版本不匹配或 config_hash 不一致，
    /// 均视为 miss（返回 None 且不抛异常）。
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<LayoutCache>> {
        match self.layout_cache.get(key.to_string())? {
            Some(bytes) => {
                match bincode::deserialize::<LayoutCache>(&bytes) {
                    Ok(cache) if cache.is_valid(key.config_hash) => Ok(Some(cache)),
                    // 反序列化成功但校验失败 —— 静默丢弃脏数据
                    Ok(_) => {
                        // 不删除数据，留给 cleanup 或下次写入覆盖
                        Ok(None)
                    }
                    // 反序列化失败 —— 数据损坏，视为 miss
                    Err(e) => {
                        tracing::warn!(
                            "LayoutCache deserialize failed (corrupted?): {}",
                            e
                        );
                        Ok(None)
                    }
                }
            }
            None => Ok(None),
        }
    }

    /// 删除书籍的所有排版缓存
    pub fn delete_book_layout_cache(&self, book_id: &str) -> Result<()> {
        let prefix = format!("v{}:{}:", LAYOUT_CACHE_VERSION, book_id);
        for key in self.layout_cache.scan_prefix(prefix.as_bytes()).keys() {
            let key = key.context("Failed to read key")?;
            self.layout_cache.remove(key)?;
        }
        Ok(())
    }

    /// 删除所有 v1 旧前缀的缓存（用于启动时一次性清理）
    pub fn delete_v1_cache(&self) -> Result<usize> {
        let mut count = 0;
        let keys: Vec<_> = self
            .layout_cache
            .scan_prefix(b"v1:")
            .keys()
            .filter_map(|k| k.ok())
            .collect();
        for key in keys {
            self.layout_cache.remove(key)?;
            count += 1;
        }
        Ok(count)
    }

    /// 清理过期缓存
    pub fn cleanup_expired_cache(&self, max_age_days: i64) -> Result<usize> {
        let cutoff = chrono::Utc::now() - chrono::Duration::days(max_age_days);
        let mut count = 0;
        for item in self.layout_cache.iter() {
            let (key, value) = item.context("Failed to read from sled")?;
            if let Ok(cache) = bincode::deserialize::<LayoutCache>(&value) {
                if cache.created_at < cutoff {
                    self.layout_cache.remove(key)?;
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
                },
                crate::domain::PageContent {
                    chapter_index: 0,
                    page_index: 1,
                    content: "page two".into(),
                    is_last_page: true,
                    start_offset: 8,
                    end_offset: 16,
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

        // 保存时 config_hash = 0xDEAD_BEEF
        store
            .save_layout_cache(&test_key(), &test_cache())
            .unwrap();

        // 用不同的 config_hash 查询 —— 应返回 None
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

        // 保存一个 version 错误的缓存（手动构造）
        let bad_cache = LayoutCache {
            version: LAYOUT_CACHE_VERSION + 1, // 未来版本
            config_hash: key.config_hash,
            total_pages: 0,
            created_at: chrono::Utc::now(),
            pages: vec![], // 空 pages 向量
        };
        store.save_layout_cache(&key, &bad_cache).unwrap();

        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_none(), "wrong version must return None");
    }

    #[test]
    fn test_get_ignores_corrupted_data() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        // 直接插入无效字节
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

        // 插入一个 v1 格式的 key
        store
            .layout_cache
            .insert("v1:old_book:0:abc", b"dummy")
            .unwrap();
        // 插入一个 v2 格式的 key
        store
            .save_layout_cache(&test_key(), &test_cache())
            .unwrap();

        let deleted = store.delete_v1_cache().unwrap();
        assert_eq!(deleted, 1, "should delete exactly 1 v1 key");

        // v2 数据不受影响
        assert!(store.get_layout_cache(&test_key()).unwrap().is_some());
    }

    #[test]
    fn test_cleanup_expired() {
        let dir = TempDir::new().unwrap();
        let store = KvStore::new(dir.path()).unwrap();
        let key = test_key();

        // 保存一条"过期"缓存（手动设置 created_at 为过去）
        let old_cache = LayoutCache {
            created_at: chrono::Utc::now()
                - chrono::Duration::days(100),
            ..test_cache()
        };
        store.save_layout_cache(&key, &old_cache).unwrap();

        // 保存一条"未过期"缓存
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

        // 模拟真实章节文本
        let chapter_text = "这是第一段内容。\n\n这是第二段内容，包含一些中英文混合文本 like this。\n\n第三段。".to_string();
        let chapter_index = 2;

        // Step 1: 首次调用（模拟 miss）—— 分页 + 缓存
        let pages = paginate_all(chapter_text.clone(), chapter_index, config.clone());
        assert!(!pages.is_empty(), "paginate_all must produce pages");

        let cache = LayoutCache::new(config_hash, pages.clone());
        let key = LayoutCacheKey {
            book_id: "test_paginate_book".into(),
            chapter_index,
            chunk_index: None,
            config_hash,
        };
        store.save_layout_cache(&key, &cache).unwrap();

        // Step 2: 二次调用（模拟 hit）—— 从缓存加载
        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_some(), "cache must be present after save");
        let cached = loaded.unwrap();
        assert!(cached.is_valid(config_hash), "cache must pass validation");

        // Step 3: 验证缓存结果与原始结果一致
        assert_eq!(cached.total_pages, pages.len() as i32);
        assert_eq!(cached.pages.len(), pages.len());
        for (i, (original, cached_page)) in pages.iter().zip(cached.pages.iter()).enumerate() {
            assert_eq!(
                original.content, cached_page.content,
                "page {} content mismatch between fresh and cached",
                i,
            );
            assert_eq!(original.page_index, cached_page.page_index);
            assert_eq!(original.is_last_page, cached_page.is_last_page);
        }
    }
}
