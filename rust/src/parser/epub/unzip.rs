//! EPUB 文件解压与读取
//! 使用 epub 库读取 EPUB 文件结构
//! 注意：epub crate 2.x API 与 1.x 不兼容

use crate::ffi::ParserError;
use epub::doc::{EpubDoc, ResourceItem, SpineItem};
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

/// EPUB 文件句柄（带缓存）
pub struct EpubFile {
    doc: EpubDoc<BufReader<File>>,
    cache: HashMap<String, Vec<u8>>,
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
    pub fn open(file_path: &str) -> Result<Self, ParserError> {
        if !std::path::Path::new(file_path).exists() {
            return Err(ParserError::file_not_found(file_path));
        }

        let doc = EpubDoc::new(file_path).map_err(|e| {
            ParserError::file_read_error(file_path, format!("EPUB 解析失败：{}", e))
        })?;

        Ok(Self {
            doc,
            cache: HashMap::new(),
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
    pub fn read_resource(&mut self, href: &str) -> Result<String, ParserError> {
        // 检查缓存
        if let Some(cached) = self.cache.get(href) {
            return self.decode_content(cached);
        }

        // 查找资源
        let (resource_href, _resource) =
            find_resource_by_href_or_path(&self.doc.resources, href)
                .ok_or_else(|| ParserError::EpubParseError(format!("资源不存在：{}", href)))?;

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
                ParserError::EpubParseError("读取资源失败：无法获取当前内容".to_string())
            })?;

            // 缓存内容（只缓存字节）
            self.cache.insert(href.to_string(), content.clone());

            return self.decode_content(&content);
        }

        Err(ParserError::EpubParseError(format!(
            "无法定位资源：{}",
            href
        )))
    }

    /// 解码内容（EPUB 规范要求 UTF-8，提供回退）
    fn decode_content(&self, content: &[u8]) -> Result<String, ParserError> {
        match String::from_utf8(content.to_vec()) {
            Ok(s) => Ok(s),
            Err(_) => {
                // 回退到 encoding_rs 解码
                let (decoded, _, _) = encoding_rs::UTF_8.decode(content);
                Ok(decoded.into_owned())
            }
        }
    }

    /// 读取章节内容（HTML）
    pub fn read_chapter(&mut self, href: &str) -> Result<String, ParserError> {
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
        self.cache.insert(href.to_string(), content.clone());

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

        // 2. 常见封面文件名
        let cover_names = [
            "cover.jpg",
            "cover.jpeg",
            "cover.png",
            "Cover.jpg",
            "Cover.jpeg",
            "Cover.png",
            "coverimage.jpg",
            "coverimage.png",
        ];
        candidates.extend(cover_names.iter().map(|&s| s.to_string()));

        // 3. 查找包含 "cover" 的图片资源
        for (href, _item) in &self.doc.resources {
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
                path_str.ends_with(".jpg")
                    || path_str.ends_with(".jpeg")
                    || path_str.ends_with(".png")
                    || path_str.ends_with(".gif")
                    || path_str.ends_with(".webp")
                    || path_str.ends_with(".bmp")
                    || path_str.ends_with(".svg")
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
            path_str.ends_with(".jpg")
                || path_str.ends_with(".jpeg")
                || path_str.ends_with(".png")
                || path_str.ends_with(".gif")
                || path_str.ends_with(".webp")
                || path_str.ends_with(".bmp")
                || path_str.ends_with(".svg")
        } else {
            // 尝试从 href 本身判断
            let lower = href.to_lowercase();
            lower.ends_with(".jpg")
                || lower.ends_with(".jpeg")
                || lower.ends_with(".png")
                || lower.ends_with(".gif")
                || lower.ends_with(".webp")
                || lower.ends_with(".bmp")
                || lower.ends_with(".svg")
        }
    }
}

/// 获取 EPUB 元数据
pub fn get_epub_metadata(file_path: &str) -> Result<(String, String, Option<String>), ParserError> {
    let epub_file = EpubFile::open(file_path)?;

    let title = epub_file.title();
    let author = epub_file.author();
    let cover = epub_file.cover_path();

    Ok((title, author, cover))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epub_not_found() {
        let result = EpubFile::open("non_existent.epub");
        assert!(result.is_err());
    }
}
