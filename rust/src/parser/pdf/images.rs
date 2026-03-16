//! PDF 图像提取模块

use flutter_rust_bridge::frb;
use std::path::Path;

use crate::ffi::{ApiResult, EpubImageInfo, ParserError};

/// 从 PDF 文件中提取封面图像
#[frb(sync)]
pub fn extract_pdf_cover(file_path: &str, output_dir: &str) -> ApiResult<String> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    std::fs::create_dir_all(output_dir)
        .map_err(|e| ParserError::FileWriteError(format!("创建输出目录失败：{}", e)))?;

    // 生成输出文件名
    let book_filename = Path::new(file_path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("cover")
        .replace(" ", "_");

    let cover_filename = format!("{}_cover.jpg", book_filename);
    let cover_output_path = Path::new(output_dir)
        .join(&cover_filename)
        .to_string_lossy()
        .to_string();

    // 占位实现：创建一个空文件
    std::fs::write(&cover_output_path, b"")
        .map_err(|e| ParserError::FileWriteError(format!("写入封面文件失败：{}", e)))?;

    tracing::warn!("PDF 封面提取功能尚未完全实现，返回占位路径");
    Ok(cover_output_path)
}

/// 从 PDF 文件中提取封面图像的原始字节数据
///
/// 用于 ZeroCopyBuffer 优化传输，避免 FFI 拷贝。
/// 注意：当前为占位实现，返回空字节数组。
pub fn extract_pdf_cover_bytes(file_path: &str) -> ApiResult<Vec<u8>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    // 占位实现：返回空字节数组
    // TODO: 实现真实的 PDF 封面提取逻辑
    tracing::warn!("PDF 封面字节提取功能尚未完全实现，返回空字节数组");
    Ok(Vec::new())
}

/// 从 PDF 页面中提取图像
pub fn get_page_images(file_path: &str, _page_index: u32) -> ApiResult<Vec<EpubImageInfo>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    // 占位实现：返回空列表
    tracing::warn!("PDF 图像提取功能尚未完全实现，返回空列表");
    Ok(Vec::new())
}

/// 获取 PDF 中所有页面的图像总数
pub fn count_total_images(_file_path: &str) -> i32 {
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_pdf_cover_file_not_found() {
        let result = extract_pdf_cover("non_existent.pdf", "/tmp");
        assert!(result.is_err());
        match result.unwrap_err() {
            ParserError::FileNotFound { .. } => (),
            _ => panic!("Expected FileNotFound error"),
        }
    }

    #[test]
    fn test_extract_pdf_cover_bytes_file_not_found() {
        let result = extract_pdf_cover_bytes("non_existent.pdf");
        assert!(result.is_err());
        match result.unwrap_err() {
            ParserError::FileNotFound { .. } => (),
            _ => panic!("Expected FileNotFound error"),
        }
    }

    #[test]
    fn test_extract_pdf_cover_bytes_empty_file() {
        use tempfile::TempDir;
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        std::fs::write(&file_path, b"").unwrap();

        let result = extract_pdf_cover_bytes(file_path.to_str().unwrap());
        assert!(result.is_ok());
        // 占位实现返回空数组
        assert!(result.unwrap().is_empty());
    }
}
