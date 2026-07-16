//! TXT 章节检测配置 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::chapter_detect::models::ChapterDetectConfig;
use crate::domain::chapter_detect::repo;
use crate::infra::manager::storage_pool;

/// 获取所有可用 scope 列表
#[frb]
pub async fn list_detect_scopes() -> Result<Vec<String>, AppError> {
    let pool = storage_pool()?;
    repo::list_scopes(&pool).await
}

/// 获取指定 scope 的完整 DB 配置
#[frb]
pub async fn get_detect_config(scope: String) -> Result<Option<ChapterDetectConfig>, AppError> {
    let pool = storage_pool()?;
    repo::load_scope_config(&pool, &scope).await
}

/// 保存 scope 配置（创建或覆盖）
///
/// 注意：禁止保存名为 `global` 的 scope（内置不可修改）。
#[frb]
pub async fn save_detect_config(config: ChapterDetectConfig) -> Result<(), AppError> {
    if config.scope == "global" {
        return Err(AppError::InvalidInput {
            reason: "cannot modify the built-in 'global' scope".into(),
        });
    }
    // 校验所有正则是否可编译
    for p in &config.patterns {
        if regex::Regex::new(&p.regex).is_err() {
            return Err(AppError::InvalidInput {
                reason: format!("invalid regex in pattern '{}': '{}'", p.pattern_name, p.regex),
            });
        }
    }

    let pool = storage_pool()?;
    repo::save_scope_config(&pool, &config).await
}

/// 删除自定义 scope（关联书籍自动回退到 global）
#[frb]
pub async fn delete_detect_scope(scope: String) -> Result<(), AppError> {
    if scope == "global" {
        return Err(AppError::InvalidInput {
            reason: "cannot delete the built-in 'global' scope".into(),
        });
    }
    let pool = storage_pool()?;
    repo::delete_scope(&pool, &scope).await
}

/// 获取书籍当前使用的 scope
#[frb]
pub async fn get_book_detect_scope(book_id: String) -> Result<String, AppError> {
    let pool = storage_pool()?;
    repo::get_book_scope(&pool, &book_id).await
}

/// 设置书籍使用的 scope
#[frb]
pub async fn set_book_detect_scope(book_id: String, scope: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    repo::set_book_scope(&pool, &book_id, &scope).await
}

/// 取消书籍自定义 scope（回退到 global）
#[frb]
pub async fn clear_book_detect_scope(book_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    repo::set_book_scope(&pool, &book_id, "global").await
}
