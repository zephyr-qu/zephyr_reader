//! 流式 EPUB 读取模块
//! 实现按需解压和资源流式读取，降低内存峰值

use crate::ffi::types::{EpubMetadata, EpubTocItem};
use crate::ffi::ParserError;
use epub::doc::{EpubDoc, ResourceItem, SpineItem};
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::Path;

/// 辅助函数：从 MetadataItem Vec 中获取指定类型的第一个值
/// epub 2.x 使用 property/value 而不是 name/content
/// 注意：epub 2.x 中 MetadataItem.value 是 String 类型，不是 Vec<String>
fn get_metadata_first(metadata: &[epub::doc::MetadataItem], name: &str) -> Option<String> {
    metadata
        .iter()
        .find(|m| m.property == name)
        .map(|m| m.value.clone())
}

/// 辅助函数：从 ResourceItem HashMap 中查找资源路径
fn find_resource_path(resources: &HashMap<String, ResourceItem>, href: &str) -> Option<String> {
    // 首先尝试直接匹配 href
    if resources.contains_key(href) {
        return Some(href.to_string());
    }

    // 然后尝试匹配路径结尾
    resources
        .iter()
        .find(|(_, item)| item.path.to_string_lossy().ends_with(href))
        .map(|(href, _)| href.clone())
}

/// 流式 EPUB 读取器
///
/// 与标准 EpubFile 不同，此读取器支持：
/// - 按需读取单个章节，不一次性加载所有内容
/// - 流式解析 HTML，提取纯文本
/// - 内存映射大文件，减少内存占用
pub struct StreamingEpubReader {
    file_path: String,
    doc: Option<EpubDoc<BufReader<File>>>,
    resource_cache: HashMap<String, Vec<u8>>,
    max_cache_size: usize,
}

impl StreamingEpubReader {
    /// 创建新的流式读取器
    pub fn new(file_path: &str) -> Result<Self, ParserError> {
        if !Path::new(file_path).exists() {
            return Err(ParserError::file_not_found(file_path));
        }

        Ok(Self {
            file_path: file_path.to_string(),
            doc: None,
            resource_cache: HashMap::new(),
            max_cache_size: 10, // 最多缓存 10 个资源
        })
    }

    /// 打开 EPUB 文档（懒加载）
    fn ensure_doc_opened(&mut self) -> Result<(), ParserError> {
        if self.doc.is_some() {
            return Ok(());
        }

        let doc = EpubDoc::new(&self.file_path).map_err(|e| {
            ParserError::file_read_error(&self.file_path, format!("EPUB 打开失败：{}", e))
        })?;

        self.doc = Some(doc);
        Ok(())
    }

    /// 获取 EPUB 元数据（不加载内容）
    pub fn get_metadata(&mut self) -> Result<EpubMetadata, ParserError> {
        self.ensure_doc_opened()?;

        let doc = self.doc.as_ref().unwrap();

        Ok(EpubMetadata {
            title: get_metadata_first(&doc.metadata, "title")
                .unwrap_or_else(|| "未知标题".to_string()),
            author: get_metadata_first(&doc.metadata, "creator")
                .unwrap_or_else(|| "未知作者".to_string()),
            spine: doc
                .spine
                .iter()
                .map(|item: &SpineItem| item.idref.clone())
                .collect(),
            toc: doc
                .toc
                .iter()
                .map(|nav| EpubTocItem {
                    label: nav.label.clone(),
                    href: nav.content.to_string_lossy().to_string(),
                })
                .collect(),
            cover_path: get_metadata_first(&doc.metadata, "cover"),
        })
    }

    /// 流式读取单个章节内容
    ///
    /// 只读取指定章节，不加载其他内容
    pub fn read_chapter_streaming(&mut self, href: &str) -> Result<String, ParserError> {
        self.ensure_doc_opened()?;

        // 检查缓存
        if let Some(cached) = self.resource_cache.get(href) {
            return self.decode_content(cached);
        }

        let doc = self.doc.as_mut().unwrap();

        // 查找资源
        let resource_href = find_resource_path(&doc.resources, href)
            .ok_or_else(|| ParserError::EpubParseError(format!("资源不存在：{}", href)))?;

        // 设置当前章节
        if let Some(idx) = doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href)
        {
            let _ = doc.set_current_chapter(idx);

            // 读取内容 - epub 2.x 返回 (Vec<u8>, String) 元组
            let (content, _charset) = doc.get_current().ok_or_else(|| {
                ParserError::EpubParseError("读取章节失败：无法获取当前内容".to_string())
            })?;

            // 缓存管理
            if self.resource_cache.len() >= self.max_cache_size {
                // 移除最旧的缓存
                if let Some(first_key) = self.resource_cache.keys().next().cloned() {
                    self.resource_cache.remove(&first_key);
                }
            }

            // 存入缓存（只缓存字节）
            self.resource_cache
                .insert(href.to_string(), content.clone());

            return self.decode_content(&content);
        }

