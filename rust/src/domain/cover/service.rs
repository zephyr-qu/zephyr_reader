//! 封面管理业务逻辑
//!
//! 提供封面提取、数据库保存和格式检测功能。
//! 封面提取委托给 cover_extractor，数据访问委托给 BookRepository。

use std::path::Path;

use crate::common::AppError;
use crate::common::security::validate_file_path;
use crate::domain::book::book_repo::BookRepository;
use crate::domain::cover::cover_extractor::get_cover_registry;
use crate::infra::manager::storage_pool;

/// 提取书籍封面
pub async fn extract_book_cover(file_path: &str, output_dir: &str) -> Result<String, AppError> {
    let validated_path = validate_file_path(file_path)?;
    let registry = get_cover_registry();
    registry.extract_cover(&validated_path, output_dir)
}

/// 提取书籍封面并保存路径到数据库
///
/// 如果数据库保存失败，自动清理已提取的封面文件。
pub async fn extract_and_save_cover(
    book_id: &str,
    file_path: &str,
    output_dir: &str,
) -> Result<String, AppError> {
    let full_path = extract_book_cover(file_path, output_dir).await?;

    let relative_path = Path::new(&full_path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string();

    if relative_path.is_empty() {
        // 清理孤立封面文件
        let _ = tokio::fs::remove_file(&full_path).await;
        return Err(AppError::Other("failed to extract cover filename".into()));
    }

    let pool = storage_pool()?;
    if let Err(e) = BookRepository::update_cover_path(&pool, book_id, &relative_path).await {
        // 数据库写入失败，清理封面文件
        if let Err(cleanup_err) = tokio::fs::remove_file(&full_path).await {
            tracing::warn!(
                "cover file cleanup failed after DB error: {} (cleanup: {})",
                e,
                cleanup_err
            );
        }
        return Err(AppError::DatabaseError {
            reason: e.to_string(),
        });
    }
    Ok(relative_path)
}

/// 检查是否支持封面提取（同步，无需 DB）
pub fn supports_cover_extraction(file_path: &str) -> bool {
    let path = Path::new(file_path);
    let extension = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_lowercase())
        .unwrap_or_default();
    let registry = get_cover_registry();
    registry.supports_format(&extension)
}
