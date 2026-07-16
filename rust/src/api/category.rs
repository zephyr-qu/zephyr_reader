//! 分类管理 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::book::Book;
use crate::domain::category::Category;
use crate::domain::category::category_repo::CategoryRepository;
use crate::infra::manager::storage_pool;
/// 获取指定分类下的所有书籍列表
#[frb]
pub async fn list_books_by_category(category_id: String) -> Result<Vec<Book>, AppError> {
    tracing::debug!("[category] list_books_by_category: category_id={}", category_id);
    let pool = storage_pool()?;
    CategoryRepository::list_books_by_category(&pool, &category_id).await
}



/// 获取所有分类列表
#[frb]
pub async fn list_categories() -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories");
    let pool = storage_pool()?;
    CategoryRepository::list(&pool).await
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
    let category = Category::new(&name, &color, sort_order as i64, description, false);
    let pool = storage_pool()?;
    CategoryRepository::save(&pool, &category).await
}

/// 新增或更新分类
#[frb]
pub async fn upsert_category(
    name: String,
    color: String,
    sort_order: i32,
    description: Option<String>,
) -> Result<Category, AppError> {
    let category = Category::new(&name, &color, sort_order as i64, description, false);
    let pool = storage_pool()?;
    CategoryRepository::save(&pool, &category).await
}

/// 删除分类
#[frb]
pub async fn delete_category(category_id: String) -> Result<(), AppError> {
    tracing::info!("[category] delete_category: category_id={}", category_id);
    let pool = storage_pool()?;
    CategoryRepository::delete_by_id(&pool, &category_id).await
}

/// 根据 ID 获取分类
#[frb]
pub async fn get_category(category_id: String) -> Result<Option<Category>, AppError> {
    let pool = storage_pool()?;
    CategoryRepository::find_by_id(&pool, &category_id).await
}

/// 批量重排分类顺序（原子操作）
#[frb]
pub async fn reorder_categories(categories: Vec<Category>) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::reorder(&pool, &categories).await
}

/// 获取书籍的所有分类列表
#[frb]
pub async fn list_categories_by_book(book_id: String) -> Result<Vec<Category>, AppError> {
    tracing::debug!("[category] list_categories_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    CategoryRepository::list_by_book(&pool, &book_id).await
}

/// 为书籍分配分类
#[frb]
pub async fn assign_category_to_book(book_id: String, category_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::assign_by_book(&pool, &book_id, &category_id).await
}

/// 移除书籍的分类关联
#[frb]
pub async fn clear_category_from_book(book_id: String, category_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::remove_by_book(&pool, &book_id, &category_id).await
}

/// 设置书籍的分类列表
#[frb]
pub async fn set_categories_for_book(
    book_id: String,
    category_ids: Vec<String>,
) -> Result<(), AppError> {
    tracing::info!("[category] set_categories_for_book: book_id={}, count={}", book_id, category_ids.len());
    let pool = storage_pool()?;
    CategoryRepository::set_by_book(&pool, &book_id, &category_ids).await
}

/// 清除书籍的所有分类
#[frb]
pub async fn clear_categories_by_book(book_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    CategoryRepository::clear_by_book(&pool, &book_id).await
}



