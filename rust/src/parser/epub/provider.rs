// =============================================================
// 文件作用：EPUB 按需内容提供器 — EpubContentProvider 基于 EpubFile 实现
//           spine item 粒度的懒加载。
//
// 公有类型/函数：
//   - EpubContentProvider — EPUB 按需内容提供器
//     - open_from_bounds() — 使用 DB 中的 spine 边界打开章节
//     - read_text_range() / read_html_range() — 读取文本/HTML 范围
//     - content_length() / format() — 内容长度和格式
//     - read_resource_bytes() — 读取资源原始字节
//     - read_spine_html() — 读取单个 spine 原始 HTML
//     - spine_count() / spine_internal_path() / primary_spine_href()
//     - asset_registry() — 构建 manifest asset 注册表
//
// 私有函数：
//   - ensure_spine_text() — 确保 spine 纯文本已缓存
//   - build_offsets_up_to() — 惰性构建偏移数组
//
// 依赖：
//   - plain_text::html_to_plain_text() — HTML 片段转纯文本
// =============================================================

//! EPUB 按需内容提供器
//!
//! `EpubContentProvider` 基于 `EpubFile` 实现 spine item 粒度的懒加载。
//! 每个 spine 的纯文本在其内容首次被请求时才加载和缓存，
//! 避免首次访问时加载整章所有 spine item 的内存浪费。

use std::sync::OnceLock;

use parking_lot::Mutex;

use super::archive_reader::EpubFile;
use super::asset_registry::EpubAssetRegistry;
use super::plain_text::html_to_plain_text;
use crate::domain::AppError;
use crate::domain::book::BookFormat;
use crate::parser::provider::ChapterContentProvider;

/// EPUB 按需内容提供器
///
/// 每个实例对应一书的一个章节（TOC entry）。
/// spine_hrefs 记录该章节覆盖的所有 spine item 的 href，
/// 首次读取时按需加载对应的 spine 并缓存。
pub struct EpubContentProvider {
    epub: Mutex<EpubFile>,
    spine_hrefs: Vec<String>,
    /// 每个 spine item 的纯文本（含尾部 \n 分隔符，最后一个除外）
    spine_texts: Vec<OnceLock<String>>,
    /// 每个 spine item 的原始 HTML（含尾部 \n 分隔符，最后一个除外）
    spine_htmls: Vec<OnceLock<String>>,
    /// 累积偏移量，惰性构建：转换为 spin 时追加实际长度，
    /// 未转换的 spin 在 `build_offsets_up_to` 中按需转换。
    offsets: Mutex<Vec<u64>>,
}

impl EpubContentProvider {
    /// 使用 DB 中的 spine 边界打开 EPUB 章节。
    ///
    /// 调用方在打开前通过 `get_chapter_bounds` 从 DB 读取边界；
    /// 导入阶段已按 `MAX_SPINE_ITEMS_PER_CHAPTER` 拆章，阅读侧不再截断。
    pub fn open_from_bounds(
        file_path: &str,
        start_index: i32,
        end_index: i32,
    ) -> Result<Self, AppError> {
        let mut epub = EpubFile::open(file_path)?;
        let spine = epub.spine();
        let start = start_index.max(0) as usize;
        let end = (end_index.max(0) as usize).min(spine.len()).max(start + 1);

        let spine_hrefs: Vec<String> = spine[start..end].to_vec();
        let count = spine_hrefs.len();

        // Detect oversized single-spine chapters (>2MB HTML)
        if count == 1
            && let Ok(html) = epub.read_resource(&spine_hrefs[0])
            && html.len() > 2_000_000
        {
            return Err(AppError::ChapterTooLarge {
                size_bytes: html.len(),
                details: format!("spine {} is {} bytes", &spine_hrefs[0], html.len()),
            });
        }

        Ok(Self {
            epub: Mutex::new(epub),
            spine_hrefs,
            spine_texts: (0..count).map(|_| OnceLock::new()).collect(),
            spine_htmls: (0..count).map(|_| OnceLock::new()).collect(),
            offsets: Mutex::new(vec![0u64]),
        })
    }
    /// 确保指定 spine index 的纯文本已缓存，返回其引用。
    /// 在 spine 文本后追加 `\n` 分隔符（最后一个 spine 除外），
    /// 以保持与旧版 `parts.join("\n")` 相同的行为。
    /// **不**负责偏移跟踪，调用方 `build_offsets_up_to` 处理。
    fn ensure_spine_text(&self, index: usize) -> Result<&str, AppError> {
        if let Some(text) = self.spine_texts[index].get() {
            return Ok(text.as_str());
        }

        let mut epub = self.epub.lock();
        let href = &self.spine_hrefs[index];
        let html = epub
            .read_resource(href)
            .map_err(|e| AppError::ChapterExtractError {
                index: -1,
                reason: format!("failed to read spine item {}: {}", href, e),
            })?;
        // 缓存原始 HTML，供 read_html_range 使用
        let _ = self.spine_htmls[index].get_or_init(|| html.clone());
        let plain = html_to_plain_text(&html);

        // 除最后一个 spine 外，追加 \n 分隔符以兼容 parts.join("\n") 行为
        let text = if index + 1 < self.spine_texts.len() {
            format!("{}\n", plain)
        } else {
            plain
        };

        Ok(self.spine_texts[index].get_or_init(|| text).as_str())
    }

