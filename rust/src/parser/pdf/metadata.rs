//! PDF 元数据提取模块
//! 负责从 PDF 文件中提取标题、作者、主题等元数据信息

use pdf::file::FileOptions;

use crate::ffi::PdfMetadata;

/// 从文件路径打开 PDF 并提取元数据
pub fn extract_metadata_from_path(file_path: &str) -> PdfMetadata {
    let mut metadata = PdfMetadata::default();

    match FileOptions::cached().open(file_path) {
        Ok(doc) => {
            metadata.page_count = doc.num_pages() as i32;

            if let Some(info_dict) = &doc.trailer.info_dict {
                if let Some(title) = info_dict.title.as_ref() {
                    metadata.title = title.to_string().ok();
                }
                if let Some(author) = info_dict.author.as_ref() {
                    metadata.author = author.to_string().ok();
                }
                if let Some(subject) = info_dict.subject.as_ref() {
                    metadata.subject = subject.to_string().ok();
                }
                if let Some(creator) = info_dict.creator.as_ref() {
                    metadata.creator = creator.to_string().ok();
                }
            }

            tracing::debug!(
                "PDF 元数据提取完成：title={:?}, author={:?}, pages={}",
                metadata.title,
                metadata.author,
                metadata.page_count
            );
        }
        Err(e) => {
            tracing::warn!("PDF 文档打开失败，无法提取元数据：{}", e);
        }
    }

    metadata
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_metadata_file_not_found() {
        let metadata = extract_metadata_from_path("non_existent.pdf");
        assert_eq!(metadata.page_count, 0);
    }
}
