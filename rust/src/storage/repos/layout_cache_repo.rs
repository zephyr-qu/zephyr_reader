use std::sync::Arc;

use anyhow::Result;

use super::super::kv_store::KvStore;
use super::super::models::{LayoutCache, LayoutCacheKey};

/// 排版缓存仓储 — 委托 KvStore 操作
pub struct LayoutCacheRepository {
    kv: Arc<KvStore>,
}

impl LayoutCacheRepository {
    /// 创建排版缓存仓储
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 保存排版缓存
    pub fn save_layout_cache(&self, key: &LayoutCacheKey, cache: &LayoutCache) -> Result<()> {
        self.kv.save_layout_cache(key, cache)
    }

    /// 获取排版缓存
    pub fn get_layout_cache(&self, key: &LayoutCacheKey) -> Result<Option<LayoutCache>> {
        self.kv.get_layout_cache(key)
    }

    /// 使指定书籍的所有排版缓存失效
    pub fn invalidate_book_cache(&self, book_id: &str) -> Result<()> {
        self.kv.delete_book_layout_cache(book_id)
    }
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::models::LayoutCacheKey;
//     use crate::storage::repos::test_utils::*;
//     use crate::storage::repos::book_repo::BookRepository;
//     use tempfile::TempDir;

//     #[tokio::test]
//     async fn test_invalidate_book_cache() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();

//         let temp_dir = TempDir::new().unwrap();
//         let kv = std::sync::Arc::new(crate::storage::kv_store::KvStore::new(temp_dir.path()).unwrap());

//         let key = LayoutCacheKey {
//             book_id: "book1".to_string(),
//             chapter_index: 0,
//             chunk_index: None,
//             config_hash: 0x1234,
//         };
//         let cache = crate::storage::models::LayoutCache::new(
//             0x1234,
//             vec![crate::domain::PageContent {
//                 chapter_index: 0,
//                 page_index: 0,
//                 content: "test page".into(),
//                 is_last_page: true,
//                 start_offset: 0,
//                 end_offset: 9,
//             }],
//         );
//         kv.save_layout_cache(&key, &cache).unwrap();

//         let repo = LayoutCacheRepository::new(kv.clone());
//         repo.invalidate_book_cache("book1").unwrap();

//         let loaded = kv.get_layout_cache(&key).unwrap();
//         assert!(loaded.is_none());
//     }
// }
