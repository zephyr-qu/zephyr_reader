use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

/// 词典仓储 — 管理词典配置的增删改查
pub struct DictionaryRepository;

impl DictionaryRepository {
    /// 保存或更新词典配置
    pub async fn save(pool: &SqlitePool, dict: &Dictionary) -> Result<Dictionary, AppError> {
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
        .bind(dict.added_at)
        .execute(pool)
        .await?;
        Ok(dict.clone())
    }

    /// 获取所有词典（按添加时间倒序）
    pub async fn find_all(pool: &SqlitePool) -> Result<Vec<Dictionary>, AppError> {
        Ok(
            sqlx::query_as::<_, Dictionary>("SELECT * FROM dictionaries ORDER BY added_at DESC")
                .fetch_all(pool)
                .await?,
        )
    }

    /// 按 ID 查找词典
    pub async fn find_by_id(pool: &SqlitePool, id: &str) -> Result<Option<Dictionary>, AppError> {
        Ok(
            sqlx::query_as::<_, Dictionary>("SELECT * FROM dictionaries WHERE id = ?")
                .bind(id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 删除词典
    ///
    /// # 返回值
    /// 返回是否成功删除了记录
    pub async fn delete(pool: &SqlitePool, id: &str) -> Result<bool, AppError> {
        let rows = sqlx::query("DELETE FROM dictionaries WHERE id = ?")
            .bind(id)
            .execute(pool)
            .await?
            .rows_affected();
        Ok(rows > 0)
    }
}
