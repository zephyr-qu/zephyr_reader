use anyhow::Result;
use sqlx::{QueryBuilder, SqlitePool};

use super::super::models::*;

/// 书籍热字段 UPSERT
const SQL_UPSERT_BOOK: &str = "\
INSERT INTO books (id, file_path, file_size, file_mtime, file_hash, title, author, cover_path, chapter_count, total_characters, format, added_at, last_opened_at, status, is_pinned) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15) \
ON CONFLICT(id) DO UPDATE SET \
file_path = excluded.file_path, file_size = excluded.file_size, \
file_mtime = excluded.file_mtime, file_hash = excluded.file_hash, \
title = excluded.title, author = excluded.author, \
cover_path = excluded.cover_path, \
chapter_count = excluded.chapter_count, total_characters = excluded.total_characters, \
format = excluded.format, added_at = excluded.added_at, \
last_opened_at = excluded.last_opened_at, \
status = excluded.status, is_pinned = excluded.is_pinned";

/// 书籍冷字段 UPSERT
const SQL_UPSERT_BOOK_METADATA: &str = "\
INSERT INTO book_metadata (book_id, description, publisher, translator, isbn) \
VALUES (?1, ?2, ?3, ?4, ?5) \
ON CONFLICT(book_id) DO UPDATE SET \
description = excluded.description, publisher = excluded.publisher, \
translator = excluded.translator, isbn = excluded.isbn";

pub struct BookRepository;