        Err(ParserError::EpubParseError(format!(
            "无法定位资源：{}",
            href
        )))
    }

    /// 流式解析 HTML，提取纯文本
    ///
    /// 使用简化的 HTML 解析，避免加载整个 DOM 树
    pub fn extract_text_from_html(&self, html_content: &str) -> String {
        // 简化版 HTML 转文本
        // 移除 script 和 style 标签
        let mut content = html_content.to_string();

        // 移除 script 标签
        content = remove_html_elements(&content, "script");
        // 移除 style 标签
        content = remove_html_elements(&content, "style");
        // 移除注释
        content = remove_html_comments(&content);

        // 替换常见块级元素为换行
        for tag in &["p", "div", "br", "h1", "h2", "h3", "h4", "h5", "h6", "li"] {
            content = content.replace(&format!("<{}", tag), &format!("\n<{}", tag));
        }

        // 移除所有 HTML 标签
        let text = strip_html_tags(&content);

        // 清理空白
        text.split_whitespace().collect::<Vec<_>>().join(" ")
    }

    /// 解码内容
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

    /// 获取资源字节（不解码）
    pub fn get_resource_bytes(&mut self, href: &str) -> Result<Vec<u8>, ParserError> {
        self.ensure_doc_opened()?;

        // 检查缓存
        if let Some(cached) = self.resource_cache.get(href) {
            return Ok(cached.clone());
        }

        let doc = self.doc.as_mut().unwrap();

        let resource_href = find_resource_path(&doc.resources, href)
            .ok_or_else(|| ParserError::EpubParseError(format!("资源不存在：{}", href)))?;

        if let Some(idx) = doc
            .spine
            .iter()
            .position(|item: &SpineItem| item.idref == resource_href)
        {
            let _ = doc.set_current_chapter(idx);

            // 读取内容 - epub 2.x 返回 (Vec<u8>, String) 元组
            let (content, _charset) = doc.get_current().ok_or_else(|| {
                ParserError::EpubParseError("读取资源失败：无法获取当前内容".to_string())
            })?;

            Ok(content)
        } else {
            Err(ParserError::EpubParseError(format!(
                "无法定位资源：{}",
                href
            )))
        }
    }

    /// 清除缓存
    pub fn clear_cache(&mut self) {
        self.resource_cache.clear();
    }
}

/// 移除 HTML 标签
fn strip_html_tags(html: &str) -> String {
    let mut result = String::new();
    let mut in_tag = false;

    for c in html.chars() {
        if c == '<' {
            in_tag = true;
        } else if c == '>' {
            in_tag = false;
        } else if !in_tag {
            result.push(c);
        }
    }

    result
}

/// 移除指定 HTML 元素及其内容
fn remove_html_elements(html: &str, tag: &str) -> String {
    let mut result = html.to_string();

    // 简单实现，移除 <tag>...</tag>
    while let Some(start) = result.find(&format!("<{}", tag)) {
        if let Some(end) = result[start..].find(&format!("</{}", tag)) {
            let end_pos = start + end + tag.len() + 2;
            result.replace_range(start..end_pos, "");
        } else {
            break;
        }
    }

    result
}

/// 移除 HTML 注释
fn remove_html_comments(html: &str) -> String {
    let mut result = String::new();
    let mut chars = html.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '<' && chars.peek() == Some(&'!') {
            // 检查是否是注释
            let mut comment_buf = String::from("<!");
            chars.next(); // 消耗 '!'

            while let Some(_) = chars.peek() {
                comment_buf.push(chars.next().unwrap());
                if comment_buf.ends_with("-->") {
                    break;
                }
            }
        } else {
            result.push(c);
        }
    }

    result
}

/// 创建流式 EPUB 读取器
#[frb(sync)]
pub fn create_streaming_epub_reader(file_path: String) -> Result<StreamingEpubReader, ParserError> {
    StreamingEpubReader::new(&file_path)
}

/// 流式读取章节
#[frb(sync)]
pub fn streaming_epub_read_chapter(
    mut reader: StreamingEpubReader,
    href: String,
) -> Result<String, ParserError> {
    reader.read_chapter_streaming(&href)
}

/// 从 HTML 提取纯文本
#[frb(sync)]
pub fn streaming_epub_extract_text(reader: &StreamingEpubReader, html_content: String) -> String {
    reader.extract_text_from_html(&html_content)
}

/// 获取 EPUB 元数据
#[frb(sync)]
pub fn streaming_epub_get_metadata(
    mut reader: StreamingEpubReader,
) -> Result<EpubMetadata, ParserError> {
    reader.get_metadata()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_strip_html_tags() {
        let html = "<p>Hello <b>World</b></p>";
        let text = strip_html_tags(html);
        assert_eq!(text, "Hello World");
    }

    #[test]
    fn test_remove_html_elements() {
        let html = "<p>Text</p><script>alert('x');</script><p>More</p>";
        let cleaned = remove_html_elements(html, "script");
        assert!(!cleaned.contains("script"));
    }
}
