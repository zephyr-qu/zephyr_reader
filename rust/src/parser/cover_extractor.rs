//! 封面提取 API
//!
//! 提供统一的封面提取入口，支持 EPUB、PDF 等多种格式。
//! 通过 CoverExtractorRegistry 自动根据文件类型选择对应的提取器。

use crate::domain::{AppError};
use flutter_rust_bridge::frb;
use once_cell::sync::OnceCell;
use parking_lot::Mutex;
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
/// 封面提取器 trait
///
/// 所有文件格式的封面提取器必须实现此 trait。
pub trait CoverExtractor: Send + Sync {
    /// 获取提取器名称
    fn name(&self) -> &str;

    /// 获取支持的格式列表
    fn supported_formats(&self) -> Vec<&str>;

    /// 提取封面
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    /// * `output_dir` - 输出目录
    ///
    /// # 返回值
    ///
    /// * `Ok(String)` - 封面保存路径
    /// * `Err(AppError)` - 提取失败
    fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String,AppError>;

    /// 检查是否支持指定格式
    fn supports_format(&self, format: &str) -> bool {
        self.supported_formats()
            .iter()
            .any(|&f| f.eq_ignore_ascii_case(format))
    }
}

/// EPUB 封面提取器
#[frb(opaque)]
pub struct EpubCoverExtractor;

impl EpubCoverExtractor {
    pub fn new() -> Self {
        Self
    }
}

impl Default for EpubCoverExtractor {
    fn default() -> Self {
        Self::new()
    }
}

impl CoverExtractor for EpubCoverExtractor {
    fn name(&self) -> &str {
        "EPUB Cover Extractor"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["epub"]
    }

    fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String,AppError> {
        let mut epub_file = crate::parser::epub::unzip::EpubFile::open(file_path)?;
        let cover_data = epub_file
            .read_cover()
            .ok_or_else(|| AppError::other("未找到 EPUB 封面"))?;

        let file_stem = Path::new(file_path)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("cover");

        // 过滤非法字符，防止路径遍历攻击
        let safe_file_stem: String = file_stem
            .chars()
            .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
            .take(100)
            .collect();

        // 动态检测图片格式（根据魔数）
        let extension = if cover_data.len() < 4 {
            "jpg"
        } else if cover_data.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
            "png"
        } else if cover_data.starts_with(&[0xFF, 0xD8, 0xFF]) {
            "jpg"
        } else if cover_data.starts_with(b"GIF8") || cover_data.starts_with(b"GIF89a") {
            "gif"
        } else if cover_data.starts_with(b"RIFF")
            && cover_data.len() > 12
            && &cover_data[8..12] == b"WEBP"
        {
            "webp"
        } else if cover_data.starts_with(b"BM") {
            "bmp"
        } else {
            "jpg"
        };

        let output_path = Path::new(output_dir)
            .join(format!("{}.{}", safe_file_stem, extension))
            .to_string_lossy()
            .to_string();

        std::fs::create_dir_all(output_dir)
            .map_err(|e| AppError::file_write_error(output_dir.to_string(), e.to_string()))?;
        std::fs::write(&output_path, cover_data)
            .map_err(|e| AppError::file_write_error(&output_path, e.to_string()))?;

        Ok(output_path)
    }
}

/// PDF 封面提取器
#[frb(opaque)]
pub struct PdfCoverExtractor;

impl PdfCoverExtractor {
    pub fn new() -> Self {
        Self
    }
}

impl Default for PdfCoverExtractor {
    fn default() -> Self {
        Self::new()
    }
}

impl CoverExtractor for PdfCoverExtractor {
    fn name(&self) -> &str {
        "PDF Cover Extractor"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["pdf"]
    }

    fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String,AppError> {
        crate::parser::pdf::images::extract_pdf_cover(file_path, output_dir)
    }
}

/// 封面提取器注册表
#[frb(opaque)]
pub struct CoverExtractorRegistry {
    extractors: HashMap<String, Arc<dyn CoverExtractor>>,
    format_map: HashMap<String, String>, // format -> extractor_name
}

impl CoverExtractorRegistry {
    /// 创建新的注册表
    pub fn new() -> Self {
        Self {
            extractors: HashMap::new(),
            format_map: HashMap::new(),
        }
    }

    /// 注册提取器
    pub fn register(&mut self, extractor: Arc<dyn CoverExtractor>) -> Result<(), String> {
        let name = extractor.name().to_string();

        if self.extractors.contains_key(&name) {
            return Err(format!("提取器 '{}' 已经注册", name));
        }

        // 注册格式映射
        for format in extractor.supported_formats() {
            let format_lower = format.to_lowercase();
            if let Some(existing) = self.format_map.get(&format_lower) {
                tracing::warn!(
                    "格式 '{}' 已被提取器 '{}' 注册，现在被 '{}' 覆盖",
                    format_lower,
                    existing,
                    name
                );
            }
            self.format_map.insert(format_lower, name.clone());
        }

        self.extractors.insert(name.clone(), extractor);
        tracing::info!("封面提取器注册成功: {}", name);
        Ok(())
    }

