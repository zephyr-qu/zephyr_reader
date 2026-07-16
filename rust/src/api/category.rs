//! 分类管理 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::book::{Book, BookStatus, BookshelfBook};
use crate::domain::category::Category;
use crate::domain::category::service;

/// 获取指定分类下的所有书籍列表
#[frb]
pub async fn list_books_by_category(category_id: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[category] list_books_by_category: category_id={}", category_id);
    service::list_books_by_category(&category_id).await
}

/// 获取指定分类下的所有书籍（书架版，含进度）
#[frb]
pub async fn list_bookshelf_books_by_category(category_id: String) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[category] list_bookshelf_books_by_category: category_id={}", category_id);
    service::list_bookshelf_books_by_category(&category_id).await
}

/// 获取指定分类和状态下的所有书籍（书架版）
#[frb]
pub async fn list_bookshelf_books_by_category_and_status(
    category_id: String,
    status: BookStatus,
) -> Result<Vec<BookshelfBook>, AppError> {
    tracing::debug!("[category] list_bookshelf_books_by_category_and_status: category_id={}, status={:?}", category_id, status);
    service::list_bookshelf_books_by_category_and_status(&category_id, status).await
}

/// 获取所有分类列表
#[frb]
pub async fn list_categories() -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories");
    service::list_categories().await
}

/// 创建分类
#[frb]
pub async fn create_category(
    name: String,
    color: String,
    sort_order: i32,
    description: Option<String>,
) -> Result<Category, AppError> {
    tracing::info!("[category] create_category: name={}", name);
    service::create_category(&name, &color, sort_order as i64, description).await
}

/// 新增或更新分类
#[frb]
pub async fn upsert_category(
    name: String,
    color: String,
    sort_order: i32,
    description: Option<String>,
) -> Result<Category, AppError> {
    service::upsert_category(&name, &color, sort_order as i64, description).await
}

/// 删除分类
#[frb]
pub async fn delete_category(category_id: String) -> Result<(), AppError> {
    tracing::info!("[category] delete_category: category_id={}", category_id);
    service::delete_category(&category_id).await
}

/// 根据 ID 获取分类
#[frb]
pub async fn get_category(category_id: String) -> Result<Option<Category>, AppError> {
    service::get_category(&category_id).await
}

/// 批量重排分类顺序（原子操作）
#[frb]
pub async fn reorder_categories(categories: Vec<Category>) -> Result<(), AppError> {
    service::reorder_categories(&categories).await
}

/// 获取书籍的所有分类列表
#[frb]
pub async fn list_categories_by_book(book_id: String) -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories_by_book: book_id={}", book_id);
    service::list_categories_by_book(&book_id).await
}

/// 为书籍分配分类
#[frb]
pub async fn assign_category_to_book(book_id: String, category_id: String) -> Result<(), AppError> {
    service::assign_category_to_book(&book_id, &category_id).await
}

/// 移除书籍的分类关联
#[frb]
pub async fn clear_category_from_book(book_id: String, category_id: String) -> Result<(), AppError> {
    service::clear_category_from_book(&book_id, &category_id).await
}

/// 设置书籍的分类列表
#[frb]
pub async fn set_categories_for_book(
    book_id: String,
    category_ids: Vec<String>,
) -> Result<(), AppError> {
    tracing::info!("[category] set_categories_for_book: book_id={}, count={}", book_id, category_ids.len());
    service::set_categories_for_book(&book_id, &category_ids).await
}

/// 清除书籍的所有分类
#[frb]
pub async fn clear_categories_by_book(book_id: String) -> Result<(), AppError> {
    service::clear_categories_by_book(&book_id).await
}
