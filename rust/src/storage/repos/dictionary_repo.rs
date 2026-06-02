use anyhow::Result;
use sqlx::SqlitePool;

use super::super::models::*;

pub struct DictionaryRepository;

impl DictionaryRepository {
    pub async fn save(pool: &SqlitePool, dict: &Dictionary) -> Result<Dictionary> {
        sqlx::query(
            "INSERT INTO dictionaries (id, name, file_path, dict_type, lang_from, lang_to, is_enabled, word_count, added_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9) \
             ON CONFLICT(id) DO UPDATE SET \
                name = excluded.name, \
                file_path = excluded.file_path, \
                dict_type = excluded.dict_type, \
                lang_from = excluded.lang_from, \
                lang_to = excluded.lang_to, \
                is_enabled = excluded.is_enabled, \
                word_count = excluded.word_count",
        )
        .bind(&dict.id)
        .bind(&dict.name)
        .bind(&dict.file_path)
        .bind(&dict.dict_type)
        .bind(&dict.lang_from)
        .bind(&dict.lang_to)
        .bind(dict.is_enabled)
        .bind(dict.word_count)
        .bind(dict.added_at.timestamp())
        .execute(pool)
        .await?;
        Ok(dict.clone())
    }

    pub async fn find_all(pool: &SqlitePool) -> Result<Vec<Dictionary>> {
        Ok(
            sqlx::query_as::<_, Dictionary>("SELECT * FROM dictionaries ORDER BY added_at DESC")
                .fetch_all(pool)
                .await?,
        )
    }

    pub async fn find_by_id(pool: &SqlitePool, id: &str) -> Result<Option<Dictionary>> {
        Ok(
            sqlx::query_as::<_, Dictionary>("SELECT * FROM dictionaries WHERE id = ?")
                .bind(id)
                .fetch_optional(pool)
                .await?,
        )
    }

    pub async fn delete(pool: &SqlitePool, id: &str) -> Result<bool> {
        let rows = sqlx::query("DELETE FROM dictionaries WHERE id = ?")
            .bind(id)
            .execute(pool)
            .await?
            .rows_affected();
        Ok(rows > 0)
    }
}