    /// 惰性构建偏移数组，直到累积长度 ≥ `target_char`。
    ///
    /// 只转换必要的 spine：按顺序转换为 spine 并记录其实际长度。
    /// 未触及目标范围以外的 spine。已转换过的不重复转换。
    fn build_offsets_up_to(&self, target_char: u64) -> Result<Vec<u64>, AppError> {
        let cache = self.offsets.lock();
        // 检查是否已经达到目标
        if *cache.last().unwrap_or(&0) >= target_char && cache.len() > 1 {
            return Ok(cache.clone());
        }
        drop(cache);

        loop {
            let offsets = self.offsets.lock();
            let n_converted = offsets.len() - 1; // 已记录偏移的 spine 数量

            if n_converted >= self.spine_texts.len() {
                break; // 所有 spine 转换完成
            }
            if *offsets.last().unwrap_or(&0) >= target_char {
                break; // 已达到目标累积长度
            }

            // 转换下一个 spine
            drop(offsets);
            let text = self.ensure_spine_text(n_converted)?;

            // 记录偏移（确保未被其他路径提前记录）
            let mut offsets = self.offsets.lock();
            if offsets.len() == n_converted + 1 {
                let last = *offsets.last().unwrap_or(&0);
                offsets.push(last + text.len() as u64);
            }
        }
        Ok(self.offsets.lock().clone())
    }
    /// 读取 EPUB 资源文件的原始字节（用于图片加载）
    pub fn read_resource_bytes(&self, href: &str) -> Option<Vec<u8>> {
        self.epub.lock().read_resource_bytes(href)
    }

    /// 本章第一个 spine manifest idref（OPF `idref`，非包内路径）。
    pub fn primary_spine_href(&self) -> &str {
        self.spine_hrefs.first().map(String::as_str).unwrap_or("")
    }

    pub fn spine_count(&self) -> usize {
        self.spine_hrefs.len()
    }

    /// 读取单个 spine 的原始 HTML（不含 spine 间拼接 `\n`）。
    pub fn read_spine_html(&self, index: usize) -> Result<String, AppError> {
        if index >= self.spine_hrefs.len() {
            return Err(AppError::ChapterExtractError {
                index: index as i32,
                reason: format!("spine index {index} out of range"),
            });
        }
        self.ensure_spine_text(index)?;
        self.spine_htmls[index]
            .get()
            .cloned()
            .ok_or_else(|| AppError::EpubParseError {
                reason: format!("spine HTML not cached at index {index}"),
            })
    }

    /// spine manifest idref → OPF 包内路径（相对路径解析基准）。
    pub fn spine_internal_path(&self, index: usize) -> Option<String> {
        let idref = self.spine_hrefs.get(index)?;
        let epub = self.epub.lock();
        epub.resources()
            .get(idref)
            .map(|item| item.path.to_string_lossy().replace('\\', "/"))
    }

    /// 构建本书 manifest asset 注册表。
    pub fn asset_registry(&self) -> EpubAssetRegistry {
        EpubAssetRegistry::from_epub(&self.epub.lock())
    }
}
impl ChapterContentProvider for EpubContentProvider {
    fn read_text_range(&self, start: u64, end: u64) -> Result<String, AppError> {
        // 先确保偏移覆盖到 end，只转换必要的 spine
        let offsets = self.build_offsets_up_to(end)?;
        let total = *offsets.last().unwrap_or(&0);
        let start = start.min(total);
        let end = end.min(total);

        if start >= end {
            return Ok(String::new());
        }

        // 二分查找与 [start, end) 重叠的 spine 索引范围
        let first_spine = offsets
            .partition_point(|&off| off <= start)
            .saturating_sub(1);
        let last_spine = offsets.partition_point(|&off| off < end);

        let mut result = String::with_capacity((end - start) as usize);
        for (relative_idx, &spine_start) in offsets[first_spine..last_spine].iter().enumerate() {
            let i = first_spine + relative_idx;
            let spine_text = self.ensure_spine_text(i)?;
            let raw_local_start = (start.saturating_sub(spine_start)) as usize;
            let raw_local_end = (end.saturating_sub(spine_start) as usize).min(spine_text.len());
            let local_start = spine_text.ceil_char_boundary(raw_local_start);
            let local_end = spine_text.floor_char_boundary(raw_local_end);
            if local_start < local_end {
                result.push_str(&spine_text[local_start..local_end]);
            }
        }
        Ok(result)
    }

