//! TXT 章节检测配置 — 数据库操作

use sqlx::SqlitePool;

use super::models::{ChapterDetectConfig, ChapterDetectPattern};
use crate::common::AppError;
/// 加载指定 scope 的 DB 配置
pub(crate) async fn load_scope_config(
    pool: &SqlitePool,
    scope: &str,
) -> Result<Option<ChapterDetectConfig>, AppError> {
    // 先确认 scope 是否存在
    let scope_exists =
        sqlx::query_scalar::<_, String>("SELECT scope FROM chapter_detect_scopes WHERE scope = ?")
            .bind(scope)
            .fetch_optional(pool)
            .await
            .map_err(|e| AppError::DatabaseError {
                reason: format!("failed to check detect scope: {}", e),
            })?;

    let scope = match scope_exists {
        Some(s) => s,
        None => return Ok(None),
    };

    // 加载该 scope 下的所有 pattern（按 order 排序）
    let rows = sqlx::query_as::<_, PatternRow>(
        "SELECT pattern_name, regex, enabled
         FROM chapter_detect_patterns
         WHERE scope = ?
         ORDER BY pattern_order",
    )
    .bind(&scope)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::DatabaseError {
        reason: format!("failed to load detect patterns: {}", e),
    })?;

    let patterns = rows
        .into_iter()
        .map(|r| ChapterDetectPattern {
            pattern_name: r.pattern_name,
            regex: r.regex,
            enabled: r.enabled,
        })
        .collect();

    Ok(Some(ChapterDetectConfig { scope, patterns }))
}




/// 获取书籍的 detect_scope
pub(crate) async fn get_book_scope(pool: &SqlitePool, book_id: &str) -> Result<String, AppError> {
    let scope = sqlx::query_scalar::<_, String>("SELECT detect_scope FROM books WHERE id = ?")
        .bind(book_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to get book scope: {}", e),
        })?;

    Ok(scope.unwrap_or_else(|| "global".to_string()))
}

/// sqlx query_as 中间行
#[derive(sqlx::FromRow)]
struct PatternRow {
    pattern_name: String,
    regex: String,
    enabled: bool,
}
