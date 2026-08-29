use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;
use flutter_rust_bridge::frb;
use sqlx::SqlitePool;

const SQL_UPSERT_SESSION: &str = "\
INSERT INTO reading_sessions (id, book_id, chapter_index, started_at, ended_at, duration_seconds) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
started_at = excluded.started_at, \
ended_at = excluded.ended_at, \
duration_seconds = excluded.duration_seconds";

#[frb(opaque)]
pub struct SessionRepository;

impl SessionRepository {
    pub async fn save(
        pool: &SqlitePool,
        session: &ReadingSession,
    ) -> Result<ReadingSession, AppError> {
        sqlx::query(SQL_UPSERT_SESSION)
            .bind(&session.id)
            .bind(&session.book_id)
            .bind(session.chapter_index)
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
        Ok(sqlx::query_as::<_, ReadingSession>(
            "SELECT * FROM reading_sessions WHERE book_id = ? ORDER BY started_at DESC LIMIT ?",
        )
        .bind(book_id)
        .bind(limit)
        .fetch_all(pool)
        .await?)
    }

    pub async fn find_by_recent(
        pool: &SqlitePool,
        limit: i64,
    ) -> Result<Vec<ReadingSession>, AppError> {
        Ok(sqlx::query_as::<_, ReadingSession>(
            "SELECT * FROM reading_sessions ORDER BY started_at DESC LIMIT ?",
        )
        .bind(limit)
        .fetch_all(pool)
        .await?)
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
        let count: i32 =
            sqlx::query_scalar("SELECT COUNT(*) FROM reading_sessions WHERE book_id = ?")
                .bind(book_id)
                .fetch_one(pool)
                .await?;
        Ok(count)
    }

    /// 获取指定书籍的累计阅读时长（秒）——与统计页同一真相源。
    pub async fn total_duration_by_book(pool: &SqlitePool, book_id: &str) -> Result<i64, AppError> {
        let total: i64 = sqlx::query_scalar(
            "SELECT COALESCE(SUM(duration_seconds), 0) FROM reading_sessions WHERE book_id = ?",
        )
        .bind(book_id)
        .fetch_one(pool)
        .await?;
        Ok(total)
    }
}