    fn content_length(&self) -> u64 {
        // 使用惰性构建，最多转换 spines 至累积长度 cover u64::MAX
        // 由于 build_offsets_up_to 在 while 循环中检查边界，
        // 调用 u64::MAX 会转换所有 spine（同旧版行为，但惰性逐步进行）
        self.build_offsets_up_to(u64::MAX)
            .map(|offsets| *offsets.last().unwrap_or(&0))
            .unwrap_or(0)
    }

    fn format(&self) -> BookFormat {
        BookFormat::Epub
    }

    fn read_html_range(&self, _start: u64, _end: u64) -> Option<Result<String, AppError>> {
        Some((|| {
            let mut html = String::new();
            for i in 0..self.spine_htmls.len() {
                self.ensure_spine_text(i)?;
                let content =
                    self.spine_htmls[i]
                        .get()
                        .ok_or_else(|| AppError::EpubParseError {
                            reason: "spine HTML not cached".into(),
                        })?;
                html.push_str(content);
                html.push('\n');
            }
            // Trim trailing newline to match read_chapter_content join("\n") behavior
            if html.ends_with('\n') {
                html.pop();
            }
            Ok(html)
        })())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_oversized_single_spine_returns_too_large() {
        use std::io::Write;
        use zip::CompressionMethod;
        use zip::ZipWriter;
        use zip::write::SimpleFileOptions;

        let dir = tempfile::TempDir::new().unwrap();
        let out_path = dir.path().join("large.epub");
        let out_file = std::fs::File::create(&out_path).unwrap();
        let mut out_zip = ZipWriter::new(out_file);

        // ponytail: minimal EPUB from scratch, no fixture dependency
        let stored = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);
        let deflated = SimpleFileOptions::default();

        out_zip.start_file("mimetype", stored).unwrap();
        out_zip.write_all(b"application/epub+zip").unwrap();

        out_zip.start_file("META-INF/container.xml", deflated).unwrap();
        out_zip.write_all(b"<?xml version=\"1.0\"?>\n").unwrap();
        out_zip.write_all(b"<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n").unwrap();
        out_zip.write_all(b"  <rootfiles>\n").unwrap();
        out_zip.write_all(b"    <rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/>\n").unwrap();
        out_zip.write_all(b"  </rootfiles>\n").unwrap();
        out_zip.write_all(b"</container>").unwrap();

        out_zip.start_file("OEBPS/content.opf", deflated).unwrap();
        out_zip.write_all(b"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n").unwrap();
        out_zip.write_all(b"<package xmlns=\"http://www.idpf.org/2007/opf\" unique-identifier=\"book-id\" version=\"2.0\">\n").unwrap();
        out_zip.write_all(b"  <metadata><dc:title xmlns:dc=\"http://purl.org/dc/elements/1.1/\">Test</dc:title></metadata>\n").unwrap();
        out_zip.write_all(b"  <manifest>\n").unwrap();
        out_zip.write_all(b"    <item id=\"ch1\" href=\"chapter1.xhtml\" media-type=\"application/xhtml+xml\"/>\n").unwrap();
        out_zip.write_all(b"  </manifest>\n").unwrap();
        out_zip.write_all(b"  <spine><itemref idref=\"ch1\"/></spine>\n").unwrap();
        out_zip.write_all(b"</package>").unwrap();

        out_zip.start_file("OEBPS/chapter1.xhtml", deflated).unwrap();
        out_zip.write_all(b"<html xmlns=\"http://www.w3.org/1999/xhtml\">").unwrap();
        out_zip.write_all(b"<head><title>Large</title></head><body><p>").unwrap();
        out_zip.write_all("A".repeat(2_100_000).as_bytes()).unwrap();
        out_zip.write_all(b"</p></body></html>").unwrap();
        out_zip.finish().unwrap();

        let path = out_path.to_string_lossy().to_string();
        let result = EpubContentProvider::open_from_bounds(&path, 0, 1);
        assert!(
        result
            .as_ref()
            .is_err_and(|e| matches!(e, AppError::ChapterTooLarge { .. })),
        "expected ChapterTooLarge, got {:?}",
        result.as_ref().err()
    );
    }
}
