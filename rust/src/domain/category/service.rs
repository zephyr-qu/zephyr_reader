//! 分类管理业务逻辑
//!
//! 提供分类的 CRUD、书籍分类关联和批量重排操作。
//! 数据访问委托给 CategoryRepository。

use crate::common::AppError;
use crate::domain::book::{Book, BookshelfBook, BookStatus};
use crate::domain::category::Category;
use crate::domain::category::category_repo::CategoryRepository;
use crate::infra::manager::storage_pool;

/// 获取所有分类
pub async fn list_categories() -> Result<Vec<Category>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::list(&pool).await
}

/// 创建分类
pub async fn create_category(
    name: &str,
    color: &str,
    sort_order: i64,
    description: Option<String>,
) -> Result<Category, AppError> {
    let category = Category::new(name, color, sort_order, description, false);
    let pool = storage_pool()?;
    CategoryRepository::save(&pool, &category).await
}

/// 新增或更新分类
pub async fn upsert_category(
    name: &str,
    color: &str,
    sort_order: i64,
    description: Option<String>,
) -> Result<Category, AppError> {
    let category = Category::new(name, color, sort_order, description, false);
    let pool = storage_pool()?;
    CategoryRepository::save(&pool, &category).await
}

/// 删除分类
pub async fn delete_category(category_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::delete_by_id(&pool, category_id).await
}

/// 根据 ID 获取分类
pub async fn get_category(category_id: &str) -> Result<Option<Category>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::find_by_id(&pool, category_id).await
}

/// 批量重排分类顺序
pub async fn reorder_categories(categories: &[Category]) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::reorder(&pool, categories).await
}

/// 获取书籍的所有分类
pub async fn list_categories_by_book(book_id: &str) -> Result<Vec<Category>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::list_by_book(&pool, book_id).await
}

/// 获取指定分类下的所有书籍
pub async fn list_books_by_category(category_id: &str) -> Result<Vec<Book>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::list_books_by_category(&pool, category_id).await
}

/// 获取指定分类下的所有书籍（书架版，含进度）
pub async fn list_bookshelf_books_by_category(category_id: &str) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::list_bookshelf_by_category(&pool, category_id).await
}

/// 获取指定分类和状态下的所有书籍（书架版）
pub async fn list_bookshelf_books_by_category_and_status(
    category_id: &str,
    status: BookStatus,
) -> Result<Vec<BookshelfBook>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::list_bookshelf_by_category_and_status(&pool, category_id, status).await
}

/// 为书籍分配分类
pub async fn assign_category_to_book(book_id: &str, category_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::assign_by_book(&pool, book_id, category_id).await
}

/// 移除书籍的分类关联
pub async fn clear_category_from_book(book_id: &str, category_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::remove_by_book(&pool, book_id, category_id).await
}

/// 设置书籍的分类列表
pub async fn set_categories_for_book(book_id: &str, category_ids: &[String]) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::set_by_book(&pool, book_id, category_ids).await
}

/// 清除书籍的所有分类
pub async fn clear_categories_by_book(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::clear_by_book(&pool, book_id).await
}
