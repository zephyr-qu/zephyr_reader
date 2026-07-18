// ============================================================
// 文件作用：EPUB 图片 asset 注册表（M1.4），将 IR ImageBlock::asset_id
//           解析为 manifest 资源 id，并提供包内路径查询。
//
// 公有类型/函数：
//   - EpubAssetEntry — 注册表条目（asset_id + internal_path）
//   - EpubAssetRegistry — EPUB manifest 资源注册表
//     - from_manifest() / from_epub() — 构建注册表
//     - len() / get() / internal_path() / resolve()
//     - read_bytes() — 读取 asset 原始字节
//   - canonicalize_chapter_image_assets() — 规范化章 IR 中图片 asset_id
//   - normalize_asset_id() — 规范化 img src
//   - resolve_relative_href() — 解析相对 href
//   - normalize_asset_path() — 折叠路径分量
// ============================================================

//! EPUB 图片 asset 注册表（M1.4）
//!
//! 将 IR [`ImageBlock::asset_id`] 解析为 manifest 资源 id，并提供包内路径查询。
//! `asset_id` = EPUB manifest key（`resources` HashMap 的 key），非 zip 绝对路径。

use std::collections::HashMap;

use epub::doc::ResourceItem;

use super::archive_reader::EpubFile;
use crate::pipeline::{ReaderChapterIr, ReaderIrBlockKind};

/// 注册表条目：`asset_id`（manifest key）→ EPUB 包内路径。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EpubAssetEntry {
    /// manifest 资源 id（`read_resource_bytes` 使用的 href/key）。
    pub asset_id: String,
    /// OPF 中记录的 archive 内路径（调试 / 后缀匹配用）。
    pub internal_path: String,
}

/// EPUB manifest 资源注册表。
#[derive(Debug, Clone, Default)]
pub struct EpubAssetRegistry {
    by_asset_id: HashMap<String, EpubAssetEntry>,
    /// 规范化 archive 路径 → manifest id
    by_internal_path: HashMap<String, String>,
    /// 文件名后缀 → manifest id（同名资源取 manifest 顺序靠后者覆盖）
    by_filename: HashMap<String, String>,
}

/// 规范化 img `src` / manifest href（trim、`\`→`/`、去 `#` 片段、折叠 `%` 编码 ASCII）。
pub fn normalize_asset_id(src: &str) -> String {
    let trimmed = src.trim().replace('\\', "/");
    let without_fragment = trimmed.split('#').next().unwrap_or(trimmed.as_str());
    decode_percent_ascii(without_fragment)
}

/// 将 `src` 相对 `chapter_href`（spine XHTML manifest id 或 path）解析为包内逻辑路径。
pub fn resolve_relative_href(chapter_href: &str, src: &str) -> String {
    let src = normalize_asset_id(src);
    if src.is_empty() {
        return src;
    }
    if src.contains("://") {
        return src;
    }
    if src.starts_with('/') {
        return normalize_asset_path(src.trim_start_matches('/'));
    }
    let base_dir = chapter_href
        .rfind('/')
        .map(|i| &chapter_href[..=i])
        .unwrap_or("");
    normalize_asset_path(&format!("{base_dir}{src}"))
}

/// 折叠 `.` / `..` 路径分量。
pub fn normalize_asset_path(path: &str) -> String {
    let mut stack: Vec<&str> = Vec::new();
    for part in path.split('/') {
        match part {
            "" | "." => {}
            ".." => {
                stack.pop();
            }
            p => stack.push(p),
        }
    }
    stack.join("/")
}

