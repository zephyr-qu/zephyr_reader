use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：书籍仓储，管理书籍的增删改查及相关关联表操作
//
// 公有类型/函数：
//   - BookRepository — 书籍仓储结构体
//   - list() / list_bookshelf() / list_titles() — 列表查询
//   - find_by_id() / find_by_file_path() / search() — 单书查询
//   - save() / save_metadata() / delete_cascade() — 写入操作
//   - count() / update_status() / update_pin() — 统计与状态更新
// ============================================================

use crate::domain::AppError;
use crate::domain::book::{Book, BookStatus, BookTitle, BookshelfBook};
use sqlx::{QueryBuilder, SqlitePool};

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

/// 书籍仓储 — 管理书籍的增删改查及相关关联表操作
#[frb(opaque)]
pub struct BookRepository;

impl BookRepository {
    /// 级联删除书籍及其所有关联数据
    ///
    /// 事务内依次删除书签、笔记、章节、阅读进度、阅读会话、分类关联和元数据，最后删除书籍本体。
    pub async fn delete_cascade(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
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
    /// 获取所有书籍列表（按添加时间倒序）
    pub async fn list(pool: &SqlitePool) -> Result<Vec<Book>, AppError> {
        Ok(
            sqlx::query_as::<_, Book>("SELECT * FROM books ORDER BY added_at DESC")
                .fetch_all(pool)
                .await?,
        )
    }

    /// 获取所有书籍列表（无排序，供 progress_repo 等内部使用）
    pub async fn list_progress(pool: &SqlitePool) -> Result<Vec<Book>, AppError> {
        Ok(sqlx::query_as::<_, Book>("SELECT * FROM books")
            .fetch_all(pool)
            .await?)
    }

    /// 书架书籍列表（含阅读进度，单次 JOIN 查询）
    pub async fn list_bookshelf(
        pool: &SqlitePool,
        sort_by: &str,
        sort_order: &str,
    ) -> Result<Vec<BookshelfBook>, AppError> {
        let sort_column = match sort_by {
            "title" => "b.title",
            "last_opened_at" => "b.last_opened_at",
            "added_at" => "b.added_at",
            "author" => "b.author",
            "progress" => "rp.progress",
            _ => "b.added_at",
        };
        let order = if sort_order.eq_ignore_ascii_case("asc") {
            "ASC"
        } else {
            "DESC"
        };
        let mut builder = sqlx::QueryBuilder::<sqlx::Sqlite>::new(
            "SELECT b.id, b.file_path, b.title, b.author, b.cover_path, b.is_pinned, b.status, b.chapter_count, b.last_opened_at, b.added_at, rp.progress \
             FROM books b \
             LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             ORDER BY b.is_pinned DESC, ",
        );
        builder.push(sort_column);
        builder.push(" ");
        builder.push(order);
        Ok(builder
            .build_query_as::<BookshelfBook>()
            .fetch_all(pool)
            .await?)
    }

    /// 获取所有书籍的 ID 和标题
    pub async fn list_titles(pool: &SqlitePool) -> Result<Vec<BookTitle>, AppError> {
        Ok(
            sqlx::query_as::<_, BookTitle>("SELECT id, title FROM books")
                .fetch_all(pool)
                .await?,
        )
    }

    /// 按 ID 查找书籍（含元数据 LEFT JOIN）
    pub async fn find_by_id(pool: &SqlitePool, id: &str) -> Result<Option<Book>, AppError> {
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

    /// 按文件路径查找书籍
    pub async fn find_by_file_path(
        pool: &SqlitePool,
        file_path: &str,
    ) -> Result<Option<Book>, AppError> {
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

    /// 保存或更新书籍（UPSERT 热字段）
    pub async fn save(pool: &SqlitePool, book: &Book) -> Result<(), AppError> {
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
            .bind(book.added_at)
            .bind(book.last_opened_at)
            .bind(book.status.as_ref())
            .bind(book.is_pinned)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 保存或更新书籍元数据（UPSERT 冷字段）
    pub async fn save_metadata(pool: &SqlitePool, book: &Book) -> Result<(), AppError> {
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

    /// 按 ID 删除书籍
    pub async fn delete_by_id(pool: &SqlitePool, id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM books WHERE id = ?")
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 搜索书籍（标题或作者模糊匹配）
    pub async fn search(pool: &SqlitePool, keyword: &str) -> Result<Vec<Book>, AppError> {
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

    /// 书架搜索（标题或作者模糊匹配，含阅读进度）
    pub async fn search_bookshelf(
        pool: &SqlitePool,
        keyword: &str,
    ) -> Result<Vec<BookshelfBook>, AppError> {
        if keyword.trim().is_empty() {
            return Ok(Vec::new());
        }
        let escaped = keyword.replace('%', r"\%").replace('_', r"\_");
        let pattern = format!("%{}%", escaped);
        Ok(sqlx::query_as::<_, BookshelfBook>(
            "SELECT b.id, b.file_path, b.title, b.author, b.cover_path, b.is_pinned, b.status, b.chapter_count, b.last_opened_at, b.added_at, rp.progress \
             FROM books b \
             LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             WHERE b.title LIKE ? ESCAPE '\\' OR b.author LIKE ? ESCAPE '\\' \
             ORDER BY b.is_pinned DESC, b.last_opened_at DESC NULLS LAST",
        )
        .bind(&pattern)
        .bind(&pattern)
        .fetch_all(pool)
        .await?)
    }

    /// 按阅读状态筛选
    pub async fn list_by_status(
        pool: &SqlitePool,
        status: BookStatus,
    ) -> Result<Vec<Book>, AppError> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT * FROM books WHERE status = ? ORDER BY last_opened_at DESC NULLS LAST",
        )
        .bind(status.as_ref())
        .fetch_all(pool)
        .await?)
    }

    /// 按阅读状态筛选（书架版，含进度）
    pub async fn list_bookshelf_by_status(
        pool: &SqlitePool,
        status: BookStatus,
    ) -> Result<Vec<BookshelfBook>, AppError> {
        Ok(sqlx::query_as::<_, BookshelfBook>(
            "SELECT b.id, b.file_path, b.title, b.author, b.cover_path, b.is_pinned, b.status, b.chapter_count, b.last_opened_at, b.added_at, rp.progress \
             FROM books b \
             LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             WHERE b.status = ? \
             ORDER BY b.is_pinned DESC, b.last_opened_at DESC NULLS LAST",
        )
        .bind(status.as_ref())
        .fetch_all(pool)
        .await?)
    }

    /// 获取所有置顶书籍
    pub async fn list_pinned(pool: &SqlitePool) -> Result<Vec<Book>, AppError> {
        Ok(sqlx::query_as::<_, Book>(
            "SELECT * FROM books WHERE is_pinned = 1 ORDER BY last_opened_at DESC NULLS LAST",
        )
        .fetch_all(pool)
        .await?)
    }

    /// 获取最近阅读的书籍（关联 reading_progress 表）
    pub async fn list_recent(pool: &SqlitePool, limit: i64) -> Result<Vec<Book>, AppError> {
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
    ) -> Result<Vec<Book>, AppError> {
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
    pub async fn update_status(
        pool: &SqlitePool,
        id: &str,
        status: BookStatus,
    ) -> Result<(), AppError> {
        sqlx::query("UPDATE books SET status = ? WHERE id = ?")
            .bind(status.as_ref())
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 更新置顶状态
    pub async fn update_pin(pool: &SqlitePool, id: &str, is_pinned: bool) -> Result<(), AppError> {
        sqlx::query("UPDATE books SET is_pinned = ? WHERE id = ?")
            .bind(is_pinned as i32)
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 记录书籍被打开（最近阅读排序依据）
    pub async fn update_last_opened(pool: &SqlitePool, id: &str) -> Result<(), AppError> {
        sqlx::query("UPDATE books SET last_opened_at = ? WHERE id = ?")
            .bind(chrono::Utc::now())
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取书籍总数
    pub async fn count(pool: &SqlitePool) -> Result<i64, AppError> {
        //使用 query_scalar 替代手动 row.get
        Ok(sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM books")
            .fetch_one(pool)
            .await?)
    }

    /// 更新书籍标题
    pub async fn update_title(
        pool: &SqlitePool,
        book_id: &str,
        title: &str,
    ) -> Result<(), AppError> {
        sqlx::query("UPDATE books SET title = ? WHERE id = ?")
            .bind(title)
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 查找书籍封面路径
    pub async fn find_cover_path(
        pool: &SqlitePool,
        book_id: &str,
    ) -> Result<Option<String>, AppError> {
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
    ) -> Result<(), AppError> {
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
    ) -> Result<(), AppError> {
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
