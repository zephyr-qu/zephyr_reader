//! TXT 章节检测配置 — 数据库操作

use sqlx::SqlitePool;

use crate::common::AppError;
use super::models::{ChapterDetectConfig, ChapterDetectPattern};
use crate::domain::chapter_detect::detector::invalidate_cache;
/// 加载指定 scope 的 DB 配置
pub(crate) async fn load_scope_config(
    pool: &SqlitePool,
    scope: &str,
) -> Result<Option<ChapterDetectConfig>, AppError> {
    // 先确认 scope 是否存在
    let scope_exists = sqlx::query_scalar::<_, String>(
        "SELECT scope FROM chapter_detect_scopes WHERE scope = ?"
    )
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
         ORDER BY pattern_order"
    )
    .bind(&scope)
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::DatabaseError {
        reason: format!("failed to load detect patterns: {}", e),
    })?;

    let patterns = rows.into_iter().map(|r| ChapterDetectPattern {
        pattern_name: r.pattern_name,
        regex: r.regex,
        enabled: r.enabled,
    }).collect();

    Ok(Some(ChapterDetectConfig { scope, patterns }))
}

/// 保存 scope 配置（覆盖写入）
pub(crate) async fn save_scope_config(
    pool: &SqlitePool,
    config: &ChapterDetectConfig,
) -> Result<(), AppError> {
    let mut tx = pool.begin().await.map_err(|e| AppError::DatabaseError {
        reason: format!("failed to begin transaction: {}", e),
    })?;

    // UPSERT scope
    sqlx::query(
        "INSERT INTO chapter_detect_scopes (scope) VALUES (?)
         ON CONFLICT(scope) DO NOTHING"
    )
    .bind(&config.scope)
    .execute(&mut *tx)
    .await
    .map_err(|e| AppError::DatabaseError {
        reason: format!("failed to upsert scope: {}", e),
    })?;

    // 删除旧 patterns 后重新插入
    sqlx::query("DELETE FROM chapter_detect_patterns WHERE scope = ?")
        .bind(&config.scope)
        .execute(&mut *tx)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to delete old patterns: {}", e),
        })?;

    for (i, p) in config.patterns.iter().enumerate() {
        sqlx::query(
            "INSERT INTO chapter_detect_patterns (scope, pattern_order, pattern_name, regex, enabled)
             VALUES (?, ?, ?, ?, ?)"
        )
        .bind(&config.scope)
        .bind(i as i32 + 1)
        .bind(&p.pattern_name)
        .bind(&p.regex)
        .bind(p.enabled)
        .execute(&mut *tx)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to insert pattern '{}': {}", p.pattern_name, e),
        })?;
    }

    tx.commit().await.map_err(|e| AppError::DatabaseError {
        reason: format!("failed to commit: {}", e),
    })?;

    // 缓存失效
    crate::domain::chapter_detect::detector::invalidate_cache(&config.scope);

    Ok(())
}

/// 删除自定义 scope（相关书籍自动回退到 global）
pub(crate) async fn delete_scope(pool: &SqlitePool, scope: &str) -> Result<(), AppError> {
    // 将使用了该 scope 的书重置为 global
    sqlx::query("UPDATE books SET detect_scope = 'global' WHERE detect_scope = ?")
        .bind(scope)
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to reset books to global: {}", e),
        })?;

    // 删除 scope（ON DELETE CASCADE 自动清 patterns）
    sqlx::query("DELETE FROM chapter_detect_scopes WHERE scope = ?")
        .bind(scope)
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to delete scope: {}", e),
        })?;

    invalidate_cache(scope);

    Ok(())
}

/// 获取所有 scope 名称
pub(crate) async fn list_scopes(pool: &SqlitePool) -> Result<Vec<String>, AppError> {
    let scopes = sqlx::query_scalar::<_, String>(
        "SELECT scope FROM chapter_detect_scopes ORDER BY scope"
    )
    .fetch_all(pool)
    .await
    .map_err(|e| AppError::DatabaseError {
        reason: format!("failed to list scopes: {}", e),
    })?;

    Ok(scopes)
}

/// 获取书籍的 detect_scope
pub(crate) async fn get_book_scope(
    pool: &SqlitePool,
    book_id: &str,
) -> Result<String, AppError> {
    let scope = sqlx::query_scalar::<_, String>(
        "SELECT detect_scope FROM books WHERE id = ?"
    )
    .bind(book_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::DatabaseError {
        reason: format!("failed to get book scope: {}", e),
    })?;

    Ok(scope.unwrap_or_else(|| "global".to_string()))
}

/// 设置书籍的 detect_scope
pub(crate) async fn set_book_scope(
    pool: &SqlitePool,
    book_id: &str,
    scope: &str,
) -> Result<(), AppError> {
    sqlx::query("UPDATE books SET detect_scope = ? WHERE id = ?")
        .bind(scope)
        .bind(book_id)
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("failed to set book scope: {}", e),
        })?;

    Ok(())
}

/// sqlx query_as 中间行
#[derive(sqlx::FromRow)]
struct PatternRow {
    pattern_name: String,
    regex: String,
    enabled: bool,
}
