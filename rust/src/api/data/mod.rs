//! 存储相关 API - 数据库操作
//!
//! 按业务领域拆分为多个子模块:
//! - init: 存储初始化
//! - book: 书籍管理
//! - progress: 阅读进度
//! - bookmark: 书签管理
//! - session: 阅读会话
//! - stats: 阅读统计
//! - chapter: 章节管理
//! - category: 分类管理
//! - note: 笔记管理
//! - vocabulary: 生词本
//! - dictionary: 词典管理 (合并到 crate::api::dictionary)
//!
//! 所有函数遵循命名规范:
//! - 查询单个: `get_xxx(id)` (无歧义时省略 by_id)
//! - 查询集合-通过外键: `list_xxxs_by_外键` (如 list_bookmarks_by_book)
//! - 新增: `create_xxx`
//! - 修改: `update_xxx`
//! - 新增或修改: `upsert_xxx`
//! - 删除: `delete_xxx(xxx_id)` (参数带自己ID时省略by_id)
//! - 清除关联: `clear_xxxs(外键_id)` (清除某实体的所有关联数据)

pub mod book;
pub mod bookmark;
pub mod category;
pub mod chapter;
pub mod init;
pub mod note;
pub mod progress;
pub mod session;
pub mod stats;
pub mod vocabulary;

// 导出异步存储宏（供子模块使用）
pub use crate::async_storage;
#[macro_export]
macro_rules! async_storage {
    ($op:expr) => {{
        let pool = $crate::storage::ensure_storage()
            .map_err(|_| $crate::domain::AppError::storage_not_initialized())?
            .pool()
            .map_err(|e| $crate::domain::AppError::database_error(e.to_string()))?;
        $op(&pool)
            .await
            .map_err(|e| $crate::domain::AppError::from(e))
    }};
}
