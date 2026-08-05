//! 封面提取 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::cover::service;

/// 提取书籍封面并保存路径到数据库
#[frb]
pub async fn extract_and_save_cover(
    book_id: String,
    file_path: String,
    output_dir: String,
) -> Result<String, AppError> {
    tracing::info!("[cover] extract_and_save_cover: book_id={}", book_id);
    service::extract_and_save_cover(&book_id, &file_path, &output_dir).await
}

/// 检查是否支持封面提取
#[frb(sync)]
pub fn supports_cover_extraction(file_path: String) -> bool {
    service::supports_cover_extraction(&file_path)
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
}
