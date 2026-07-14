use crate::domain::AppError;
use crate::parser::registry::parser_for_file;
use crate::storage::repos::{BookRepository, ChapterRepository};
use crate::storage::storage_pool;
use crate::utils::security::validate_file_path;
use flutter_rust_bridge::frb;

// ============================================================
// 文件作用：书籍解析入口 — 验证路径、选择解析器、保存元数据。
//
// 公有函数：
//   - parse_book() — 解析书籍文件并保存到数据库
// ============================================================

const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;

/// 解析书籍文件：验证路径、检查大小限制、选择解析器、保存元数据。
#[frb]
pub async fn parse_book(file_path: String) -> Result<String, AppError> {
    tracing::info!("[parse_book] start: file_path={}", file_path);
    let validated_path = validate_file_path(&file_path)?;
    let metadata = tokio::fs::metadata(&validated_path)
        .await
        .map_err(|e| AppError::FileReadError { path: validated_path.clone(), details: e.to_string() })?;
    if metadata.len() > MAX_FILE_SIZE {
        return Err(AppError::SecurityError { reason: format!(
            "file size exceeds limit (max {} MB)", MAX_FILE_SIZE / 1024 / 1024
        ), path: validated_path });
    }
    let pool = storage_pool()?;
    if let Some(existing) = BookRepository::find_by_file_path(&pool, &validated_path).await? {
        return Ok(existing.book_id);
    }
    let parser = parser_for_file(&validated_path)?;
    let result = parser.parse(&validated_path).await?;
    BookRepository::save(&pool, &result.book_info).await?;
    BookRepository::save_metadata(&pool, &result.book_info).await?;
    ChapterRepository::save(&pool, &result.book_info.book_id, &result.chapters).await?;
    Ok(result.book_info.book_id)
}
