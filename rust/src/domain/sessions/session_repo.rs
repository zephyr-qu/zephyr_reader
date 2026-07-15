use flutter_rust_bridge::frb;
use chrono::NaiveDate;
use sqlx::SqlitePool;
use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;

const SQL_UPSERT_SESSION: &str = "\
INSERT INTO reading_sessions (id, book_id, chapter_index, start_char_offset, end_char_offset, started_at, ended_at, duration_seconds) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
start_char_offset = excluded.start_char_offset, \
end_char_offset = excluded.end_char_offset, \
started_at = excluded.started_at, \
ended_at = excluded.ended_at, \
duration_seconds = excluded.duration_seconds";

#[frb(opaque)]
pub struct SessionRepository;

impl SessionRepository {
    pub async fn save(pool: &SqlitePool, session: &ReadingSession) -> Result<ReadingSession, AppError> {
        sqlx::query(SQL_UPSERT_SESSION)
            .bind(&session.id)
            .bind(&session.book_id)
            .bind(session.chapter_index)
            .bind(session.start_char_offset)
            .bind(session.end_char_offset)
            .bind(session.started_at)
            .bind(session.ended_at)
            .bind(session.duration_seconds)
            .execute(pool)
            .await?;
        Ok(session.clone())
    }

    pub async fn find_by_book(
        pool: &SqlitePool,
        book_id: &str,
        limit: i64,
    ) -> Result<Vec<ReadingSession>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingSession>(
                "SELECT * FROM reading_sessions WHERE book_id = ? ORDER BY started_at DESC LIMIT ?",
            )
            .bind(book_id)
            .bind(limit)
            .fetch_all(pool)
            .await?,
        )
    }

    pub async fn find_by_date_range(
        pool: &SqlitePool,
        book_id: &str,
        start: NaiveDate,
        end: NaiveDate,
    ) -> Result<Vec<ReadingSession>, AppError> {
        let start_dt = start.and_hms_opt(0, 0, 0).unwrap();
        let end_dt = end.and_hms_opt(23, 59, 59).unwrap();
        Ok(
            sqlx::query_as::<_, ReadingSession>(
                "SELECT * FROM reading_sessions WHERE book_id = ? AND started_at BETWEEN ? AND ? ORDER BY started_at",
            )
            .bind(book_id)
            .bind(start_dt)
            .bind(end_dt)
            .fetch_all(pool)
            .await?,
        )
    }

    pub async fn find_by_recent(
        pool: &SqlitePool,
        limit: i64,
    ) -> Result<Vec<ReadingSession>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingSession>(
                "SELECT * FROM reading_sessions ORDER BY started_at DESC LIMIT ?",
            )
            .bind(limit)
            .fetch_all(pool)
            .await?,
        )
    }

    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM reading_sessions WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取指定书籍的会话数量
    pub async fn count_by_book(pool: &SqlitePool, book_id: &str) -> Result<i32, AppError> {
        let count: i32 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM reading_sessions WHERE book_id = ?",
        )
        .bind(book_id)
        .fetch_one(pool)
        .await?;
        Ok(count)
    }
}
