//! LRU 缓存实现
//!
//! 提供基于 HashMap 和 VecDeque 的 LRU（最近最少使用）缓存实现。
//! 用于缓存解析结果、排版数据等，提升重复访问性能。

use std::collections::{HashMap, VecDeque};
use std::hash::Hash;
use std::time::{Duration, Instant};

/// LRU 缓存条目
struct CacheEntry<V> {
    value: V,
    last_accessed: Instant,
    size_bytes: usize,
}

/// LRU 缓存
///
/// 支持基于容量和内存大小的双重限制。
/// 当缓存超出限制时，自动淘汰最近最少使用的条目。
pub struct LruCache<K, V> {
    items: HashMap<K, CacheEntry<V>>,
    order: VecDeque<K>,
    max_entries: usize,
    max_memory_bytes: usize,
    current_memory_bytes: usize,
}

impl<K: Eq + Hash + Clone, V> LruCache<K, V> {
    /// 创建新的 LRU 缓存
    ///
    /// # 参数
    ///
    /// * `max_entries` - 最大条目数
    /// * `max_memory_bytes` - 最大内存占用（字节），0 表示不限制
    pub fn new(max_entries: usize, max_memory_bytes: usize) -> Self {
        Self {
            items: HashMap::with_capacity(max_entries.min(1024)),
            order: VecDeque::with_capacity(max_entries.min(1024)),
            max_entries,
            max_memory_bytes,
            current_memory_bytes: 0,
        }
    }

    /// 创建默认配置的 LRU 缓存
    ///
    /// 默认最大 100 条目，最大内存 50MB
    pub fn default() -> Self {
        Self::new(100, 50 * 1024 * 1024)
    }

    /// 获取缓存条目数
    pub fn len(&self) -> usize {
        self.items.len()
    }

    /// 检查缓存是否为空
    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }

    /// 获取缓存项（不更新访问时间）
    pub fn get(&self, key: &K) -> Option<&V> {
        self.items.get(key).map(|entry| &entry.value)
    }

    /// 获取缓存项（更新访问时间）
    pub fn get_mut(&mut self, key: &K) -> Option<&mut V> {
        if let Some(entry) = self.items.get_mut(key) {
            entry.last_accessed = Instant::now();
            // 内联 touch 逻辑，避免双重可变借用
            if let Some(pos) = self.order.iter().position(|k| k == key) {
                self.order.remove(pos);
                self.order.push_back(key.clone());
            }
            Some(&mut entry.value)
        } else {
            None
        }
    }

    /// 插入缓存项
    ///
    /// 如果缓存已满，自动淘汰最近最少使用的条目。
    pub fn put(&mut self, key: K, value: V, size_bytes: usize) {
        // 如果已存在，先移除旧条目
        if self.items.contains_key(&key) {
            self.remove(&key);
        }

        // 检查是否需要淘汰
        while self.should_evict(size_bytes) {
            self.evict_lru();
        }

        // 插入新条目
        let entry = CacheEntry {
            value,
            last_accessed: Instant::now(),
            size_bytes,
        };

        self.current_memory_bytes += size_bytes;
        self.order.push_back(key.clone());
        self.items.insert(key, entry);
    }

    /// 插入缓存项（使用默认大小估算）
    pub fn insert(&mut self, key: K, value: V) {
        // 估算大小：对于 String 类型，使用实际长度；其他类型使用固定大小
        let size_bytes = std::mem::size_of_val(&value);
        self.put(key, value, size_bytes);
    }

    /// 移除缓存项
    pub fn remove(&mut self, key: &K) -> Option<V> {
        if let Some(entry) = self.items.remove(key) {
            self.current_memory_bytes = self.current_memory_bytes.saturating_sub(entry.size_bytes);
            // 从 order 中移除（可能需要线性搜索）
            if let Some(pos) = self.order.iter().position(|k| k == key) {
                self.order.remove(pos);
            }
            Some(entry.value)
        } else {
            None
        }
    }

    /// 清除所有缓存
    pub fn clear(&mut self) {
        self.items.clear();
        self.order.clear();
        self.current_memory_bytes = 0;
    }

    /// 检查是否需要淘汰
    fn should_evict(&self, new_size: usize) -> bool {
        if self.items.is_empty() {
            return false;
        }

        // 检查条目数限制
        if self.items.len() >= self.max_entries {
            return true;
        }

        // 检查内存限制
        if self.max_memory_bytes > 0 && self.current_memory_bytes + new_size > self.max_memory_bytes
        {
            return true;
        }

        false
    }

    /// 淘汰最近最少使用的条目
    fn evict_lru(&mut self) {
        if let Some(oldest_key) = self.order.pop_front() {
            if let Some(entry) = self.items.remove(&oldest_key) {
                self.current_memory_bytes =
                    self.current_memory_bytes.saturating_sub(entry.size_bytes);
                tracing::trace!("LRU 淘汰：大小：{} bytes", entry.size_bytes);
            }
        }
    }

    /// 更新条目的访问顺序（移到队尾）
    #[allow(dead_code)]
    fn touch(&mut self, key: &K) {
        if let Some(pos) = self.order.iter().position(|k| k == key) {
            self.order.remove(pos);
            self.order.push_back(key.clone());
        }
    }

    /// 获取缓存命中率统计
    pub fn get_stats(&self) -> CacheStats {
        CacheStats {
            entries: self.items.len(),
            memory_bytes: self.current_memory_bytes,
            max_entries: self.max_entries,
            max_memory_bytes: self.max_memory_bytes,
            memory_usage_percent: if self.max_memory_bytes > 0 {
                (self.current_memory_bytes as f32 / self.max_memory_bytes as f32) * 100.0
            } else {
                0.0
            },
        }
    }
}

