// ============================================================
// 文件作用：EPUB 元数据提取，从 EpubFile 中提取标题、作者、目录、
//           封面路径、spine 等元数据信息。
//
// 公有类型/函数：
//   - get_epub_metadata() — 获取 EPUB 元数据（快速预览）
//   - get_metadata_first() — 从 MetadataItem 列表获取指定属性的第一个值
//
// 私有函数：
//   - get_translator() — 翻译者提取
//   - flatten_toc() — 递归展开 NavPoint 树
// ============================================================

//! EPUB 元数据提取
//! 从 EpubFile 中提取标题、作者、目录、封面路径等元数据信息
//! 文件 I/O 委托给 archive_reader 模块

use super::archive_reader::EpubFile;
use crate::domain::AppError;
use crate::parser::epub::{EpubMetadata, EpubTocItem};
use epub::doc::{MetadataItem, SpineItem};

/// 辅助函数：从 MetadataItem Vec 中获取指定类型的第一个值
/// epub 2.x 使用 property/value 而不是 name/content
/// 注意：epub 2.x 中 MetadataItem.value 是 String 类型，不是 Vec<String>
pub fn get_metadata_first(metadata: &[MetadataItem], name: &str) -> Option<String> {
    metadata
        .iter()
        .find(|m| m.property == name)
        .map(|m| m.value.clone())
}

/// 辅助函数：获取翻译者
/// 查找 role 细目为 "trl" 的 creator，或第一个非 author 的 creator，或 contributor
fn get_translator(metadata: &[MetadataItem]) -> Option<String> {
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

impl EpubFile {
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

    /// 通过 TOC href 查找对应的 spine 索引
    ///
    /// TOC 中的 href 是文件路径（如 "text/part0000.html"），
    /// 而 spine 中存的是 resource ID（如 "id5"），
    /// 需要通过 manifest 中的 resource path 做桥接。
    ///
    /// 匹配策略：先尝试路径结尾精确匹配，若失败则
    /// 仅比较文件名部分（忽略目录差异），提高对
    /// 目录结构不一致的 EPUB 的兼容性。
    pub fn find_spine_index_by_toc_href(&self, toc_href: &str) -> Option<usize> {
        let pure_href = toc_href.split('#').next().unwrap_or(toc_href);

        // Strategy 1: path suffix exact match (existing behavior)
        let resource_id = self
            .doc
            .resources
            .iter()
            .find(|(_, res)| res.path.to_string_lossy().ends_with(pure_href))
            .map(|(id, _)| id.clone());

        // Strategy 2: filename-only match (ignores directory prefix mismatch)
        let resource_id = resource_id.or_else(|| {
            let href_filename = pure_href
                .rsplit_once('/')
                .map(|(_, name)| name)
                .unwrap_or(pure_href);
            self.doc
                .resources
                .iter()
                .find(|(_, res)| {
                    let res_path = res.path.to_string_lossy();
                    let res_filename = res_path
                        .rsplit_once('/')
                        .map(|(_, name)| name)
                        .unwrap_or(&res_path);
                    res_filename == href_filename
                })
                .map(|(id, _)| id.clone())
        });

        // 在 spine 中找 idref 匹配该 resource ID 的位置
        resource_id.and_then(|rid| self.doc.spine.iter().position(|item| item.idref == rid))
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
        .map(|(label, href, level)| EpubTocItem { label, href, level })
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
    fn test_get_epub_metadata_not_found() {
        let result = get_epub_metadata("non_existent.epub");
        assert!(result.is_err());
    }
}
