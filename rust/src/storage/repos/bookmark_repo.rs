use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

const SQL_UPSERT_BOOKMARK: &str = "\
INSERT INTO bookmarks (id, book_id, chapter_index, chapter_id, char_offset, title, created_at) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
chapter_id = excluded.chapter_id, \
char_offset = excluded.char_offset, \
title = excluded.title, \
created_at = excluded.created_at";

/// 书签仓储 — 管理书签的增删改查
pub struct BookmarkRepository;

impl BookmarkRepository {
    /// 创建或更新书签
    pub async fn save(pool: &SqlitePool, bookmark: &Bookmark) -> Result<Bookmark, AppError> {
        sqlx::query(SQL_UPSERT_BOOKMARK)
            .bind(&bookmark.id)
            .bind(&bookmark.book_id)
            .bind(bookmark.chapter_index)
            .bind(&bookmark.chapter_id)
            .bind(bookmark.char_offset)
            .bind(&bookmark.title)
            .bind(bookmark.created_at)
            .execute(pool)
            .await?;
        Ok(bookmark.clone())
    }

    /// 获取指定书籍的所有书签
    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Bookmark>, AppError> {
        Ok(sqlx::query_as::<_, Bookmark>(
            "SELECT * FROM bookmarks WHERE book_id = ? ORDER BY chapter_index, char_offset",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    /// 删除单个书签
    pub async fn delete_by_id(pool: &SqlitePool, bookmark_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM bookmarks WHERE id = ?")
            .bind(bookmark_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 按 ID 查找书签
    pub async fn find_by_id(pool: &SqlitePool, bookmark_id: &str) -> Result<Option<Bookmark>, AppError> {
        Ok(
            sqlx::query_as::<_, Bookmark>("SELECT * FROM bookmarks WHERE id = ?")
                .bind(bookmark_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 批量导入书签
    pub async fn import_bookmarks(pool: &SqlitePool, bookmarks: &[Bookmark]) -> Result<(), AppError> {
        if bookmarks.is_empty() {
            return Ok(());
        }
        let mut tx = pool.begin().await?;
        for bookmark in bookmarks {
            sqlx::query(SQL_UPSERT_BOOKMARK)
                .bind(&bookmark.id)
                .bind(&bookmark.book_id)
                .bind(bookmark.chapter_index)
                .bind(&bookmark.chapter_id)
                .bind(bookmark.char_offset)
                .bind(&bookmark.title)
                .bind(bookmark.created_at)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }
    /// 删除指定书籍的所有书签
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM bookmarks WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 批量删除指定 ID 列表中的书签（事务内执行）。
    pub async fn delete_by_ids(
        pool: &SqlitePool,
        ids: &[String],
    ) -> Result<(), AppError> {
        if ids.is_empty() {
            return Ok(());
        }
        let mut tx = pool.begin().await?;
        for id in ids {
            sqlx::query("DELETE FROM bookmarks WHERE id = ?")
                .bind(id)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    /// 获取指定书籍的书签数量
    pub async fn count_by_book(pool: &SqlitePool, book_id: &str) -> Result<i32, AppError> {
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM bookmarks WHERE book_id = ?")
            .bind(book_id)
            .fetch_one(pool)
            .await?;
        Ok(count as i32)
    }
}

