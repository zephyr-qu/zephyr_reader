//! 分类管理 API
//!
//! 提供书籍分类的 CRUD 操作和分类分配功能。
//!
//! @dart_call - 被 Dart 侧 CategoryService 调用

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::CategoryRepository;

pub use crate::storage::models::{Book, BookshelfBook, BookStatus, Category};

// ============================================================
// 文件作用：分类管理 API — 分类 CRUD、书籍分类分配。
//
// 公有函数：
//   - list_books_by_category() — 分类下的书籍列表
//   - list_bookshelf_books_by_category() — 书架版（含进度）
//   - list_bookshelf_books_by_category_and_status() — 分类+状态筛选
//   - list_categories() — 获取所有分类
//   - create_category() — 创建分类
//   - upsert_category() — 新增或更新分类
//   - delete_category() — 删除分类
//   - get_category() — 根据 ID 获取
//   - reorder_categories() — 批量重排顺序
//   - list_categories_by_book() — 书籍的所有分类
//   - assign_category_to_book() — 为书籍分配分类
//   - clear_category_from_book() — 移除分类关联
//   - set_categories_for_book() — 设置书籍分类列表
//   - clear_categories_by_book() — 清除书籍所有分类
// ============================================================

/// 获取指定分类下的所有书籍列表
///
/// 替代 Dart 侧 list() + N×listByBook() 的 N+1 查询。
///
/// # 参数
/// * `category_id` - 分类 ID
///
/// # 返回
/// 该分类下的书籍列表
#[frb]
pub async fn list_books_by_category(category_id: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[category] list_books_by_category: category_id={}", category_id);
    async_storage!(|pool| CategoryRepository::list_books_by_category(pool, &category_id))
}

/// 获取指定分类下的所有书籍（书架版，含进度）
#[frb]
pub async fn list_bookshelf_books_by_category(category_id: String) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[category] list_bookshelf_books_by_category: category_id={}", category_id);
    async_storage!(|pool| CategoryRepository::list_bookshelf_by_category(pool, &category_id))
}

/// 获取指定分类和状态下的所有书籍（书架版，含进度，一次 SQL 过滤）
#[frb]
pub async fn list_bookshelf_books_by_category_and_status(
    category_id: String,
    status: BookStatus,
) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!(
        "[category] list_bookshelf_books_by_category_and_status: category_id={}, status={:?}",
        category_id,
        status,
    );
    async_storage!(|pool| CategoryRepository::list_bookshelf_by_category_and_status(pool, &category_id, status))
}

/// 获取所有分类列表
///
/// # 返回
/// 所有分类对象列表
#[frb]
pub async fn list_categories() -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories");
    async_storage!(|pool| CategoryRepository::list(pool))
}

/// 创建分类（自动生成 UUID）
///
/// # 参数
/// * `name` - 分类名称
/// * `color` - 显示颜色
/// * `sort_order` - 排序序号
/// * `description` - 描述（可选）
///
/// # 返回
/// 创建完成的分类对象
#[frb]
pub async fn create_category(
    name: String,
    color: String,
    sort_order: i32,
    description: Option<String>,
) -> Result<Category, AppError> {
    tracing::info!("[category] create_category: name={}", name);
    let category = Category::new(&name, &color, sort_order as i64, description.as_deref(), false);
    async_storage!(|pool| CategoryRepository::save(pool, &category))
}

/// 新增或更新分类(upsert)
///
/// 如果 `category_id` 为 None，自动生成新 UUID（用于创建）；
/// 如果为 Some，则使用该 ID（用于更新已有分类）。
///
/// # 参数
/// * `name` - 分类名称
/// * `color` - 显示颜色
/// * `sort_order` - 排序序号
/// * `description` - 描述（可选）
/// * `category_id` - 分类 ID（可选，更新时传入）
///
/// # 返回
/// 保存后的分类对象
#[frb]
pub async fn upsert_category(
    name: String,
    color: String,
    sort_order: i32,
    description: Option<String>,
) -> Result<Category, AppError> {
    let category = Category::new(&name, &color, sort_order as i64, description.as_deref(), false);
    async_storage!(|pool| CategoryRepository::save(pool, &category))
}
/// 删除分类
///
/// # 参数
/// * `category_id` - 分类 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_category(category_id: String) -> Result<(), AppError> {
    tracing::info!("[category] delete_category: category_id={}", category_id);
    async_storage!(|pool| CategoryRepository::delete_by_id(pool, &category_id))
}

/// 根据 ID 获取分类
///
/// # 参数
/// * `category_id` - 分类 ID
///
/// # 返回
/// 存在则返回 Some(Category), 否则返回 None
#[frb]
pub async fn get_category(category_id: String) -> Result<Option<Category>, AppError> {
    async_storage!(|pool| CategoryRepository::find_by_id(pool, &category_id))
}

/// 批量重排分类顺序（原子操作）
///
/// 接收已更新 `sort_order` 的分类列表，在事务内一次性写入所有排序值。
/// 替代 Dart 侧 N 次串行 `updateCategory` 调用，避免部分更新风险。
#[frb]
pub async fn reorder_categories(categories: Vec<Category>) -> Result<(), AppError> {
    let pool = crate::storage::ensure_storage()?.pool()?;
    CategoryRepository::reorder(&pool, &categories).await
}

/// 获取书籍的所有分类列表
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 该书籍的所有分类列表
#[frb]
pub async fn list_categories_by_book(book_id: String) -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories_by_book: book_id={}", book_id);
    async_storage!(|pool| CategoryRepository::list_by_book(pool, &book_id))
}

/// 为书籍分配分类
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `category_id` - 分类 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn assign_category_to_book(book_id: String, category_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::assign_by_book(pool, &book_id, &category_id))
}

/// 移除书籍的分类关联
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `category_id` - 分类 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_category_from_book(
    book_id: String,
    category_id: String,
) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::remove_by_book(pool, &book_id, &category_id))
}

/// 设置书籍的分类列表(替换原有分类)
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `category_ids` - 新的分类 ID 列表
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn set_categories_for_book(
    book_id: String,
    category_ids: Vec<String>,
) -> Result<(), AppError> {
    tracing::info!("[category] set_categories_for_book: book_id={}, count={}", book_id, category_ids.len());
    async_storage!(|pool| CategoryRepository::set_by_book(pool, &book_id, &category_ids))
}

/// 清除书籍的所有分类
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_categories_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::clear_by_book(pool, &book_id))
}
