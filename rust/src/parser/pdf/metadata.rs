//! PDF 元数据提取模块
//! 负责从 PDF 文件中提取标题、作者、主题等元数据信息

use pdfium_render::prelude::Pdfium;

use crate::ffi::PdfMetadata;

/// 从文件路径打开 PDF 并提取元数据
pub fn extract_metadata_from_path(file_path: &str) -> PdfMetadata {
    let mut metadata = PdfMetadata::default();

    let pdfium = Pdfium::default();

    match pdfium.load_pdf_from_file(file_path, None) {
        Ok(pdf) => {
            metadata.page_count = pdf.pages().len() as i32;

            tracing::debug!(
                "PDF 元数据提取完成：pages={}",
                metadata.page_count
            );
        }
        Err(e) => {
            tracing::warn!("PDF 文档打开失败，无法提取元数据：{}", e);
        }
    }

    metadata
}
