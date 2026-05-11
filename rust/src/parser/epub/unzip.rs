//! EPUB 文件解压与读取
//! 使用 epub 库读取 EPUB 文件结构
//! 注意：epub crate 2.x API 与 1.x 不兼容

use crate::domain::{ EpubMetadata, AppError};
use epub::doc::{EpubDoc, ResourceItem, SpineItem};
use lru::LruCache;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::num::NonZeroUsize;

/// EPUB 缓存最大条目数
const EPUB_CACHE_SIZE: usize = 50;
const COVER_CANDIDATES: &[&str] = &[
    "cover.jpg", "cover.jpeg", "cover.png",
    "Cover.jpg", "Cover.jpeg", "Cover.png",
    "coverimage.jpg", "coverimage.png",
];
/// EPUB 文件句柄（带 LRU 缓存）
pub struct EpubFile {
    doc: EpubDoc<BufReader<File>>,
    cache: LruCache<String, Vec<u8>>,
}

/// 辅助函数：从 MetadataItem Vec 中获取指定类型的第一个值
/// epub 2.x 使用 property/value 而不是 name/content
/// 注意：epub 2.x 中 MetadataItem.value 是 String 类型，不是 Vec<String>
fn get_metadata_first(metadata: &[epub::doc::MetadataItem], name: &str) -> Option<String> {
    metadata
        .iter()
        .find(|m| m.property == name)
        .map(|m| m.value.clone())
}

/// 辅助函数：从 ResourceItem HashMap 中查找资源
fn find_resource_by_href_or_path<'a>(
    resources: &'a HashMap<String, ResourceItem>,
    href: &str,
) -> Option<(&'a String, &'a ResourceItem)> {
    // 首先尝试直接匹配 href
    if let Some((key, item)) = resources.get_key_value(href) {
        return Some((key, item));
    }

    // 然后尝试匹配路径结尾
    resources
        .iter()
        .find(|(_, item)| item.path.to_string_lossy().ends_with(href))
}

impl EpubFile {
    /// 打开 EPUB 文件
    pub fn open(file_path: &str) -> Result<Self, AppError> {
        if !std::path::Path::new(file_path).exists() {
            return Err(AppError::file_not_found(file_path));
        }

        let doc = EpubDoc::new(file_path).map_err(|e| {
            AppError::file_read_error(file_path, format!("EPUB 解析失败：{}", e))
        })?;

        Ok(Self {
            doc,
            cache: LruCache::new(NonZeroUsize::new(EPUB_CACHE_SIZE).unwrap()),
        })
    }

    /// 获取书籍标题
    pub fn title(&self) -> String {
        get_metadata_first(&self.doc.metadata, "title").unwrap_or_else(|| "未知标题".to_string())
    }

    /// 获取作者
    pub fn author(&self) -> String {
        get_metadata_first(&self.doc.metadata, "creator").unwrap_or_else(|| "未知作者".to_string())
    }

    /// 获取封面路径
    pub fn cover_path(&self) -> Option<String> {
        get_metadata_first(&self.doc.metadata, "cover")
    }

    /// 获取目录（NCX/Nav），支持多级嵌套
    pub fn toc(&self) -> Vec<(String, String)> {
        self.doc
            .toc
            .iter()
            .map(|nav| (nav.label.clone(), nav.content.to_string_lossy().to_string()))
            .collect()
    }

    /// 获取 spine（阅读顺序）
    pub fn spine(&self) -> Vec<String> {
        self.doc
            .spine
            .iter()
            .map(|item: &SpineItem| item.idref.clone())
            .collect()
    }

    /// 读取指定资源内容（带缓存）
    pub fn read_resource(&mut self, href: &str) -> Result<String, AppError> {
        // 检查缓存（先克隆内容以避免借用冲突）
        if let Some(cached) = self.cache.get(href).cloned() {
            return self.decode_content(&cached);
        }

        // 查找资源
        let (resource_href, _resource) =
            find_resource_by_href_or_path(&self.doc.resources, href)
                .ok_or_else(|| AppError::epub_parse_error(format!("资源不存在：{}", href)))?;

        let resource_href: String = resource_href.clone();

        // 设置当前章节到该资源
        let index = self
            .doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href);
        if let Some(idx) = index {
            let _ = self.doc.set_current_chapter(idx);

            // 读取内容 - epub 2.x 返回 (Vec<u8>, String) 元组
            let (content, _charset) = self.doc.get_current().ok_or_else(|| {
                AppError::epub_parse_error("读取资源失败：无法获取当前内容".to_string())
            })?;

            // 缓存内容（只缓存字节）
            self.cache.put(href.to_string(), content.clone());

            return self.decode_content(&content);
        }

