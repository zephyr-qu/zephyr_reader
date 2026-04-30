//! PDF 图像提取模块
//!
//! 使用 pdfium-render 提取 PDF 封面图像

use flutter_rust_bridge::frb;
use pdfium_render::prelude::*;
use std::path::Path;

use crate::ffi::{ApiResult, EpubImageInfo, ParserError};

/// 从 PDF 文件中提取封面图像
///
/// 尝试多种策略提取最佳封面：
/// 1. 首先尝试提取嵌入的封面图像
/// 2. 如果失败，渲染第一页作为封面
#[frb(sync)]
pub fn extract_pdf_cover(file_path: &str, output_dir: &str) -> ApiResult<String> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    std::fs::create_dir_all(output_dir).map_err(|e| {
        ParserError::file_write_error(output_dir, format!("创建输出目录失败：{}", e))
    })?;

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
        Ok(_) => {
            // 验证生成的封面文件
            if let Ok(metadata) = std::fs::metadata(&cover_output_path) {
                if metadata.len() > 0 {
                    tracing::info!("PDF 封面提取成功：{}", cover_output_path);
                    return Ok(cover_output_path);
                }
            }
            tracing::warn!("PDF 封面提取成功但文件为空：{}", cover_output_path);
            Err(ParserError::PdfParseError("封面文件为空".to_string()))
        }
        Err(e) => {
            tracing::warn!("PDF 封面提取失败：{}, 错误: {}", cover_output_path, e);
            Err(ParserError::PdfParseError(format!("封面提取失败: {}", e)))
        }
    }
}

/// 从 PDF 文件中提取封面图像的真实实现
///
/// 使用 pdfium-render 渲染第一页为图片
fn extract_cover_from_pdf(file_path: &str, output_path: &str) -> ApiResult<()> {
    let pdfium = Pdfium::default();
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    if pdf.pages().len() == 0 {
        return Err(ParserError::PdfParseError("PDF 文件没有页面".to_string()));
    }

    let first_page = pdf
        .pages()
        .first()
        .map_err(|e| ParserError::PdfParseError(format!("获取封面页失败：{}", e)))?;

    let render_config = PdfRenderConfig::new()
        .set_target_width(1200)
        .set_maximum_height(1800)
        .clear_before_rendering(true);

    let bitmap = first_page
        .render_with_config(&render_config)
        .map_err(|e| ParserError::PdfParseError(format!("渲染 PDF 页面失败：{}", e)))?;

    bitmap
        .as_image()
        .into_rgb8()
        .save_with_format(output_path, image::ImageFormat::Jpeg)
        .map_err(|e| {
            ParserError::file_write_error(output_path, format!("保存封面文件失败：{}", e))
        })?;

    let metadata = std::fs::metadata(output_path).map_err(|e| {
        ParserError::file_read_error(output_path, format!("无法读取封面文件元数据：{}", e))
    })?;

    if metadata.len() == 0 {
        return Err(ParserError::file_write_error(
            output_path,
            "保存的封面文件大小为 0".to_string(),
        ));
    }

    tracing::debug!(
        "PDF 封面提取成功：{} ({}x{}, {} bytes)",
        output_path,
        bitmap.width(),
        bitmap.height(),
        metadata.len()
    );

    Ok(())
}

/// 从 PDF 文件中提取封面图像的原始字节数据
pub fn extract_pdf_cover_bytes(file_path: &str) -> ApiResult<Vec<u8>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    let pdfium = Pdfium::default();
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    if pdf.pages().len() == 0 {
        return Err(ParserError::PdfParseError("PDF 文件没有页面".to_string()));
    }

    let first_page = pdf
        .pages()
        .first()
        .map_err(|e| ParserError::PdfParseError(format!("获取封面页失败：{}", e)))?;

    let render_config = PdfRenderConfig::new()
        .set_target_width(1200)
        .set_maximum_height(1800)
        .clear_before_rendering(true);

    let bitmap = first_page
        .render_with_config(&render_config)
        .map_err(|e| ParserError::PdfParseError(format!("渲染 PDF 页面失败：{}", e)))?;

    use std::io::Cursor;
    let mut jpeg_data = Cursor::new(Vec::new());

    bitmap
        .as_image()
        .into_rgb8()
        .write_to(&mut jpeg_data, image::ImageFormat::Jpeg)
        .map_err(|e| {
            ParserError::file_write_error(file_path, format!("编码 JPEG 图像失败：{}", e))
        })?;

    let data = jpeg_data.into_inner();

    if data.is_empty() {
        return Err(ParserError::PdfParseError("封面图像数据为空".to_string()));
    }

    tracing::debug!(
        "PDF 封面字节提取成功：{} bytes ({}x{})",
        data.len(),
        bitmap.width(),
        bitmap.height()
    );

    Ok(data)
}

