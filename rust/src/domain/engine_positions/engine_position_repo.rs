use flutter_rust_bridge::frb;
use sqlx::SqlitePool;

use crate::common::AppError;
use crate::domain::engine_positions::models::EnginePositionHint;

const SQL_UPSERT_ENGINE_POSITION: &str = "\
INSERT INTO reading_engine_positions (book_id, engine_kind, publication_fingerprint, opaque_position, updated_at) \
VALUES (?1, ?2, ?3, ?4, ?5) \
ON CONFLICT(book_id) DO UPDATE SET \
engine_kind = excluded.engine_kind, \
publication_fingerprint = excluded.publication_fingerprint, \
opaque_position = excluded.opaque_position, \
updated_at = excluded.updated_at";

/// 阅读引擎位置提示仓储 — 每本书一行，整体覆盖写
#[frb(opaque)]
pub struct EnginePositionHintRepository;

impl EnginePositionHintRepository {
    pub async fn save(pool: &SqlitePool, hint: &EnginePositionHint) -> Result<(), AppError> {
        sqlx::query(SQL_UPSERT_ENGINE_POSITION)
            .bind(&hint.book_id)
            .bind(&hint.engine_kind)
            .bind(&hint.publication_fingerprint)
            .bind(&hint.opaque_position)
            .bind(hint.updated_at)
            .execute(pool)
            .await?;
        Ok(())
    }

    pub async fn find_by_book(
        pool: &SqlitePool,
        book_id: &str,
    ) -> Result<Option<EnginePositionHint>, AppError> {
        Ok(sqlx::query_as::<_, EnginePositionHint>(
            "SELECT * FROM reading_engine_positions WHERE book_id = ?",
        )
        .bind(book_id)
        .fetch_optional(pool)
        .await?)
    }
}
