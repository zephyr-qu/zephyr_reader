use flutter_rust_bridge::frb;
use sqlx::SqlitePool;

use crate::common::AppError;
use crate::domain::engine_position::models::ReadingEnginePosition;

const SQL_UPSERT: &str = "\
INSERT INTO reading_engine_positions (book_id, engine_kind, publication_fingerprint, opaque_position, updated_at) \
VALUES (?1, ?2, ?3, ?4, ?5) \
ON CONFLICT(book_id) DO UPDATE SET \
engine_kind = excluded.engine_kind, \
publication_fingerprint = excluded.publication_fingerprint, \
opaque_position = excluded.opaque_position, \
updated_at = excluded.updated_at";

#[frb(opaque)]
pub struct EnginePositionRepository;

impl EnginePositionRepository {
    /// Save or update an engine position hint for a book.
    pub async fn save(
        pool: &SqlitePool,
        position: &ReadingEnginePosition,
    ) -> Result<(), AppError> {
        sqlx::query(SQL_UPSERT)
            .bind(&position.book_id)
            .bind(&position.engine_kind)
            .bind(&position.publication_fingerprint)
            .bind(&position.opaque_position)
            .bind(position.updated_at)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// Find the engine position hint for a book.
    pub async fn find_by_book(
        pool: &SqlitePool,
        book_id: &str,
    ) -> Result<Option<ReadingEnginePosition>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingEnginePosition>(
                "SELECT * FROM reading_engine_positions WHERE book_id = ?",
            )
            .bind(book_id)
            .fetch_optional(pool)
            .await?,
        )
    }

    /// Delete the engine position hint for a book.
    pub async fn delete_by_book(
        pool: &SqlitePool,
        book_id: &str,
    ) -> Result<(), AppError> {
        sqlx::query("DELETE FROM reading_engine_positions WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}
