//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据

use std::path::Path;

use anyhow::{Context, Result};

use super::models::{LayoutCache, LayoutCacheKey};

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
        let layout_cache = db.open_tree("layout_cache")?;
         Ok(Self { db, layout_cache })
    }

    /// 刷盘
    pub fn flush(&self) -> Result<()> {
        self.db.flush().context("Failed to flush sled database")?;
        Ok(())
    }

    /// 存储排版缓存
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, value: &LayoutCache) -> Result<()> {
        let bytes = bincode::serialize(value).context("Failed to serialize value")?;
        self.layout_cache.insert(key.to_string(), bytes)?;
        Ok(())
    }

    /// 获取排版缓存
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<LayoutCache>> {
        match self.layout_cache.get(key.to_string())? {
            Some(bytes) => {
                let value = bincode::deserialize(&bytes).context("Failed to deserialize value")?;
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }

    /// 删除书籍的所有排版缓存
    pub fn delete_book_layout_cache(&self, book_id: &str) -> Result<()> {
        let prefix = format!("v1:{}:", book_id);
        for key in self.layout_cache.scan_prefix(prefix.as_bytes()).keys() {
            let key = key.context("Failed to read key")?;
            self.layout_cache.remove(key)?;
        }
        Ok(())
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
    use tempfile::TempDir;

    #[test]
    fn test_kv_store_basic() {
        let temp_dir = TempDir::new().unwrap();
        let store = KvStore::new(temp_dir.path()).unwrap();

        let key = super::LayoutCacheKey {
            book_id: "test".to_string(),
            chapter_index: 0,
            config_hash: "abc".to_string(),
        };
        let cache = super::LayoutCache {
            page_offsets: vec![(0, 100)],
            total_pages: 1,
            created_at: chrono::Utc::now(),
        };

        store.save_layout_cache(&key, &cache).unwrap();
        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_some());
        assert_eq!(loaded.unwrap().total_pages, 1);

        store.delete_book_layout_cache("test").unwrap();
        let loaded = store.get_layout_cache(&key).unwrap();
        assert!(loaded.is_none());
    }
}
