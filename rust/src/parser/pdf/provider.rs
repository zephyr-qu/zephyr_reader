//! PDF 按需内容提供器
//!
//! TODO: Dart 侧尚未接入 PDF 阅读，此模块目前无活调用方
//! `PdfContentProvider` 实现 `PagedContentProvider`，提供页面级按需访问。
//! 每次 `get_page()` 调用打开 Pdfium 文档，提取单页文本并缓存。
//! LRU 页面缓存避免相邻页面翻页时的重复提取开销。

use parking_lot::Mutex;
use std::num::NonZeroUsize;

use lru::LruCache;
use pdfium_render::prelude::{PdfPageIndex, Pdfium};

use crate::domain::AppError;
use crate::parser::provider::{PageData, PagedContentProvider};

/// LRU 页面缓存容量
const PDF_PAGE_CACHE_SIZE: usize = 16;

/// PDF 按需内容提供器
pub struct PdfContentProvider {
    file_path: String,
    total_pages_count: u32,
    page_cache: Mutex<LruCache<u32, String>>,
}

impl PdfContentProvider {
    /// 打开 PDF 文件并获取总页数
    ///
    /// 注意：每次 `get_page()` 调用会重新加载 Pdfium 文档，
    /// 因为 `PdfDocument` 不满足 `Send + Sync`。文本提取结果
    /// 通过 LRU 缓存优化重复访问。
    pub fn open(file_path: &str) -> Result<Self, AppError> {
        if !std::path::Path::new(file_path).exists() {
            return Err(AppError::file_not_found(file_path));
        }

        let pdfium = Pdfium::default();
        let pdf = pdfium
            .load_pdf_from_file(file_path, None)
            .map_err(|e| AppError::pdf_parse_error(format!("failed to open PDF: {}", e)))?;

        let total_pages_count = pdf.pages().len() as u32;

        Ok(Self {
            file_path: file_path.to_string(),
            total_pages_count,
            page_cache: Mutex::new(LruCache::new(
                NonZeroUsize::new(PDF_PAGE_CACHE_SIZE).unwrap(),
            )),
        })
    }

    /// 提取指定页面的文本
    fn extract_page_text(&self, page_index: u32) -> Result<String, AppError> {
        let pdfium = Pdfium::default();
        let pdf = pdfium
            .load_pdf_from_file(&self.file_path, None)
            .map_err(|e| AppError::pdf_parse_error(format!("failed to open PDF: {}", e)))?;

        let num_pages = pdf.pages().len() as usize;
        if (page_index as usize) >= num_pages {
            return Err(AppError::pdf_parse_error(format!(
                "page index out of range: {} (total {} pages)",
                page_index, num_pages
            )));
        }

        let page = pdf.pages().get(page_index as PdfPageIndex).map_err(|e| {
            AppError::pdf_parse_error(format!("failed to get page {}: {}", page_index, e))
        })?;

        let page_text = page.text().map_err(|e| {
            AppError::pdf_parse_error(format!("failed to extract page {} text: {}", page_index, e))
        })?;

        let mut text = String::new();
        for char_obj in page_text.chars().iter() {
            if let Some(ch) = char_obj.unicode_char() {
                text.push(ch);
            }
        }

        Ok(text)
    }

    /// 提取并缓存相邻页面（供 prefetch 使用）
    fn cache_adjacent_pages(&self, current_page: u32, depth: u32) {
        for i in 1..=depth {
            let target = current_page + i;
            if target >= self.total_pages_count {
                break;
            }
            {
                let cache = self.page_cache.lock();
                if cache.contains(&target) {
                    continue;
                }
            }
            if let Ok(text) = self.extract_page_text(target) {
                let mut cache = self.page_cache.lock();
                cache.put(target, text);
            }
        }
    }
}

impl PagedContentProvider for PdfContentProvider {
    fn get_page(&self, page_index: u32) -> Result<PageData, AppError> {
        // 先查缓存
        {
            let mut cache = self.page_cache.lock();
            if let Some(text) = cache.get(&page_index) {
                return Ok(PageData {
                    page_index,
                    text: text.clone(),
                });
            }
        }

        // 缓存未命中，提取页面文本
        let text = self.extract_page_text(page_index)?;

        // 写入缓存
        {
            let mut cache = self.page_cache.lock();
            cache.put(page_index, text.clone());
        }

        Ok(PageData { page_index, text })
    }

    fn total_pages(&self) -> u32 {
        self.total_pages_count
    }

    /// 预取相邻页面（通常在用户翻页后由 API 层调用）
    ///
    /// 同步提取当前页的后两页并缓存。由于 `extract_page_text` 是阻塞操作，
    /// 调用者应在 `spawn_blocking` 等非 UI 线程中调用。
    fn prefetch(&self, page_index: u32) {
        self.cache_adjacent_pages(page_index, 2);
    }
}
