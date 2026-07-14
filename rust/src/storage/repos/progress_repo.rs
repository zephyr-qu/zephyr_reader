// ============================================================
// 文件作用：阅读进度仓储，管理阅读进度的增改查
//
// 公有类型/函数：
//   - ProgressRepository — 阅读进度仓储结构体
//   - save() — 保存或更新阅读进度
//   - find_by_book() — 获取指定书籍的进度
//   - list_all_with_progress() — 批量查询（书架展示用）
//   - clear_by_book() — 清除进度
// ============================================================

use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

const SQL_UPSERT_PROGRESS: &str = "\
INSERT INTO reading_progress (book_id, chapter_index, chunk_index, chapter_id, char_offset, progress, reading_time_seconds, last_read_at, is_completed) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9) \
ON CONFLICT(book_id) DO UPDATE SET \
chapter_index = excluded.chapter_index, \
chunk_index = excluded.chunk_index, \
chapter_id = excluded.chapter_id, \
char_offset = excluded.char_offset, \
progress = excluded.progress, \
reading_time_seconds = excluded.reading_time_seconds, \
last_read_at = excluded.last_read_at, \
is_completed = excluded.is_completed";

/// 阅读进度仓储 — 管理阅读进度的增改查
pub struct ProgressRepository;

impl ProgressRepository {
    /// 保存或更新阅读进度
    pub async fn save(pool: &SqlitePool, progress: &ReadingProgress) -> Result<(), AppError> {
        sqlx::query(SQL_UPSERT_PROGRESS)
            .bind(&progress.book_id)
            .bind(progress.chapter_index)
            .bind(progress.chunk_index)
            .bind(&progress.chapter_id)
            .bind(progress.char_offset)
            .bind(progress.progress)
            .bind(progress.reading_time_seconds)
            .bind(progress.last_read_at)
            .bind(progress.is_completed as i32)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取所有书籍的阅读进度（用于书架批量展示）
    ///
    /// 内部执行 2 次查询（books + progress），Rust 层按 book_id 匹配，
    /// 替代 Dart 侧 N+1 次 FRB 调用。
    pub async fn list_all_with_progress(pool: &SqlitePool) -> Result<Vec<BookWithProgress>, AppError> {
        let books = super::BookRepository::list_progress(pool).await?;
        let all_progress: Vec<ReadingProgress> =
            sqlx::query_as::<_, ReadingProgress>(
                "SELECT book_id, chapter_index, chunk_index, chapter_id, char_offset, progress, reading_time_seconds, last_read_at, is_completed FROM reading_progress"
            )
                .fetch_all(pool)
                .await?;

        let progress_map: std::collections::HashMap<&str, &ReadingProgress> = all_progress
            .iter()
            .map(|p| (p.book_id.as_str(), p))
            .collect();

        let result = books
            .into_iter()
            .map(|book| BookWithProgress {
                progress: progress_map.get(book.book_id.as_str()).copied().cloned(),
                book,
            })
            .collect();

        Ok(result)
    }

    /// 获取指定书籍的阅读进度
    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Option<ReadingProgress>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingProgress>(
                "SELECT book_id, chapter_index, chunk_index, chapter_id, char_offset, progress, reading_time_seconds, last_read_at, is_completed FROM reading_progress WHERE book_id = ?",
            )
            .bind(book_id)
            .fetch_optional(pool)
            .await?,
        )
    }

    /// 清除指定书籍的阅读进度
    pub async fn clear_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM reading_progress WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}
