//! EPUB 文件解压与读取
//! 使用 epub 库读取 EPUB 文件结构

use crate::ffi::ParserError;
use epub::doc::EpubDoc;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

/// EPUB 文件句柄（带缓存）
pub struct EpubFile {
    doc: EpubDoc<BufReader<File>>,
    cache: HashMap<String, Vec<u8>>,
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
        self.doc
            .metadata
            .get("title")
            .and_then(|v| v.first())
            .cloned()
            .unwrap_or_else(|| "未知标题".to_string())
    }

    /// 获取作者
    pub fn author(&self) -> String {
        self.doc
            .metadata
            .get("creator")
            .and_then(|v| v.first())
            .cloned()
            .unwrap_or_else(|| "未知作者".to_string())
    }

    /// 获取封面路径
    pub fn cover_path(&self) -> Option<String> {
        // Try to get cover from metadata
        self.doc
            .metadata
            .get("cover")
            .and_then(|v| v.first())
            .cloned()
    }

    /// 获取目录（NCX/Nav）
    pub fn toc(&self) -> Vec<(String, String)> {
        self.doc
            .toc
            .iter()
            .map(|nav| (nav.label.clone(), nav.content.to_string_lossy().to_string()))
            .collect()
    }

    /// 获取 spine（阅读顺序）
    pub fn spine(&self) -> Vec<String> {
        self.doc.spine.clone()
    }

    /// 读取指定资源内容（带缓存）
    pub fn read_resource(&mut self, href: &str) -> Result<String, ParserError> {
        // 检查缓存
        if let Some(cached) = self.cache.get(href) {
            return self.decode_content(cached);
        }

        // 查找资源
        let resource = self
            .doc
            .resources
            .get(href)
            .or_else(|| {
                self.doc
                    .resources
                    .values()
                    .find(|(path, _)| path.ends_with(href))
            })
            .ok_or_else(|| ParserError::EpubParseError(format!("资源不存在：{}", href)))?;

        let resource_path = resource.0.clone();

        // 设置当前页到该资源
        let index = self.doc.spine.iter().position(|x| x == &resource_path);
        if let Some(idx) = index {
            let _ = self.doc.set_current_page(idx);

            // 读取内容
            let content = self
                .doc
                .get_current()
                .map_err(|e| ParserError::EpubParseError(format!("读取资源失败：{}", e)))?;

            // 缓存内容
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

    /// 读取封面图片
    pub fn read_cover(&mut self) -> Option<Vec<u8>> {
        // Try to find cover href first
        let cover_href = self
            .doc
            .metadata
            .get("cover")
            .and_then(|v| v.first())
            .cloned()?;

        // 检查缓存
        if let Some(cached) = self.cache.get(&cover_href) {
            return Some(cached.clone());
        }

        // 尝试读取封面
        if let Some(resource) = self.doc.resources.get(&cover_href) {
            let resource_path = resource.0.clone();
            let index = self.doc.spine.iter().position(|x| x == &resource_path);
            if let Some(idx) = index {
                let _ = self.doc.set_current_page(idx);
                if let Ok(content) = self.doc.get_current() {
                    self.cache.insert(cover_href, content.clone());
                    return Some(content);
                }
            }
        }
        None
    }

    /// 清除缓存
    pub fn clear_cache(&mut self) {
        self.cache.clear();
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
