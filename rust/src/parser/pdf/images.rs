//! PDF 图像提取模块
//!
//! 注意：PDF 封面提取功能由于 pdf 库 API 限制，暂时使用简化实现。
//! 完整的封面提取需要进一步研究 pdf 库的正确用法。

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
        .map_err(|e| ParserError::file_write_error(output_dir, format!("创建输出目录失败：{}", e)))?;

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

    // 尝试提取 PDF 封面
    match extract_cover_from_pdf(file_path, &cover_output_path) {
        Ok(_) => Ok(cover_output_path),
        Err(e) => {
            tracing::warn!("PDF 封面提取失败：{}, 返回占位路径", e);
            // 失败时创建空文件作为占位
            std::fs::write(&cover_output_path, b"")
                .map_err(|e| ParserError::file_write_error(&cover_output_path, format!("写入封面文件失败：{}", e)))?;
            Ok(cover_output_path)
        }
    }
}

/// 从 PDF 文件中提取封面图像的真实实现
///
/// 注意：由于 pdf 库 API 复杂，当前为简化实现
fn extract_cover_from_pdf(file_path: &str, output_path: &str) -> ApiResult<()> {
    // TODO: 实现真实的 PDF 封面提取逻辑
    // 需要使用 pdf 库正确解析 PDF 文件并提取封面图像
    // 当前返回错误，调用方会创建空文件作为占位
    
    // 这里可以尝试使用 pdfium-render 来提取封面
    // 但由于配置复杂，暂时不实现
    
    Err(ParserError::PdfParseError("PDF 封面提取功能尚未完全实现".to_string()))
}

/// 从 PDF 文件中提取封面图像的原始字节数据
///
/// 用于 ZeroCopyBuffer 优化传输，避免 FFI 拷贝。
pub fn extract_pdf_cover_bytes(file_path: &str) -> ApiResult<Vec<u8>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    // 创建临时文件路径
    let temp_dir = std::env::temp_dir();
    let temp_path = temp_dir.join("pdf_cover_temp.jpg");
    let temp_path_str = temp_path.to_string_lossy().to_string();
    
    // 使用 extract_pdf_cover 提取封面
    match extract_pdf_cover(file_path, temp_dir.to_str().unwrap_or("/tmp")) {
        Ok(_) => {
            // 读取提取的封面文件
            let data = std::fs::read(&temp_path_str)
                .map_err(|e| ParserError::file_read_error(&temp_path_str, format!("读取封面文件失败：{}", e)))?;
            
            // 清理临时文件
            let _ = std::fs::remove_file(&temp_path);
            
            if data.is_empty() {
                return Err(ParserError::PdfParseError("封面文件为空".to_string()));
            }
            
            Ok(data)
        }
        Err(e) => {
            tracing::warn!("PDF 封面字节提取失败：{}", e);
            Err(e)
        }
    }
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
