use crate::domain::AppError;
use std::path::Path;

pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::file_not_found(path_str));
    }
    if !path.is_file() {
        return Err(AppError::file_read_error(path_str, "path is not a file"));
    }
    let canonical = path
        .canonicalize()
        .map_err(|e| AppError::file_read_error(path_str, e.to_string()))?;
    Ok(canonical.to_string_lossy().to_string())
}

pub async fn validate_file_path_async(path_str: &str) -> Result<String, AppError> {
    let path_str = path_str.to_string();
    tokio::task::spawn_blocking(move || validate_file_path(&path_str))
        .await
        .map_err(|e| AppError::task_panic("security sync", e.to_string()))?
}