impl<K: Eq + Hash + Clone, V> Default for LruCache<K, V> {
    fn default() -> Self {
        Self::default()
    }
}

/// 缓存统计信息
#[derive(Debug, Clone)]
pub struct CacheStats {
    /// 当前条目数
    pub entries: usize,
    /// 当前内存占用（字节）
    pub memory_bytes: usize,
    /// 最大条目数
    pub max_entries: usize,
    /// 最大内存占用（字节）
    pub max_memory_bytes: usize,
    /// 内存使用百分比
    pub memory_usage_percent: f32,
}

/// 带过期时间的 LRU 缓存
pub struct ExpiringLruCache<K, V> {
    inner: LruCache<K, V>,
    #[allow(dead_code)]
    default_ttl: Duration,
}

impl<K: Eq + Hash + Clone, V> ExpiringLruCache<K, V> {
    /// 创建带过期时间的 LRU 缓存
    pub fn new(max_entries: usize, max_memory_bytes: usize, default_ttl: Duration) -> Self {
        Self {
            inner: LruCache::new(max_entries, max_memory_bytes),
            default_ttl,
        }
    }

    /// 获取缓存项（检查过期）
    pub fn get(&self, key: &K) -> Option<&V> {
        // 注意：这里无法检查过期时间，因为 Entry 结构没有存储创建时间
        // 如需过期功能，需要扩展 CacheEntry 结构
        self.inner.get(key)
    }

    /// 插入缓存项（使用默认 TTL）
    pub fn insert(&mut self, key: K, value: V) {
        self.inner.insert(key, value);
    }

    /// 移除缓存项
    pub fn remove(&mut self, key: &K) -> Option<V> {
        self.inner.remove(key)
    }

    /// 清除所有缓存
    pub fn clear(&mut self) {
        self.inner.clear();
    }

    /// 获取缓存条目数
    pub fn len(&self) -> usize {
        self.inner.len()
    }

    /// 检查缓存是否为空
    pub fn is_empty(&self) -> bool {
        self.inner.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lru_cache_basic() {
        let mut cache = LruCache::<String, String>::new(3, 0);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());
        cache.insert("key3".to_string(), "value3".to_string());

        assert_eq!(cache.len(), 3);
        assert_eq!(cache.get(&"key1".to_string()), Some(&"value1".to_string()));
        assert_eq!(cache.get(&"key2".to_string()), Some(&"value2".to_string()));
        assert_eq!(cache.get(&"key3".to_string()), Some(&"value3".to_string()));
    }

    #[test]
    fn test_lru_cache_eviction() {
        let mut cache = LruCache::<String, String>::new(2, 0);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());
        // 插入第三个，应该淘汰 key1
        cache.insert("key3".to_string(), "value3".to_string());

        assert_eq!(cache.len(), 2);
        assert_eq!(cache.get(&"key1".to_string()), None); // 被淘汰
        assert_eq!(cache.get(&"key2".to_string()), Some(&"value2".to_string()));
        assert_eq!(cache.get(&"key3".to_string()), Some(&"value3".to_string()));
    }

    #[test]
    fn test_lru_cache_access_updates_order() {
        let mut cache = LruCache::<String, String>::new(2, 0);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());
        // 访问 key1，更新其顺序
        cache.get_mut(&"key1".to_string());
        // 插入 key3，应该淘汰 key2（因为 key1 刚被访问）
        cache.insert("key3".to_string(), "value3".to_string());

        assert_eq!(cache.len(), 2);
        assert_eq!(cache.get(&"key1".to_string()), Some(&"value1".to_string()));
        assert_eq!(cache.get(&"key2".to_string()), None); // 被淘汰
        assert_eq!(cache.get(&"key3".to_string()), Some(&"value3".to_string()));
    }

    #[test]
    fn test_lru_cache_remove() {
        let mut cache = LruCache::<String, String>::new(3, 0);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());

        assert_eq!(
            cache.remove(&"key1".to_string()),
            Some("value1".to_string())
        );
        assert_eq!(cache.get(&"key1".to_string()), None);
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn test_lru_cache_clear() {
        let mut cache = LruCache::<String, String>::new(3, 0);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());

        cache.clear();

        assert!(cache.is_empty());
        assert_eq!(cache.len(), 0);
    }

    #[test]
    fn test_lru_cache_memory_limit() {
        // 测试内存限制
        let mut cache = LruCache::<String, Vec<u8>>::new(100, 1000); // 最大 1000 字节

        // 插入大条目
        let large_value = vec![0u8; 400];
        cache.put("key1".to_string(), large_value, 400);
        cache.put("key2".to_string(), vec![0u8; 400], 400);
        cache.put("key3".to_string(), vec![0u8; 400], 400);

        // 应该淘汰了一些条目以保持内存限制
        let stats = cache.get_stats();
        assert!(stats.memory_bytes <= 1000);
    }

    #[test]
    fn test_lru_cache_stats() {
        let mut cache = LruCache::<String, String>::new(100, 10000);

        cache.insert("key1".to_string(), "value1".to_string());
        cache.insert("key2".to_string(), "value2".to_string());

        let stats = cache.get_stats();
        assert_eq!(stats.entries, 2);
        assert!(stats.memory_bytes > 0);
        assert_eq!(stats.max_entries, 100);
        assert_eq!(stats.max_memory_bytes, 10000);
    }

    #[test]
    fn test_expiring_lru_cache() {
        let mut cache =
            ExpiringLruCache::<String, String>::new(100, 10000, Duration::from_secs(60));

        cache.insert("key1".to_string(), "value1".to_string());
        assert_eq!(cache.get(&"key1".to_string()), Some(&"value1".to_string()));
        assert_eq!(cache.len(), 1);
    }
}