impl BookRepository {
    pub async fn delete_cascade(pool: &SqlitePool, book_id: &str) -> Result<()> {
        let mut tx = pool.begin().await?;

        // 先删关联表（避免外键约束冲突，若启用了 foreign_keys）
        sqlx::query("DELETE FROM bookmarks WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM notes WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM chapters WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM reading_progress WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM reading_sessions WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM book_categories WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM book_metadata WHERE book_id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        // 最后删书籍本体
        sqlx::query("DELETE FROM books WHERE id = ?")
            .bind(book_id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;
        Ok(())
    }
    pub async fn list(pool: &SqlitePool) -> Result<Vec<Book>> {
        // 直接使用 query_as，FromRow 自动完成所有映射
        Ok(sqlx::query_as::<_, Book>("SELECT * FROM books")
            .fetch_all(pool)
            .await?)
    }

    pub async fn list_titles(pool: &SqlitePool) -> Result<Vec<BookTitle>> {
        Ok(sqlx::query_as::<_, BookTitle>("SELECT id, title FROM books")
            .fetch_all(pool)
            .await?)
    }

    pub async fn find_by_id(pool: &SqlitePool, id: &str) -> Result<Option<Book>> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT b.*, m.description, m.publisher, m.translator, m.isbn \
             FROM books b \
             LEFT JOIN book_metadata m ON b.id = m.book_id \
             WHERE b.id = ?",
        )
        .bind(id)
        .fetch_optional(pool)
        .await?)
    }

    pub async fn find_by_file_path(pool: &SqlitePool, file_path: &str) -> Result<Option<Book>> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT b.*, m.description, m.publisher, m.translator, m.isbn \
             FROM books b \
             LEFT JOIN book_metadata m ON b.id = m.book_id \
             WHERE b.file_path = ?",
        )
        .bind(file_path)
        .fetch_optional(pool)
        .await?)
    }

    pub async fn save(pool: &SqlitePool, book: &Book) -> Result<()> {
        sqlx::query(SQL_UPSERT_BOOK)
            .bind(&book.book_id)
            .bind(&book.file_path)
            .bind(book.file_size)
            .bind(book.file_mtime)
            .bind(&book.file_hash)
            .bind(&book.title)
            .bind(&book.author)
            .bind(&book.cover_path)
            .bind(book.chapter_count)
            .bind(book.total_characters)
            .bind(book.format.as_ref())
            .bind(book.added_at.timestamp())
            .bind(book.last_opened_at.map(|d| d.timestamp()))
            .bind(book.status.as_ref())
            .bind(book.is_pinned)
            .execute(pool)
            .await?;
        Ok(())
    }

    pub async fn save_metadata(pool: &SqlitePool, book: &Book) -> Result<()> {
        sqlx::query(SQL_UPSERT_BOOK_METADATA)
            .bind(&book.book_id)
            .bind(&book.description)
            .bind(&book.publisher)
            .bind(&book.translator)
            .bind(&book.isbn)
            .execute(pool)
            .await?;
        Ok(())
    }

    pub async fn delete_by_id(pool: &SqlitePool, id: &str) -> Result<()> {
        sqlx::query("DELETE FROM books WHERE id = ?")
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 搜索书籍（标题或作者模糊匹配）
    pub async fn search(pool: &SqlitePool, keyword: &str) -> Result<Vec<Book>> {
        if keyword.trim().is_empty() {
            return Ok(Vec::new());
        }
        let escaped = keyword.replace('%', r"\%").replace('_', r"\_");
        let pattern = format!("%{}%", escaped);
        Ok(sqlx::query_as::<_, Book>(
            "SELECT * FROM books \
             WHERE title LIKE ? ESCAPE '\\' OR author LIKE ? ESCAPE '\\' \
             ORDER BY last_opened_at DESC NULLS LAST",
        )
        .bind(&pattern)
        .bind(&pattern)
        .fetch_all(pool)
        .await?)
    }

    /// 按阅读状态筛选
    pub async fn list_by_status(pool: &SqlitePool, status: BookStatus) -> Result<Vec<Book>> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT * FROM books WHERE status = ? ORDER BY last_opened_at DESC NULLS LAST",
        )
        .bind(status.as_ref())
        .fetch_all(pool)
        .await?)
    }

    /// 获取所有置顶书籍
    pub async fn list_pinned(pool: &SqlitePool) -> Result<Vec<Book>> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT * FROM books WHERE is_pinned = 1 ORDER BY last_opened_at DESC NULLS LAST",
        )
        .fetch_all(pool)
        .await?)
    }

    /// 获取最近阅读的书籍（关联 reading_progress 表）
    pub async fn list_recent(pool: &SqlitePool, limit: i64) -> Result<Vec<Book>> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT b.* FROM books b \
             JOIN reading_progress p ON b.id = p.book_id \
             WHERE p.last_read_at IS NOT NULL \
             ORDER BY p.last_read_at DESC LIMIT ?",
        )
        .bind(limit)
        .fetch_all(pool)
        .await?)
    }

    /// 分页列表（支持动态排序）
    pub async fn list_paginated(
        pool: &SqlitePool,
        limit: i64,
        offset: i64,
        sort_by: &str,
        sort_order: &str,
    ) -> Result<Vec<Book>> {
        let mut builder = QueryBuilder::<sqlx::Sqlite>::new("SELECT * FROM books ORDER BY ");

        // 白名单校验
        let sort_column = match sort_by {
            "title" => "title",
            "added_at" => "added_at",
            "last_opened_at" => "last_opened_at",
            "file_size" => "file_size",
            _ => "added_at",
        };
        builder.push(sort_column);
        builder.push(" ");

        let order = if sort_order.eq_ignore_ascii_case("asc") {
            "ASC"
        } else {
            "DESC"
        };
        builder.push(order);
        builder.push(" LIMIT ");
        builder.push_bind(limit);
        builder.push(" OFFSET ");
        builder.push_bind(offset);

        Ok(builder.build_query_as::<Book>().fetch_all(pool).await?)
    }

    /// 更新阅读状态
    pub async fn update_status(pool: &SqlitePool, id: &str, status: BookStatus) -> Result<()> {
        sqlx::query("UPDATE books SET status = ? WHERE id = ?")
            .bind(status.as_ref())
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 更新置顶状态
    pub async fn update_pin(pool: &SqlitePool, id: &str, is_pinned: bool) -> Result<()> {
        sqlx::query("UPDATE books SET is_pinned = ? WHERE id = ?")
            .bind(is_pinned as i32)
            .bind(id)
            .execute(pool)
            .await?;

        Ok(())
    }

    /// 获取书籍总数
    pub async fn count(pool: &SqlitePool) -> Result<i64> {
        //使用 query_scalar 替代手动 row.get
        Ok(sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM books")
            .fetch_one(pool)
            .await?)
    }

    /// 更新书籍标题
    pub async fn update_title(pool: &SqlitePool, book_id: &str, title: &str) -> Result<()> {
        sqlx::query("UPDATE books SET title = ? WHERE id = ?")
            .bind(title)
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 查找书籍封面路径
    pub async fn find_cover_path(pool: &SqlitePool, book_id: &str) -> Result<Option<String>> {
        let row: Option<(String,)> =
            sqlx::query_as("SELECT cover_path FROM books WHERE id = ? AND cover_path IS NOT NULL")
                .bind(book_id)
                .fetch_optional(pool)
                .await?;
        Ok(row.map(|r| r.0))
    }

    /// 更新书籍封面路径
    pub async fn update_cover_path(
        pool: &SqlitePool,
        book_id: &str,
        cover_path: &str,
    ) -> Result<()> {
        sqlx::query("UPDATE books SET cover_path = ? WHERE id = ?")
            .bind(cover_path)
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 批量更新书籍元数据（仅更新 Some 字段）
    pub async fn update_metadata(
        pool: &SqlitePool,
        book_id: &str,
        title: Option<&str>,
        author: Option<&str>,
        description: Option<&str>,
    ) -> Result<()> {
        let mut tx = pool.begin().await?;
        if let Some(v) = title {
            sqlx::query("UPDATE books SET title = ?1 WHERE id = ?2")
                .bind(v)
                .bind(book_id)
                .execute(&mut *tx)
                .await?;
        }
        if let Some(v) = author {
            sqlx::query("UPDATE books SET author = ?1 WHERE id = ?2")
                .bind(v)
                .bind(book_id)
                .execute(&mut *tx)
                .await?;
        }
        if let Some(v) = description {
            sqlx::query(
                "INSERT INTO book_metadata (book_id, description) VALUES (?1, ?2) \
                 ON CONFLICT(book_id) DO UPDATE SET description = excluded.description",
            )
            .bind(book_id)
            .bind(v)
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

//     #[tokio::test]
//     async fn test_save_new_book() {
//         let pool = setup_test_db().await;
//         let book = test_book();
//         BookRepository::save(&pool, &book).await.unwrap();
//         let saved = BookRepository::find_by_id(&pool, "book1").await.unwrap().unwrap();
//         assert_eq!(saved.title, "测试书籍");
//         assert_eq!(saved.author.unwrap(), "作者A");
//         assert_eq!(saved.format, BookFormat::Txt);
//     }

//     #[tokio::test]
//     async fn test_save_update_book() {
//         let pool = setup_test_db().await;
//         let book = test_book();
//         BookRepository::save(&pool, &book).await.unwrap();
//         let mut updated = book;
//         updated.title = "更新标题".to_string();
//         updated.status = BookStatus::Completed;
//         BookRepository::save(&pool, &updated).await.unwrap();
//         let saved = BookRepository::find_by_id(&pool, "book1").await.unwrap().unwrap();
//         assert_eq!(saved.title, "更新标题");
//         assert_eq!(saved.status, BookStatus::Completed);
//     }

//     #[tokio::test]
//     async fn test_find_by_id_not_found() {
//         let pool = setup_test_db().await;
//         let result = BookRepository::find_by_id(&pool, "nonexistent").await.unwrap();
//         assert!(result.is_none());
//     }

//     #[tokio::test]
//     async fn test_find_by_file_path() {
//         let pool = setup_test_db().await;
//         let book = test_book();
//         BookRepository::save(&pool, &book).await.unwrap();
//         let found = BookRepository::find_by_file_path(&pool, "/path/to/book.txt").await.unwrap();
//         assert!(found.is_some());
//         let not_found = BookRepository::find_by_file_path(&pool, "/nonexistent.txt").await.unwrap();
//         assert!(not_found.is_none());
//     }

//     #[tokio::test]
//     async fn test_search_keyword() {
//         let pool = setup_test_db().await;
//         let book = test_book();
//         BookRepository::save(&pool, &book).await.unwrap();
//         let mut book2 = test_book();
//         book2.book_id = "book2".to_string();
//         book2.title = "英语学习".to_string();
//         BookRepository::save(&pool, &book2).await.unwrap();
//         let results = BookRepository::search(&pool, "测试").await.unwrap();
//         assert_eq!(results.len(), 1);
//         assert_eq!(results[0].book_id, "book1");
//         let empty = BookRepository::search(&pool, "").await.unwrap();
//         assert!(empty.is_empty());
//     }

//     #[tokio::test]
//     async fn test_list_paginated() {
//         let pool = setup_test_db().await;
//         for i in 0..5 {
//             let mut book = test_book();
//             book.book_id = format!("book{}", i + 1);
//             book.title = format!("Book {}", i + 1);
//             BookRepository::save(&pool, &book).await.unwrap();
//         }
//         let page1 = BookRepository::list_paginated(&pool, 2, 0, "title", "asc").await.unwrap();
//         assert_eq!(page1.len(), 2);
//         let page2 = BookRepository::list_paginated(&pool, 2, 2, "title", "asc").await.unwrap();
//         assert_eq!(page2.len(), 2);
//     }

//     #[tokio::test]
//     async fn test_delete_book() {
//         let pool = setup_test_db().await;
//         let book = test_book();
//         BookRepository::save(&pool, &book).await.unwrap();
//         BookRepository::delete_by_id(&pool, "book1").await.unwrap();
//         let found = BookRepository::find_by_id(&pool, "book1").await.unwrap();
//         assert!(found.is_none());
//     }
// }
