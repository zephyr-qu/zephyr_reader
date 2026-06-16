use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

/// 章节仓储 — 管理书籍章节的增删查
pub struct ChapterRepository;

impl ChapterRepository {
    /// 批量保存章节（事务内执行）
    pub async fn save(pool: &SqlitePool, book_id: &str, chapters: &[Chapter]) -> Result<(), AppError> {
        if chapters.is_empty() {
            return Ok(());
        }
        let mut tx = pool.begin().await?;
        for chapter in chapters {
            if chapter.book_id != book_id {
                return Err(AppError::DatabaseError { reason: format!(
                    "Chapter {} belongs to book {}, but expected {}",
                    chapter.id, chapter.book_id, book_id
                ).into() });
            }
            sqlx::query(
                "INSERT INTO chapters (id, book_id, title, chapter_index, cached_at, level, start_index, end_index) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8) \
                 ON CONFLICT(id) DO UPDATE SET \
                    book_id = excluded.book_id, \
                    title = excluded.title, \
                    chapter_index = excluded.chapter_index, \
                    cached_at = excluded.cached_at, \
                    level = excluded.level, \
                    start_index = excluded.start_index, \
                    end_index = excluded.end_index",
            )
            .bind(&chapter.id)
            .bind(&chapter.book_id)
            .bind(&chapter.title)
            .bind(chapter.chapter_index)
            .bind(chapter.cached_at)
            .bind(chapter.level)
            .bind(chapter.start_index)
            .bind(chapter.end_index)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    /// 获取指定书籍的所有章节（按索引升序）
    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Chapter>, AppError> {
        Ok(sqlx::query_as::<_, Chapter>(
            "SELECT * FROM chapters WHERE book_id = ? ORDER BY chapter_index",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    /// 按索引查找章节
    pub async fn find_by_index(
        pool: &SqlitePool,
        book_id: &str,
        index: i32,
    ) -> Result<Option<Chapter>, AppError> {
        Ok(sqlx::query_as::<_, Chapter>(
            "SELECT * FROM chapters WHERE book_id = ? AND chapter_index = ?",
        )
        .bind(book_id)
        .bind(index)
        .fetch_optional(pool)
        .await?)
    }

    /// 删除指定书籍的所有章节
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM chapters WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}

