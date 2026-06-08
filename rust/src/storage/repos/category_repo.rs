use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

/// 分类仓储 — 管理书籍分类的增删改查
pub struct CategoryRepository;

impl CategoryRepository {
    /// 获取所有分类（按排序权重升序）
    pub async fn list(pool: &SqlitePool) -> Result<Vec<Category>, AppError> {
        Ok(
            sqlx::query_as::<_, Category>("SELECT * FROM categories ORDER BY sort_order")
                .fetch_all(pool)
                .await?,
        )
    }

    /// 保存或更新分类
    pub async fn save(pool: &SqlitePool, category: &Category) -> Result<Category, AppError> {
        sqlx::query(
            "INSERT INTO categories (id, name, description, color, sort_order, is_system) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6) \
             ON CONFLICT(id) DO UPDATE SET \
                name = excluded.name, \
                description = excluded.description, \
                color = excluded.color, \
                sort_order = excluded.sort_order, \
                is_system = excluded.is_system",
        )
        .bind(&category.id)
        .bind(&category.name)
        .bind(&category.description)
        .bind(&category.color)
        .bind(category.sort_order)
        .bind(category.is_system as i32)
        .execute(pool)
        .await?;
        Ok(category.clone())
    }

    /// 删除分类
    pub async fn delete_by_id(pool: &SqlitePool, category_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM categories WHERE id = ?")
            .bind(category_id)
            .execute(pool)
            .await?;

        Ok(())
    }

    /// 按 ID 查找分类
    pub async fn find_by_id(pool: &SqlitePool, category_id: &str) -> Result<Option<Category>, AppError> {
        Ok(
            sqlx::query_as::<_, Category>("SELECT * FROM categories WHERE id = ?")
                .bind(category_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 为书籍分配分类（幂等操作）
    pub async fn assign_by_book(pool: &SqlitePool, book_id: &str, category_id: &str) -> Result<(), AppError> {
        // 关联表无需 UPDATE SET，DO NOTHING 即可实现幂等
        sqlx::query(
            "INSERT INTO book_categories (book_id, category_id) VALUES (?, ?) \
             ON CONFLICT(book_id, category_id) DO NOTHING",
        )
        .bind(book_id)
        .bind(category_id)
        .execute(pool)
        .await?;
        Ok(())
    }

    /// 移除书籍的某个分类
    pub async fn remove_by_book(pool: &SqlitePool, book_id: &str, category_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM book_categories WHERE book_id = ? AND category_id = ?")
            .bind(book_id)
            .bind(category_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取书籍的所有分类
    pub async fn list_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Category>, AppError> {
        Ok(sqlx::query_as::<_, Category>(
            "SELECT c.* FROM categories c \
             INNER JOIN book_categories bc ON c.id = bc.category_id \
             WHERE bc.book_id = ? ORDER BY c.sort_order",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    /// 获取指定分类下的所有书籍
    pub async fn list_books_by_category(pool: &SqlitePool, category_id: &str) -> Result<Vec<Book>, AppError> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT b.* FROM books b \
             INNER JOIN book_categories bc ON b.id = bc.book_id \
             WHERE bc.category_id = ? ORDER BY b.added_at DESC",
        )
        .bind(category_id)
        .fetch_all(pool)
        .await?)
    }

    /// 清除书籍的所有分类
    pub async fn clear_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM book_categories WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 设置书籍的分类列表（事务内先清后加）
    pub async fn set_by_book(
        pool: &SqlitePool,
        book_id: &str,
        category_ids: &[String],
    ) -> Result<(), AppError> {
        let mut tx = pool.begin().await?;
        sqlx::query("DELETE FROM book_categories WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;
        for cat_id in category_ids {
            sqlx::query(
                "INSERT INTO book_categories (book_id, category_id) VALUES (?, ?) \
                 ON CONFLICT(book_id, category_id) DO NOTHING",
            )
            .bind(book_id)
            .bind(cat_id)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }
}
// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::test_utils::*;
//     use crate::storage::repos::book_repo::BookRepository;

//     #[tokio::test]
//     async fn test_save_category() {
//         let pool = setup_test_db().await;
//         let cat = test_category();
//         CategoryRepository::save_category(&pool, &cat).await.unwrap();
//         let all = CategoryRepository::get_all_categories(&pool).await.unwrap();
//         assert_eq!(all.len(), 1);
//         assert_eq!(all[0].name, "科幻");
//     }

//     #[tokio::test]
//     async fn test_get_all_categories_empty() {
//         let pool = setup_test_db().await;
//         let all = CategoryRepository::get_all_categories(&pool).await.unwrap();
//         assert!(all.is_empty());
//     }

//     #[tokio::test]
//     async fn test_assign_remove_book_category() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let cat = test_category();
//         CategoryRepository::save_category(&pool, &cat).await.unwrap();
//         CategoryRepository::assign_category(&pool, "book1", "cat1").await.unwrap();
//         let cats = CategoryRepository::get_categories_for_book(&pool, "book1").await.unwrap();
//         assert_eq!(cats.len(), 1);
//         CategoryRepository::remove_category(&pool, "book1", "cat1").await.unwrap();
//         let cats = CategoryRepository::get_categories_for_book(&pool, "book1").await.unwrap();
//         assert!(cats.is_empty());
//     }

//     #[tokio::test]
//     async fn test_delete_category() {
//         let pool = setup_test_db().await;
//         let cat = test_category();
//         CategoryRepository::save_category(&pool, &cat).await.unwrap();
//         CategoryRepository::delete_category(&pool, "cat1").await.unwrap();
//         let all = CategoryRepository::get_all_categories(&pool).await.unwrap();
//         assert!(all.is_empty());
//     }

//     #[tokio::test]
//     async fn test_clear_categories_for_book() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let cat = test_category();
//         CategoryRepository::save_category(&pool, &cat).await.unwrap();
//         CategoryRepository::assign_category(&pool, "book1", "cat1").await.unwrap();
//         CategoryRepository::clear_categories_for_book(&pool, "book1").await.unwrap();
//         let cats = CategoryRepository::get_categories_for_book(&pool, "book1").await.unwrap();
//         assert!(cats.is_empty());
//     }
// }
