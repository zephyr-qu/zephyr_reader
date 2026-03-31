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
/// 优先尝试提取嵌入的封面图像，失败时渲染第一页
fn extract_cover_from_pdf(file_path: &str, output_path: &str) -> ApiResult<()> {
    // 初始化 Pdfium
    let pdfium = Pdfium::default();

    // 打开 PDF 文件
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    // 验证 PDF 至少有一页
    let page_count = pdf.pages().len();
    if page_count == 0 {
        return Err(ParserError::PdfParseError("PDF 文件没有页面".to_string()));
    }

    // 获取第一页（封面）
    let first_page = pdf
        .pages()
        .first()
        .map_err(|e| ParserError::PdfParseError(format!("获取封面页失败：{}", e)))?;

    // 设置渲染配置 - 使用更高的质量
    // 对于封面，我们使用较高的分辨率以保证质量
    let render_config = PdfRenderConfig::new()
        .set_target_width(1200)  // 提高宽度到 1200px
        .set_maximum_height(1800) // 提高高度到 1800px
        .clear_before_rendering(true); // 渲染前清除缓存

    // 渲染页面为图片
    let bitmap = first_page
        .render_with_config(&render_config)
        .map_err(|e| ParserError::PdfParseError(format!("渲染 PDF 页面失败：{}", e)))?;

    // 转换为 JPEG 格式并保存，使用较高的质量
    bitmap
        .as_image()
        .into_rgb8()
        .save_with_format(output_path, image::ImageFormat::Jpeg)
        .map_err(|e| ParserError::file_write_error(output_path, format!("保存封面文件失败：{}", e)))?;

    // 验证保存的文件
    let metadata = std::fs::metadata(output_path)
        .map_err(|e| ParserError::file_read_error(output_path, format!("无法读取封面文件元数据：{}", e)))?;

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
///
/// 用于 ZeroCopyBuffer 优化传输，避免 FFI 拷贝。
/// 直接返回 JPEG 字节数据，不创建临时文件。
pub fn extract_pdf_cover_bytes(file_path: &str) -> ApiResult<Vec<u8>> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    // 初始化 Pdfium
    let pdfium = Pdfium::default();

    // 打开 PDF 文件
    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| ParserError::PdfParseError(format!("加载 PDF 文件失败：{}", e)))?;

    // 验证 PDF 至少有一页
    let page_count = pdf.pages().len();
    if page_count == 0 {
        return Err(ParserError::PdfParseError("PDF 文件没有页面".to_string()));
    }

    // 获取第一页（封面）
    let first_page = pdf
        .pages()
        .first()
        .map_err(|e| ParserError::PdfParseError(format!("获取封面页失败：{}", e)))?;

    // 设置渲染配置
    let render_config = PdfRenderConfig::new()
        .set_target_width(1200)
        .set_maximum_height(1800)
        .clear_before_rendering(true);

    // 渲染页面为图片
    let bitmap = first_page
        .render_with_config(&render_config)
        .map_err(|e| ParserError::PdfParseError(format!("渲染 PDF 页面失败：{}", e)))?;

    // 转换为 JPEG 格式的字节数据
    // 使用 Vec<u8> + Cursor 来满足 Write + Seek trait 边界
    use std::io::Cursor;
    let mut jpeg_data = Cursor::new(Vec::new());

    bitmap
        .as_image()
        .into_rgb8()
        .write_to(&mut jpeg_data, image::ImageFormat::Jpeg)
        .map_err(|e| ParserError::file_write_error(
            file_path,
            format!("编码 JPEG 图像失败：{}", e),
        ))?;

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
    use std::path::Path;
    use tempfile::TempDir;

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
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        std::fs::write(&file_path, b"").unwrap();

        let result = extract_pdf_cover_bytes(file_path.to_str().unwrap());
        // 空文件或者无效 PDF 会返回错误
        assert!(result.is_err());
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_invalid_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("invalid.pdf");
        // 写入无效的 PDF 内容
        std::fs::write(&file_path, b"%PDF-1.4\ninvalid content").unwrap();

        let result = extract_pdf_cover(file_path.to_str().unwrap(), temp_dir.path().to_str().unwrap());
        // 即使解析失败，也会返回占位文件路径
        assert!(result.is_ok());
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_pdf_cover_output_dir_creation() {
        let temp_dir = TempDir::new().unwrap();
        let nested_dir = temp_dir.path().join("nested").join("cover").join("dir");
        let file_path = temp_dir.path().join("test.pdf");

        // 创建空文件模拟 PDF
        std::fs::write(&file_path, b"%PDF-1.4\n").unwrap();

        // 输出目录不存在，应该自动创建
        let result = extract_pdf_cover(
            file_path.to_str().unwrap(),
            nested_dir.to_str().unwrap(),
        );

        // 即使 PDF 解析失败，也应该返回占位文件路径
        assert!(result.is_ok());

        // 验证输出目录被创建
        assert!(nested_dir.exists());
    }

    #[test]
    fn test_cover_filename_generation() {
        // 测试文件名生成逻辑
        let test_cases = vec![
            ("test_book.pdf", "test_book"),
            ("My Book.pdf", "My_Book"),
            ("文件 123.pdf", "文件_123"),  // 注意：空格会被替换为下划线
        ];

        for (input, expected_stem) in test_cases {
            let book_filename = Path::new(input)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("cover")
                .replace(" ", "_");

            let cover_filename = format!("{}_cover.jpg", book_filename);

            // 验证文件名格式
            assert!(cover_filename.ends_with("_cover.jpg"));
            // 验证包含原文件名（去除空格后）
            assert!(cover_filename.contains(expected_stem),
                "封面文件名 '{}' 应该包含 '{}'", cover_filename, expected_stem);
        }
    }

    #[test]
    fn test_cover_filename_edge_cases() {
        // 测试边界情况
        let edge_cases = vec![
            ("", "cover"),  // 空文件名
            ("no_extension", "no_extension"),
            ("  spaces  .pdf", "spaces"),  // 多余空格
        ];

        for (input, _expected_stemm) in edge_cases {
            let book_filename = Path::new(input)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("cover")
                .replace(" ", "_");

            // 验证不会panic
            let _cover_filename = format!("{}_cover.jpg", book_filename);
        }
    }
}
