use flutter_rust_bridge::frb;
use sqlx::SqlitePool;

use crate::common::AppError;
use crate::domain::progress::models::{BookWithProgress, ReadingProgress};

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

#[frb(opaque)]
pub struct ProgressRepository;

impl ProgressRepository {
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
            .bind(progress.is_completed)
            .execute(pool)
            .await?;
        Ok(())
    }

    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Option<ReadingProgress>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingProgress>("SELECT * FROM reading_progress WHERE book_id = ?")
                .bind(book_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    pub async fn list_all_with_progress(pool: &SqlitePool) -> Result<Vec<BookWithProgress>, AppError> {
        use crate::domain::progress::models::BookWithProgressRow;
        let rows = sqlx::query_as::<_, BookWithProgressRow>(
            "SELECT b.*, rp.chapter_index AS progress_chapter_index, \
             rp.char_offset AS progress_char_offset, rp.progress AS progress_percent, \
             rp.last_read_at AS progress_last_read_at, \
             rp.is_completed AS progress_is_completed \
             FROM books b LEFT JOIN reading_progress rp ON b.id = rp.book_id \
             ORDER BY COALESCE(rp.last_read_at, b.created_at) DESC",
        )
        .fetch_all(pool)
        .await?;
        Ok(rows.into_iter().map(BookWithProgress::from).collect())
    }

    pub async fn clear_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM reading_progress WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}