impl EpubAssetRegistry {
    /// 从 EPUB manifest 构建全量资源索引。
    pub fn from_manifest(resources: &HashMap<String, ResourceItem>) -> Self {
        let mut registry = Self::default();
        for (id, item) in resources {
            let internal_path = item.path.to_string_lossy().replace('\\', "/");
            let entry = EpubAssetEntry {
                asset_id: id.clone(),
                internal_path: internal_path.clone(),
            };
            registry.by_asset_id.insert(id.clone(), entry);
            registry
                .by_internal_path
                .insert(normalize_asset_path(&internal_path), id.clone());
            if let Some(name) = internal_path.rsplit('/').next().filter(|s| !s.is_empty()) {
                registry.by_filename.insert(name.to_string(), id.clone());
            }
        }
        registry
    }

    /// 从已打开的 EPUB 构建注册表。
    pub fn from_epub(epub: &EpubFile) -> Self {
        Self::from_manifest(epub.resources())
    }

    pub fn is_empty(&self) -> bool {
        self.by_asset_id.is_empty()
    }

    pub fn len(&self) -> usize {
        self.by_asset_id.len()
    }

    pub fn get(&self, asset_id: &str) -> Option<&EpubAssetEntry> {
        self.by_asset_id.get(asset_id)
    }

    /// manifest id 对应的 EPUB 包内路径。
    pub fn internal_path(&self, asset_id: &str) -> Option<&str> {
        self.get(asset_id).map(|e| e.internal_path.as_str())
    }

    /// 解析章内相对 `src` → manifest 条目。
    pub fn resolve(&self, chapter_href: &str, raw_src: &str) -> Option<&EpubAssetEntry> {
        let resolved = resolve_relative_href(chapter_href, raw_src);
        self.lookup_resolved(&resolved)
    }

    /// 读取 asset 原始字节（manifest id、包内路径或章内相对 src 均可尝试）。
    pub fn read_bytes(&self, epub: &mut EpubFile, asset_id: &str) -> Option<Vec<u8>> {
        let asset_id = normalize_asset_id(asset_id);
        if asset_id.is_empty() {
            return None;
        }
        let mut tried = std::collections::HashSet::<String>::new();
        let mut queue: Vec<String> = Vec::new();

        if let Some(entry) = self
            .get(&asset_id)
            .or_else(|| self.lookup_resolved(&asset_id))
        {
            queue.push(entry.asset_id.clone());
            queue.push(entry.internal_path.clone());
        }
        queue.push(asset_id.clone());

        while let Some(href) = queue.pop() {
            if href.is_empty() || !tried.insert(href.clone()) {
                continue;
            }
            if let Some(bytes) = epub.read_resource_bytes(&href)
                && !bytes.is_empty()
            {
                return Some(bytes);
            }
        }
        None
    }

    fn lookup_resolved(&self, resolved: &str) -> Option<&EpubAssetEntry> {
        let normalized = normalize_asset_path(resolved);

        if let Some(entry) = self.by_asset_id.get(resolved) {
            return Some(entry);
        }
        if let Some(entry) = self.by_asset_id.get(&normalized) {
            return Some(entry);
        }
        if let Some(id) = self.by_internal_path.get(&normalized) {
            return self.by_asset_id.get(id);
        }
        if let Some(name) = normalized.rsplit('/').next().filter(|s| !s.is_empty())
            && let Some(id) = self.by_filename.get(name)
        {
            return self.by_asset_id.get(id);
        }
        self.by_asset_id.values().find(|entry| {
            entry.internal_path == normalized
                || entry.internal_path.ends_with(&format!("/{normalized}"))
                || entry.asset_id == normalized
        })
    }
}

/// 将章 IR 中 Image 块的 `asset_id` 规范化为 manifest id（无法解析则保留原值）。
pub fn canonicalize_chapter_image_assets(
    ir: &mut ReaderChapterIr,
    registry: &EpubAssetRegistry,
    chapter_href: &str,
) {
    for block in &mut ir.blocks {
        if block.kind != ReaderIrBlockKind::Image {
            continue;
        }
        let raw = match &block.image_asset_id {
            Some(id) => id.clone(),
            None => continue,
        };
        if let Some(entry) = registry.resolve(chapter_href, &raw) {
            block.image_asset_id = Some(entry.asset_id.clone());
        } else {
            tracing::warn!(
                raw_src = %raw,
                chapter_href = %chapter_href,
                "failed to resolve image asset_id to manifest entry"
            );
        }
    }
}