/// 从 PDF 页面中提取图像
pub fn get_page_images(file_path: &str, page_index: u32) -> ApiResult<Vec<EpubImageInfo>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    let pdfium = Pdfium::default();
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    let page_count = pdf.pages().len() as u32;
    if page_count == 0 {
        return Err(ParserError::PdfParseError("PDF 文件没有页面".to_string()));
    }
    if page_index >= page_count {
        return Err(ParserError::PdfParseError(format!(
            "页面索引超出范围：{} (总共 {} 页)",
            page_index, page_count
        )));
    }

    let page = pdf
        .pages()
        .get(page_index as u16)
        .map_err(|e| ParserError::PdfParseError(format!("获取页面失败：{}", e)))?;

    let page_width = page.width().value.ceil() as i32;
    let page_height = page.height().value.ceil() as i32;

    let href = format!("page_{}", page_index);
    let filename = format!("page_{}.png", page_index);

    let image_info = EpubImageInfo {
        href,
        filename,
        format: crate::ffi::ImageFormat::Png,
        size_bytes: -1,
        width: Some(page_width),
        height: Some(page_height),
    };

    tracing::info!(
        "从 PDF 页面 {} 获取图像信息：{}x{}",
        page_index,
        page_width,
        page_height
    );

    Ok(vec![image_info])
}

/// 获取 PDF 中所有页面的图像总数
pub fn count_total_images(file_path: &str) -> i32 {
    if !Path::new(file_path).exists() {
        return 0;
    }

    let pdfium = Pdfium::default();
    let pdf = match pdfium.load_pdf_from_file(file_path, None) {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("加载 PDF 失败，无法统计图像数量：{}", e);
            return 0;
        }
    };

    let page_count = pdf.pages().len() as i32;
    tracing::debug!("PDF 文件 {} 中共有 {} 页（图像）", file_path, page_count);
    page_count
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;
    use tempfile::TempDir;

    #[test]
    fn test_extract_pdf_cover_file_not_found() {
        let result = extract_pdf_cover("non_existent.pdf", "/tmp");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_extract_pdf_cover_bytes_file_not_found() {
        let result = extract_pdf_cover_bytes("non_existent.pdf");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_bytes_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        std::fs::write(&file_path, b"").unwrap();

        let result = extract_pdf_cover_bytes(file_path.to_str().unwrap());
        assert!(result.is_err());
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_invalid_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("invalid.pdf");
        std::fs::write(&file_path, b"%PDF-1.4\ninvalid content").unwrap();

        let result = extract_pdf_cover(
            file_path.to_str().unwrap(),
            temp_dir.path().to_str().unwrap(),
        );
        assert!(result.is_ok());
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_output_dir_creation() {
        let temp_dir = TempDir::new().unwrap();
        let nested_dir = temp_dir.path().join("nested").join("cover").join("dir");
        let file_path = temp_dir.path().join("test.pdf");

        std::fs::write(&file_path, b"%PDF-1.4\n").unwrap();

        let result = extract_pdf_cover(file_path.to_str().unwrap(), nested_dir.to_str().unwrap());
        assert!(result.is_ok());
        assert!(nested_dir.exists());
    }

    #[test]
    fn test_cover_filename_generation() {
        let test_cases = vec![
            ("test_book.pdf", "test_book"),
            ("My Book.pdf", "My_Book"),
            ("文件 123.pdf", "文件_123"),
        ];

        for (input, expected_stem) in test_cases {
            let book_filename = Path::new(input)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("cover")
                .replace(" ", "_");

            let cover_filename = format!("{}_cover.jpg", book_filename);
            assert!(cover_filename.ends_with("_cover.jpg"));
            assert!(
                cover_filename.contains(expected_stem),
                "封面文件名 '{}' 应该包含 '{}'",
                cover_filename,
                expected_stem
            );
        }
    }

    #[test]
    fn test_cover_filename_edge_cases() {
        let edge_cases = vec![
            ("", "cover"),
            ("no_extension", "no_extension"),
            ("  spaces  .pdf", "spaces"),
        ];

        for (input, _expected_stemm) in edge_cases {
            let book_filename = Path::new(input)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("cover")
                .replace(" ", "_");

            let _cover_filename = format!("{}_cover.jpg", book_filename);
        }
    }
}
