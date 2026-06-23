//! 封面提取 API
//!
//! 提供统一的封面提取入口（当前主链：EPUB、TXT）。

use crate::domain::AppError;
use crate::parser::get_cover_registry;
use crate::storage::ensure_storage;
use crate::storage::repos::BookRepository;
use crate::utils::security::validate_file_path;
use flutter_rust_bridge::frb;
use std::path::Path;

/// 提取书籍封面
///
/// 自动检测文件类型并提取封面图片，保存到指定目录。
#[frb]
pub async fn extract_book_cover(file_path: String, output_dir: String) -> Result<String, AppError> {
    tracing::info!("[cover] extract_book_cover: file_path={}", file_path);
    let validated_path = validate_file_path(&file_path)?;
    let registry = get_cover_registry();
    registry.extract_cover(&validated_path, &output_dir)
}

/// 提取书籍封面并保存路径到数据库
///
/// 一次调用完成：提取封面 + 更新 DB 中的 cover_path。
/// 替代 Dart 侧 extractBookCover + updateBook 的两步调用。
#[frb]
pub async fn extract_and_save_cover(
    book_id: String,
    file_path: String,
    output_dir: String,
) -> Result<String, AppError> {
    tracing::info!("[cover] extract_and_save_cover: book_id={}", book_id);
    let full_path = extract_book_cover(file_path, output_dir).await?;
    let storage = ensure_storage()?;
    let pool = storage.pool()?;

    // 只存文件名（相对路径），不存绝对路径，保证数据库可移植
    let relative_path = Path::new(&full_path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string();

    if relative_path.is_empty() {
        return Err(AppError::Other("failed to extract cover filename".into()));
    }

    if let Err(e) = BookRepository::update_cover_path(&pool, &book_id, &relative_path).await {
        // DB 更新失败，清理已写入的封面文件
        if let Err(cleanup_err) = tokio::fs::remove_file(&full_path).await {
            tracing::warn!(
                "cover file cleanup failed after DB error: {} (cleanup: {})",
                e,
                cleanup_err
            );
        }
        return Err(AppError::DatabaseError { reason: e.to_string().into() });
    }
    Ok(relative_path)
}

/// 检查是否支持封面提取
#[frb(sync)]
pub fn supports_cover_extraction(file_path: String) -> bool {
    let path = Path::new(&file_path);
    let extension = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_lowercase())
        .unwrap_or_default();

    let registry = get_cover_registry();
    registry.supports_format(&extension)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_supports_epub() {
        assert!(supports_cover_extraction("test.epub".to_string()));
    }

    #[test]
    fn test_does_not_support_pdf() {
        assert!(!supports_cover_extraction("test.pdf".to_string()));
    }

    #[test]
    fn test_does_not_support_unknown() {
        assert!(!supports_cover_extraction("test.xyz".to_string()));
    }

    #[test]
    fn test_does_not_support_txt() {
        assert!(!supports_cover_extraction("test.txt".to_string()));
    }

    #[tokio::test]
    async fn test_extract_book_cover_file_not_found() {
        let result = extract_book_cover("non_existent.epub".to_string(), "/tmp".to_string()).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_extract_book_cover_empty_output_dir() {
        let result = extract_book_cover("non_existent.epub".to_string(), "".to_string()).await;
        assert!(result.is_err());
    }
}