fn decode_percent_ascii(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%'
            && i + 2 < bytes.len()
            && let (Some(h1), Some(h2)) = (hex_nibble(bytes[i + 1]), hex_nibble(bytes[i + 2]))
        {
            out.push((h1 << 4) | h2);
            i += 3;
            continue;
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex_nibble(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;
    use std::path::PathBuf;

    use epub::doc::ResourceItem;

    use super::*;
    use crate::pipeline::{ReaderChapterIr, ReaderIrBlock};

    fn sample_registry() -> EpubAssetRegistry {
        let mut resources = HashMap::new();
        resources.insert(
            "img_main".into(),
            ResourceItem {
                path: PathBuf::from("OEBPS/Images/cover.jpg"),
                mime: "image/jpeg".into(),
                properties: None,
            },
        );
        resources.insert(
            "id_inline".into(),
            ResourceItem {
                path: PathBuf::from("OEBPS/Text/photo.png"),
                mime: "image/png".into(),
                properties: None,
            },
        );
        EpubAssetRegistry::from_manifest(&resources)
    }

    #[test]
    fn normalize_asset_path_collapses_dotdot() {
        assert_eq!(
            normalize_asset_path("OEBPS/Text/../Images/a.jpg"),
            "OEBPS/Images/a.jpg"
        );
    }

    #[test]
    fn resolve_relative_href_from_chapter() {
        assert_eq!(
            resolve_relative_href("OEBPS/Text/chapter1.xhtml", "../Images/cover.jpg"),
            "OEBPS/Images/cover.jpg"
        );
    }

    #[test]
    fn resolve_percent_encoded_filename() {
        assert_eq!(
            normalize_asset_id("images/hello%20world.jpg"),
            "images/hello world.jpg"
        );
    }

    #[test]
    fn normalize_strips_url_fragment() {
        assert_eq!(
            normalize_asset_id("../Images/cover.jpg#fragment"),
            "../Images/cover.jpg"
        );
        assert_eq!(normalize_asset_id("images/pic.png#"), "images/pic.png");
    }

    #[test]
    fn lookup_by_relative_src_and_filename() {
        let registry = sample_registry();
        let entry = registry
            .resolve("OEBPS/Text/chapter1.xhtml", "../Images/cover.jpg")
            .expect("relative path should resolve");
        assert_eq!(entry.asset_id, "img_main");
        assert_eq!(entry.internal_path, "OEBPS/Images/cover.jpg");

        let by_name = registry
            .resolve("", "photo.png")
            .expect("filename fallback");
        assert_eq!(by_name.asset_id, "id_inline");
    }

    #[test]
    fn canonicalize_rewrites_image_asset_id() {
        let mut ir = ReaderChapterIr::new(
            vec![ReaderIrBlock::image(
                0,
                "../Images/cover.jpg".into(),
                None,
                None,
                None,
            )],
            "\u{FFFC}".to_string(),
        );
        let registry = sample_registry();
        canonicalize_chapter_image_assets(&mut ir, &registry, "OEBPS/Text/chapter1.xhtml");
        let block = &ir.blocks[0];
        assert_eq!(block.image_asset_id.as_deref(), Some("img_main"));
    }

    #[test]
    fn registry_from_epub_fixture_if_present() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../test/fixtures/medium.epub");
        if !path.exists() {
            return;
        }
        let epub = EpubFile::open(path.to_str().unwrap()).expect("open medium.epub");
        let registry = EpubAssetRegistry::from_epub(&epub);
        assert!(
            registry.len() > 0,
            "medium.epub should have manifest resources"
        );
    }
}
