//! 运行时基础设施层 — 有状态的服务初始化与管理
//!
//! 模块：
//!   - manager — 存储管理器（SQLite + redb KV + 全局单例 + 初始化入口）
//!   - kv_store — Sled KV 缓存实例
//!   - init — 应用启动初始化

pub mod init;
pub mod kv_store;
pub mod manager;

pub use init::init_app;
pub use init::test_connection;
pub use manager::StorageManager;

// ==================== 宏 ====================

pub use crate::async_storage;
#[macro_export]
macro_rules! async_storage {
    ($op:expr) => {{
        let pool = $crate::infra::ensure_storage()?.pool()?;
        $op(&pool).await
    }};
}
pub use manager::{ensure_storage, storage, storage_pool};