    /// 获取指定格式的提取器
    pub fn get_extractor(&self, format: &str) -> Option<Arc<dyn CoverExtractor>> {
        let format_lower = format.to_lowercase();
        self.format_map
            .get(&format_lower)
            .and_then(|name| self.extractors.get(name).cloned())
    }

    /// 提取封面（自动选择提取器）
    pub fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String,AppError> {
        let extension = Path::new(file_path)
            .extension()
            .and_then(|ext| ext.to_str())
            .ok_or_else(|| AppError::unsupported_format("无法识别文件扩展名".to_string()))?;

        let extractor = self.get_extractor(extension).ok_or_else(|| {
            AppError::unsupported_format(format!("不支持的文件格式: {}", extension))
        })?;

        extractor.extract_cover(file_path, output_dir)
    }

    /// 检查是否支持指定格式
    pub fn supports_format(&self, format: &str) -> bool {
        self.format_map.contains_key(&format.to_lowercase())
    }
}

impl Default for CoverExtractorRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// 线程安全的封面提取器注册表
#[frb(opaque)]
pub struct ThreadSafeCoverRegistry {
    inner: Mutex<CoverExtractorRegistry>,
}

impl ThreadSafeCoverRegistry {
    /// 创建新的线程安全注册表
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(CoverExtractorRegistry::new()),
        }
    }

    /// 注册提取器
    pub fn register(&self, extractor: Arc<dyn CoverExtractor>) -> Result<(), String> {
        let mut registry = self.inner.lock();
        registry.register(extractor)
    }

    /// 提取封面
    pub fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String,AppError> {
        let extension = Path::new(file_path)
            .extension()
            .and_then(|ext| ext.to_str())
            .ok_or_else(|| AppError::unsupported_format("无法识别文件扩展名".to_string()))?;
        let extractor = self.inner.lock().get_extractor(extension).ok_or_else(|| {
            AppError::unsupported_format(format!("不支持的文件格式: {}", extension))
        })?;
        extractor.extract_cover(file_path, output_dir)
    }

    /// 检查是否支持指定格式
    pub fn supports_format(&self, format: &str) -> bool {
        self.inner.lock().supports_format(format)
    }
}

impl Default for ThreadSafeCoverRegistry {
    fn default() -> Self {
        Self::new()
    }
}

// 全局注册表
static COVER_REGISTRY: OnceCell<ThreadSafeCoverRegistry> = OnceCell::new();

/// 初始化封面提取器注册表
fn init_cover_registry() -> ThreadSafeCoverRegistry {
    let registry = ThreadSafeCoverRegistry::new();

    // 注册 EPUB 提取器
    if let Err(e) = registry.register(Arc::new(EpubCoverExtractor::new())) {
        tracing::warn!("注册 EPUB 封面提取器失败: {}", e);
    }

    // 注册 PDF 提取器
    if let Err(e) = registry.register(Arc::new(PdfCoverExtractor::new())) {
        tracing::warn!("注册 PDF 封面提取器失败: {}", e);
    }

    tracing::info!("封面提取器注册表初始化完成");
    registry
}

/// 获取封面提取器注册表
pub fn get_cover_registry() -> &'static ThreadSafeCoverRegistry {
    COVER_REGISTRY.get_or_init(init_cover_registry)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epub_cover_extractor_name() {
        let extractor = EpubCoverExtractor::new();
        assert_eq!(extractor.name(), "EPUB Cover Extractor");
    }

    #[test]
    fn test_pdf_cover_extractor_name() {
        let extractor = PdfCoverExtractor::new();
        assert_eq!(extractor.name(), "PDF Cover Extractor");
    }

    #[test]
    fn test_cover_registry_register() {
        let mut registry = CoverExtractorRegistry::new();
        let extractor = Arc::new(EpubCoverExtractor::new());

        assert!(registry.register(extractor).is_ok());
        assert!(registry.supports_format("epub"));
    }

    #[test]
    fn test_cover_registry_get_extractor() {
        let mut registry = CoverExtractorRegistry::new();
        registry
            .register(Arc::new(EpubCoverExtractor::new()))
            .unwrap();
        registry
            .register(Arc::new(PdfCoverExtractor::new()))
            .unwrap();

        assert!(registry.get_extractor("epub").is_some());
        assert!(registry.get_extractor("pdf").is_some());
        assert!(registry.get_extractor("txt").is_none());
    }
}