        Err(AppError::epub_parse_error(format!(
            "无法定位资源：{}",
            href
        )))
    }

    /// 解码内容（EPUB 规范要求 UTF-8，提供回退）
    ///
    /// 优先尝试零拷贝的 `from_utf8`，失败后再使用 `encoding_rs` 解码。
    /// 避免 `to_vec()` 导致的不必要全量拷贝。
    fn decode_content(&self, content: &[u8]) -> Result<String, AppError> {
        // 先尝试零拷贝解析（EPUB 规范要求 UTF-8）
        match std::str::from_utf8(content) {
            Ok(s) => return Ok(s.to_string()),
            Err(e) => {
                tracing::debug!("EPUB 内容非 UTF-8，尝试解码: {:?}", e);
            }
        }

        // 回退到 encoding_rs 解码
        let (decoded, _, _) = encoding_rs::UTF_8.decode(content);
        Ok(decoded.into_owned())
    }

    /// 读取章节内容（HTML）
    pub fn read_chapter(&mut self, href: &str) -> Result<String, AppError> {
        self.read_resource(href)
    }

    /// 读取资源字节（不解码）
    pub fn read_resource_bytes(&mut self, href: &str) -> Option<Vec<u8>> {
        // 检查缓存
        if let Some(cached) = self.cache.get(href) {
            return Some(cached.clone());
        }

        // 查找资源
        let (resource_href, _resource) = find_resource_by_href_or_path(&self.doc.resources, href)?;
        let resource_href: String = resource_href.clone();

        // 设置当前章节到该资源
        let index = self
            .doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href)?;
        let _ = self.doc.set_current_chapter(index);

        // 读取内容 - epub 2.x 返回 (Vec<u8>, String) 元组
        let (content, _charset) = self.doc.get_current()?;

        // 缓存内容
        self.cache.put(href.to_string(), content.clone());

        Some(content)
    }

    /// 读取封面图片
    pub fn read_cover(&mut self) -> Option<Vec<u8>> {
        // 收集可能的封面路径（避免借用冲突）
        let mut candidates: Vec<String> = Vec::new();

        // 1. 尝试从 metadata 获取 cover
        if let Some(cover_href) = get_metadata_first(&self.doc.metadata, "cover") {
            candidates.push(cover_href);
        }

        candidates.extend(COVER_CANDIDATES.iter().map(|&s| s.to_string()));

        // 3. 查找包含 "cover" 的图片资源
        for href in self.doc.resources.keys() {
            let lower_href = href.to_lowercase();
            if (lower_href.contains("cover") || lower_href.contains("封面"))
                && (lower_href.ends_with(".jpg")
                    || lower_href.ends_with(".jpeg")
                    || lower_href.ends_with(".png"))
            {
                candidates.push(href.clone());
            }
        }

        // 尝试读取每个候选路径
        for href in candidates {
            if let Some(content) = self.read_resource_bytes(&href) {
                return Some(content);
            }
        }

        None
    }

    /// 清除缓存
    pub fn clear_cache(&mut self) {
        self.cache.clear();
    }

    /// 获取所有图片资源的列表
    ///
    /// 返回所有图片资源的 (href, 文件名) 列表
    pub fn list_images(&self) -> Vec<(String, String)> {
        self.doc
            .resources
            .iter()
            .filter(|(_, item)| {
                let path_str = item.path.to_string_lossy().to_lowercase();
                is_image_extension(&path_str)
            })
            .map(|(href, item)| {
                // 提取文件名
                let path_str = item.path.to_string_lossy();
                let filename = path_str
                    .rsplit('/')
                    .next()
                    .or_else(|| path_str.rsplit('\\').next())
                    .unwrap_or(href)
                    .to_string();
                (href.clone(), filename)
            })
            .collect()
    }

    /// 判断资源是否为图片
    pub fn is_image_resource(&self, href: &str) -> bool {
        if let Some(item) = self.doc.resources.get(href) {
            let path_str = item.path.to_string_lossy().to_lowercase();
            is_image_extension(&path_str)
        } else {
            // 尝试从 href 本身判断
            let lower = href.to_lowercase();
            is_image_extension(&lower)
        }
    }
}
fn is_image_extension(path: &str) -> bool {
    matches!(
        path.rsplit('.').next().unwrap_or(""),
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "bmp" | "svg"
    )
}
/// 获取 EPUB 元数据（快速预览，不读取章节内容）
///
/// 用于 Flutter 侧快速获取 EPUB 文件的基本信息，
/// 无需完整解析即可显示书名、作者、封面、目录等。
///
/// # 参数
/// * `file_path` - EPUB 文件路径
///
/// # 返回值
/// * `Ok(EpubMetadata)` - 元数据
/// * `Err(AppError)` - 解析失败
pub fn get_epub_metadata(file_path: &str) -> Result<EpubMetadata,AppError> {
    let epub_file = EpubFile::open(file_path)?;

    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();
    let toc = epub_file
        .toc()
        .into_iter()
        .map(|(label, href)| crate::domain::EpubTocItem { label, href, level: 1 })
        .collect();
    let spine = epub_file.spine();

    Ok(EpubMetadata {
        title,
        author,
        cover_path,
        toc,
        spine,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epub_not_found() {
        let result = EpubFile::open("non_existent.epub");
        assert!(result.is_err());
    }

    #[test]
    fn test_get_epub_metadata_not_found() {
        let result = get_epub_metadata("non_existent.epub");
        assert!(result.is_err());
    }
}
