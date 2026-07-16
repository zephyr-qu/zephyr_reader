// ============================================================
// 文件作用：EPUB 文件解压与读取，使用 epub crate 读取 EPUB 文件结构。
//           提供文件 I/O、资源查找和 LRU 缓存。
//
// 公有类型/函数：
//   - EpubFile — EPUB 文件句柄（带 LRU 缓存）
//     - open() — 打开 EPUB 文件
//     - read_resource() / read_chapter() / read_resource_bytes()
//     - read_cover() — 读取封面图片
//     - resources() / raw_metadata() — 资源/元数据访问器
//
// 私有函数：
//   - find_resource_by_href_or_path() — 资源查找
//   - resource_prefers_spine_text() — MIME 类型判断
// ============================================================

//! EPUB 文件解压与读取
//! 使用 epub 库读取 EPUB 文件结构
//! 元数据提取委托给 entry_extractor 模块

use super::asset_registry::normalize_asset_path;
use super::entry_extractor::get_metadata_first;
use crate::domain::AppError;
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
    pub(crate) doc: EpubDoc<BufReader<File>>,
    cache: LruCache<String, Vec<u8>>,
}

/// 辅助函数：从 ResourceItem HashMap 中查找资源
fn find_resource_by_href_or_path<'a>(
    resources: &'a HashMap<String, ResourceItem>,
    href: &str,
) -> Option<(&'a String, &'a ResourceItem)> {
    // 首先尝试直接匹配 manifest id
    if let Some((key, item)) = resources.get_key_value(href) {
        return Some((key, item));
    }

    let normalized = normalize_asset_path(href.trim().replace('\\', "/").as_str());

    // 规范化路径精确匹配 manifest id 或 OPF 内路径
    for (key, item) in resources.iter() {
        let internal = item.path.to_string_lossy().replace('\\', "/");
        let internal_norm = normalize_asset_path(&internal);
        if key == &normalized || internal == href || internal_norm == normalized {
            return Some((key, item));
        }
        if internal.ends_with(&normalized)
            || internal_norm.ends_with(&normalized)
            || normalized.ends_with(&internal_norm)
        {
            return Some((key, item));
        }
    }

    // 文件名后缀匹配
    if let Some(name) = normalized.rsplit('/').next().filter(|s| !s.is_empty()) {
        for (key, item) in resources.iter() {
            let internal = item.path.to_string_lossy().replace('\\', "/");
            if internal.rsplit('/').next() == Some(name) {
                return Some((key, item));
            }
        }
    }

    None
}

fn resource_prefers_spine_text(resource: &ResourceItem) -> bool {
    let mime = resource.mime.to_ascii_lowercase();
    mime.contains("html")
        || mime.contains("xml")
        || mime.contains("xhtml")
        || mime.contains("text/")
}

impl EpubFile {
    /// 打开 EPUB 文件
    pub fn open(file_path: &str) -> Result<Self, AppError> {
        if !std::path::Path::new(file_path).exists() {
            return Err(AppError::FileNotFound { path: file_path.into() });
        }

        tracing::info!("[EpubFile::open] opening EPUB: {}", file_path);
        let doc = EpubDoc::new(file_path).map_err(|e| {
            AppError::FileReadError { path: file_path.into(), details: format!("EPUB parse failed: {}", e) }
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

    /// 读取指定资源内容（带缓存）
    pub fn read_resource(&mut self, href: &str) -> Result<String, AppError> {
        // 检查缓存（先克隆内容以避免借用冲突）
        if let Some(cached) = self.cache.get(href).cloned() {
            tracing::debug!("[read_resource] cache hit: href={}", href);
            return self.decode_content(&cached);
        }

        // 查找资源
        let (resource_href, resource) = find_resource_by_href_or_path(&self.doc.resources, href)
            .ok_or_else(|| AppError::EpubParseError { reason: format!("resource not found: {}", href) })?;

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
                AppError::EpubParseError { reason: "read resource failed: unable to get current content".to_string() }
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
        ) })
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
        let href = href.split('#').next().unwrap_or(href).trim();
        if href.is_empty() {
            return None;
        }
        // 检查缓存
        if let Some(cached) = self.cache.get(href) {
            return Some(cached.clone());
        }

        // 查找资源
        let (resource_href, resource) = find_resource_by_href_or_path(&self.doc.resources, href)?;
        let resource_href: String = resource_href.clone();

        // 仅 XHTML/HTML 走 spine 文本路径；图片等二进制资源必须 get_resource
        if resource_prefers_spine_text(resource)
            && let Some(index) = self
                .doc
                .spine
                .iter()
                .position(|item: &SpineItem| item.idref == resource_href)
            {
                let _ = self.doc.set_current_chapter(index);
                if let Some((content, _charset)) = self.doc.get_current()
                    && !content.is_empty() {
                        self.cache.put(href.to_string(), content.clone());
                        return Some(content);
                    }
            }

        let (content, _mime) = self.doc.get_resource(&resource_href)?;
        if content.is_empty() {
            return None;
        }
        self.cache.put(href.to_string(), content.clone());
        Some(content)
    }

    /// manifest 资源表（M1.4 asset 注册表输入）。
    pub fn resources(&self) -> &HashMap<String, ResourceItem> {
        &self.doc.resources
    }

    /// 获取原始 metadata（用于外部提取扩展字段）
    pub fn raw_metadata(&self) -> &[epub::doc::MetadataItem] {
        &self.doc.metadata
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
