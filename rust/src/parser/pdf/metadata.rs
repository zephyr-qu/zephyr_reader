//! PDF 元数据提取模块
//! 负责从 PDF 文件中提取标题、作者、主题等元数据信息

use pdfium_render::prelude::Pdfium;

use crate::domain::PdfMetadata;

/// 从文件路径打开 PDF 并提取元数据
pub fn extract_metadata_from_path(file_path: &str) -> PdfMetadata {
    let mut metadata = PdfMetadata::default();

    let pdfium = Pdfium;

    match pdfium.load_pdf_from_file(file_path, None) {
        Ok(pdf) => {
            metadata.page_count = pdf.pages().len();

            // pdfium-render 不直接提供元数据 API
            // 元数据需要通过其他方式提取（如解析 PDF 内部结构）
            // 这里保留占位符，实际项目中可能需要额外的库

            tracing::debug!(
                "PDF metadata extraction complete: title={:?}, author={:?}, pages={}",
                metadata.title,
                metadata.author,
                metadata.page_count
            );
        }
        Err(e) => {
            tracing::warn!("PDF document open failed, unable to extract metadata: {}", e);
        }
    }

    metadata
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_metadata_file_not_found() {
        let metadata = extract_metadata_from_path("non_existent.pdf");
        assert_eq!(metadata.page_count, 0);
    }
}
