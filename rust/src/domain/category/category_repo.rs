use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：分类仓储，管理书籍分类的增删改查
//
// 公有类型/函数：
//   - CategoryRepository — 分类仓储结构体
//   - list() / find_by_id() — 查询分类
//   - save() / delete_by_id() / reorder() — 写入与排序
//   - assign_by_book() / remove_by_book() / set_by_book() — 书籍分类关联
//   - list_by_book() / list_books_by_category() — 按分类查询
// ============================================================

use crate::domain::book::{Book, BookshelfBook, BookStatus};
use crate::domain::AppError;
use crate::domain::category::Category;
use sqlx::SqlitePool;

/// 分类仓储 — 管理书籍分类的增删改查
#[frb(opaque)]
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

    /// 获取指定分类下的所有书籍（书架版，含进度）
    pub async fn list_bookshelf_by_category(
        pool: &SqlitePool,
        category_id: &str,
    ) -> Result<Vec<BookshelfBook>, AppError> {
        Ok(sqlx::query_as::<_, BookshelfBook>(
            "SELECT b.id, b.file_path, b.title, b.author, b.cover_path, b.is_pinned, b.status, b.chapter_count, b.last_opened_at, b.added_at, rp.progress \
             FROM books b \
             INNER JOIN book_categories bc ON b.id = bc.book_id \
             LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             WHERE bc.category_id = ? \
             ORDER BY b.is_pinned DESC, b.last_opened_at DESC NULLS LAST",
        )
        .bind(category_id)
        .fetch_all(pool)
        .await?)
    }

    /// 获取指定分类和状态下的所有书籍（书架版，含进度，一次 SQL 过滤）
    pub async fn list_bookshelf_by_category_and_status(
        pool: &SqlitePool,
        category_id: &str,
        status: BookStatus,
    ) -> Result<Vec<BookshelfBook>, AppError> {
        Ok(sqlx::query_as::<_, BookshelfBook>(
            "SELECT b.id, b.file_path, b.title, b.author, b.cover_path, b.is_pinned, b.status, b.chapter_count, b.last_opened_at, b.added_at, rp.progress \
             FROM books b \
             INNER JOIN book_categories bc ON b.id = bc.book_id \
             LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             WHERE bc.category_id = ? AND b.status = ? \
             ORDER BY b.is_pinned DESC, b.last_opened_at DESC NULLS LAST",
        )
        .bind(category_id)
        .bind(status.as_ref())
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

    /// 批量更新分类排序（事务内原子操作）
    ///
    /// 接收已设置 `sort_order` 的分类列表，一次事务写入所有排序值。
    /// 替代 N 次串行 save() 调用，避免部分更新风险。
    pub async fn reorder(
        pool: &SqlitePool,
        categories: &[Category],
    ) -> Result<(), AppError> {
        let mut tx = pool.begin().await?;
        for cat in categories {
            sqlx::query("UPDATE categories SET sort_order = ? WHERE id = ?")
                .bind(cat.sort_order)
                .bind(&cat.id)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }
}
