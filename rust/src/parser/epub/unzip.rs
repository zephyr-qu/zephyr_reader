//! EPUB 文件解压与读取
//! 使用 epub 库读取 EPUB 文件结构
//! 注意：epub crate 2.x API 与 1.x 不兼容

use crate::domain::{AppError, EpubMetadata};
use epub::doc::{EpubDoc, ResourceItem, SpineItem};
use lru::LruCache;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::num::NonZeroUsize;

/// EPUB 缓存最大条目数
const EPUB_CACHE_SIZE: usize = 50;
const COVER_CANDIDATES: &[&str] = &[
    "cover.jpg",
    "cover.jpeg",
    "cover.png",
    "Cover.jpg",
    "Cover.jpeg",
    "Cover.png",
    "coverimage.jpg",
    "coverimage.png",
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

/// 辅助函数：获取翻译者
/// 查找 role 细目为 "trl" 的 creator，或第一个非 author 的 creator，或 contributor
fn get_translator(metadata: &[epub::doc::MetadataItem]) -> Option<String> {
    // 先找 role=trl 的 creator
    for item in metadata.iter().filter(|m| m.property == "creator") {
        let has_trl_role = item
            .refined
            .iter()
            .any(|r| r.property == "role" && (r.value == "trl" || r.value == "translator"));
        if has_trl_role {
            return Some(item.value.clone());
        }
    }
    // 再找 contributor
    for item in metadata.iter().filter(|m| m.property == "contributor") {
        let has_trl_role = item
            .refined
            .iter()
            .any(|r| r.property == "role" && (r.value == "trl" || r.value == "translator"));
        if has_trl_role {
            return Some(item.value.clone());
        }
    }
    // 最后取第2个 creator（启发式：常见于中日双语书籍）
    let creators: Vec<&str> = metadata
        .iter()
        .filter(|m| m.property == "creator")
        .map(|m| m.value.as_str())
        .collect();
    if creators.len() > 1 && creators[0] != creators[1] {
        return Some(creators[1].to_string());
    }
    None
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
            return Err(AppError::FileNotFound { path: file_path.into() });
        }

        tracing::info!("[EpubFile::open] opening EPUB: {}", file_path);
        let doc = EpubDoc::new(file_path).map_err(|e| {
            AppError::FileReadError { path: file_path.into(), details: format!("EPUB parse failed: {}", e).into() }
        })?;
        tracing::info!(
            "[EpubFile::open] success: metadata={}, resources={}, spine={}, toc={}",
            doc.metadata.len(),
            doc.resources.len(),
            doc.spine.len(),
            doc.toc.len()
        );

        Ok(Self {
            doc,
            cache: LruCache::new(NonZeroUsize::new(EPUB_CACHE_SIZE).unwrap()),
        })
    }

    /// 获取书籍标题
    pub fn title(&self) -> String {
        get_metadata_first(&self.doc.metadata, "title")
            .unwrap_or_else(|| "Unknown Title".to_string())
    }

    /// 获取作者
    pub fn author(&self) -> String {
        get_metadata_first(&self.doc.metadata, "creator")
            .unwrap_or_else(|| "Unknown Author".to_string())
    }

    /// 获取封面路径
    pub fn cover_path(&self) -> Option<String> {
        get_metadata_first(&self.doc.metadata, "cover")
    }

    /// 获取目录（NCX/Nav），扁平化为 (label, href, level) 三元组
    /// level 从 1 开始（1 = 顶级章节）
    pub fn toc(&self) -> Vec<(String, String, i32)> {
        let mut result = Vec::new();
        flatten_toc(&self.doc.toc, 1, &mut result);
        result
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
            tracing::debug!("[read_resource] cache hit: href={}", href);
            return self.decode_content(&cached);
        }

        // 查找资源
        let (resource_href, resource) = find_resource_by_href_or_path(&self.doc.resources, href)
            .ok_or_else(|| AppError::EpubParseError { reason: format!("resource not found: {}", href).into() })?;

        let resource_href: String = resource_href.clone();
        tracing::debug!(
            "[read_resource] resource found: href={resource_href}, path={:?}",
            resource.path
        );

        // 设置当前章节到该资源
        let index = self
            .doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href);
        if let Some(idx) = index {
            tracing::debug!("[read_resource] spine index: {idx}");
            let _ = self.doc.set_current_chapter(idx);

            // 读取内容 - epub 2.x 返回 (Vec<u8>, String) 元组
            let (content, charset) = self.doc.get_current().ok_or_else(|| {
                AppError::EpubParseError { reason: "read resource failed: unable to get current content".to_string().into() }
            })?;

            tracing::debug!(
                "[read_resource] read success: {} bytes, charset={:?}",
                content.len(),
                charset
            );

            // 缓存内容（只缓存字节）
            self.cache.put(href.to_string(), content.clone());

            return self.decode_content(&content);
        }

        tracing::warn!(
            "[read_resource] resource not found in spine: {}",
            resource_href
        );
        Err(AppError::EpubParseError { reason: format!(
            "unable to locate resource: {}",
            href
        ).into() })
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
                tracing::debug!("EPUB content is not UTF-8, attempting decode: {:?}", e);
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

        // 先尝试从 spine 读取（适用于章节等文本资源）
        if let Some(index) = self
            .doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href)
        {
            let _ = self.doc.set_current_chapter(index);
            let (content, _charset) = self.doc.get_current()?;
            self.cache.put(href.to_string(), content.clone());
            Some(content)
        } else {
            // 不在 spine 中（如封面图片），直接从 archive 读取
            let (content, _mime) = self.doc.get_resource(&resource_href)?;
            self.cache.put(href.to_string(), content.clone());
            Some(content)
        }
    }

    /// manifest 资源表（M1.4 asset 注册表输入）。
    pub fn resources(&self) -> &HashMap<String, ResourceItem> {
        &self.doc.resources
    }

    /// 获取原始 metadata（用于外部提取扩展字段）
    pub fn raw_metadata(&self) -> &[epub::doc::MetadataItem] {
        &self.doc.metadata
    }

    /// 获取出版社
    pub fn publisher(&self) -> Option<String> {
        get_metadata_first(&self.doc.metadata, "publisher")
    }

    /// 获取翻译者
    pub fn translator(&self) -> Option<String> {
        get_translator(&self.doc.metadata)
    }

    /// 获取标识符（ISBN）
    pub fn identifier(&self) -> Option<String> {
        get_metadata_first(&self.doc.metadata, "identifier")
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

    /// 通过 TOC href 查找对应的 spine 索引
    ///
    /// TOC 中的 href 是文件路径（如 "text/part0000.html"），
    /// 而 spine 中存的是 resource ID（如 "id5"），
    /// 需要通过 manifest 中的 resource path 做桥接。
    pub fn find_spine_index_by_toc_href(&self, toc_href: &str) -> Option<usize> {
        let pure_href = toc_href.split('#').next().unwrap_or(toc_href);
        // 在 resources 中找 path 结尾匹配 TOC href 的条目
        let resource_id = self
            .doc
            .resources
            .iter()
            .find(|(_, res)| res.path.to_string_lossy().ends_with(pure_href))
            .map(|(id, _)| id.clone())?;
        // 在 spine 中找 idref 匹配该 resource ID 的位置
        self.doc
            .spine
            .iter()
            .position(|item| item.idref == resource_id)
    }
}
/// 递归展开 NavPoint 树为扁平列表 (label, href, level)
fn flatten_toc(
    navpoints: &[epub::doc::NavPoint],
    level: i32,
    result: &mut Vec<(String, String, i32)>,
) {
    for nav in navpoints {
        let href = nav.content.to_string_lossy().to_string();
        result.push((nav.label.clone(), href, level));
        if !nav.children.is_empty() {
            flatten_toc(&nav.children, level + 1, result);
        }
    }
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
pub fn get_epub_metadata(file_path: &str) -> Result<EpubMetadata, AppError> {
    let epub_file = EpubFile::open(file_path)?;

    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();
    let toc = epub_file
        .toc()
        .into_iter()
        .map(|(label, href, level)| crate::domain::EpubTocItem { label, href, level })
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
