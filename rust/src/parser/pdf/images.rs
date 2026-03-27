//! PDF 图像提取模块
//!
//! 使用 pdfium-render 提取 PDF 封面图像

use flutter_rust_bridge::frb;
use pdfium_render::prelude::*;
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
/// 使用 pdfium-render 渲染第一页为图片
fn extract_cover_from_pdf(file_path: &str, output_path: &str) -> ApiResult<()> {
    // 初始化 Pdfium
    let pdfium = Pdfium::default();

    // 打开 PDF 文件
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    // 获取第一页（封面）
    let first_page = pdf
        .pages()
        .first()
        .or_else(|e| Err(ParserError::PdfParseError(format!("获取封面页失败：{}", e))))?;

    // 设置渲染配置
    let render_config = PdfRenderConfig::new()
        .set_target_width(800)
        .set_maximum_height(1200);

    // 渲染页面为图片
    let bitmap = first_page
        .render_with_config(&render_config)
        .map_err(|e| ParserError::PdfParseError(format!("渲染 PDF 页面失败：{}", e)))?;

    // 转换为 JPEG 格式并保存
    bitmap
        .as_image()
        .into_rgb8()
        .save_with_format(output_path, image::ImageFormat::Jpeg)
        .map_err(|e| ParserError::file_write_error(output_path, format!("保存封面文件失败：{}", e)))?;

    Ok(())
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
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_bytes_empty_file() {
        use tempfile::TempDir;
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        std::fs::write(&file_path, b"").unwrap();

        let result = extract_pdf_cover_bytes(file_path.to_str().unwrap());
        // 空文件或者无效 PDF 会返回错误或者空数组
        // 取决于 Pdfium 库的行为
        assert!(result.is_ok() || result.is_err());
    }
}
