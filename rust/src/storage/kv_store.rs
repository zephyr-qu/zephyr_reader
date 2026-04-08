//! KV 存储（sled）
//!
//! 用于排版缓存等高频读写、可重建的临时数据

use std::path::Path;

use anyhow::{Context, Result};
use serde::{de::DeserializeOwned, Serialize};

/// KV 存储封装
pub struct KvStore {
    db: sled::Db,
}

impl KvStore {
    /// 打开或创建 KV 存储
    pub fn new(path: impl AsRef<Path>) -> Result<Self> {
        let db = sled::open(path).context("Failed to open sled database")?;
        Ok(Self { db })
    }

    /// 存储序列化值
    pub fn put<T: Serialize>(&self, key: impl AsRef<[u8]>, value: &T) -> Result<()> {
        let bytes = bincode::serialize(value).context("Failed to serialize value")?;
        self.db.insert(key, bytes)?;
        Ok(())
    }

    /// 获取反序列化值
    pub fn get<T: DeserializeOwned>(&self, key: impl AsRef<[u8]>) -> Result<Option<T>> {
        match self.db.get(key)? {
            Some(bytes) => {
                let value = bincode::deserialize(&bytes).context("Failed to deserialize value")?;
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }

    /// 删除键
    pub fn delete(&self, key: impl AsRef<[u8]>) -> Result<Option<sled::IVec>> {
        Ok(self.db.remove(key)?)
    }

    /// 检查键是否存在
    pub fn contains_key(&self, key: impl AsRef<[u8]>) -> Result<bool> {
        Ok(self.db.contains_key(key)?)
    }

    /// 原子更新
    pub fn update<T: Serialize + DeserializeOwned>(
        &self,
        key: impl AsRef<[u8]>,
        f: impl FnOnce(Option<T>) -> T,
    ) -> Result<()> {
        let key = key.as_ref();
        let old = self.get::<T>(key)?;
        let new = f(old);
        self.put(key, &new)?;
        Ok(())
    }

    /// 前缀扫描
    pub fn scan_prefix<T: DeserializeOwned>(
        &self,
        prefix: impl AsRef<[u8]>,
    ) -> Result<Vec<(String, T)>> {
        let mut results = Vec::new();
        for item in self.db.scan_prefix(prefix) {
            let (key, value) = item.context("Failed to read from sled")?;
            if let Ok(v) = bincode::deserialize::<T>(&value) {
                results.push((String::from_utf8_lossy(&key).to_string(), v));
            }
        }
        Ok(results)
    }

    /// 刷盘
    pub fn flush(&self) -> Result<()> {
        self.db.flush().context("Failed to flush sled database")?;
        Ok(())
    }

    /// 获取树（用于命名空间隔离）
    pub fn open_tree(&self, name: impl AsRef<str>) -> Result<TreeWrapper> {
        let tree = self.db.open_tree(name.as_ref())?;
        Ok(TreeWrapper { tree })
    }

    /// 清空所有数据
    pub fn clear(&self) -> Result<()> {
        self.db.clear()?;
        Ok(())
    }

    /// 获取磁盘使用量（字节）
    pub fn size_on_disk(&self) -> Result<u64> {
        Ok(self.db.size_on_disk()?)
    }
}

/// 树包装器（命名空间）
pub struct TreeWrapper {
    tree: sled::Tree,
}

impl TreeWrapper {
    pub fn put<T: Serialize>(&self, key: impl AsRef<[u8]>, value: &T) -> Result<()> {
        let bytes = bincode::serialize(value).context("Failed to serialize value")?;
        self.tree.insert(key, bytes)?;
        Ok(())
    }

    pub fn get<T: DeserializeOwned>(&self, key: impl AsRef<[u8]>) -> Result<Option<T>> {
        match self.tree.get(key)? {
            Some(bytes) => {
                let value = bincode::deserialize(&bytes).context("Failed to deserialize value")?;
                Ok(Some(value))
            }
            None => Ok(None),
        }
    }

    pub fn delete(&self, key: impl AsRef<[u8]>) -> Result<Option<sled::IVec>> {
        Ok(self.tree.remove(key)?)
    }

    pub fn clear(&self) -> Result<()> {
        self.tree.clear()?;
        Ok(())
    }
}

// ==================== 排版缓存专用 API ====================

use super::models::{DbLayoutCache, LayoutCacheKey};

impl KvStore {
    /// 存储排版缓存
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, value: &DbLayoutCache) -> Result<()> {
        let tree = self.open_tree("layout_cache")?;
        tree.put(key.to_string(), value)
    }

    /// 获取排版缓存
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<DbLayoutCache>> {
        let tree = self.open_tree("layout_cache")?;
        tree.get(key.to_string())
    }

    /// 删除书籍的所有排版缓存
    pub fn delete_book_layout_cache(&self, book_id: &str) -> Result<()> {
        let tree = self.db.open_tree("layout_cache")?;
        let prefix = format!("{}:", book_id);
        for key in tree.scan_prefix(prefix.as_bytes()).keys() {
            let key = key.context("Failed to read key")?;
            tree.remove(key)?;
        }
        Ok(())
    }

    /// 清理过期缓存（超过 N 天）
    pub fn cleanup_expired_cache(&self, max_age_days: i64) -> Result<usize> {
        let cutoff = chrono::Utc::now() - chrono::Duration::days(max_age_days);
        let tree = self.db.open_tree("layout_cache")?;

        let mut count = 0;
        for item in tree.iter() {
            let (key, value) = item.context("Failed to read from sled")?;
            if let Ok(cache) = bincode::deserialize::<DbLayoutCache>(&value) {
                if cache.created_at < cutoff {
                    tree.remove(key)?;
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

        // 存储
        store.put("key1", &"value1".to_string()).unwrap();

        // 获取
        let value: Option<String> = store.get("key1").unwrap();
        assert_eq!(value, Some("value1".to_string()));

        // 删除
        store.delete("key1").unwrap();
        let value: Option<String> = store.get("key1").unwrap();
        assert_eq!(value, None);
    }
}
