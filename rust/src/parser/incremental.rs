//! 增量解析支持
//!
//! 实现文件变更检测和增量解析，避免重复解析未变更的内容。
//! 适用于大文件重新加载场景，显著提升性能。

use std::fs;
use std::hash::Hasher;
use std::io::{Read, Seek, SeekFrom};
use std::num::NonZeroUsize;
use std::time::{SystemTime, UNIX_EPOCH};

use lru::LruCache;

use flutter_rust_bridge::frb;
use crate::ffi::{ApiResult, ChapterInfo, ParseResult, ParserError};
use crate::parser::BookParser;

/// 默认缓存大小
const DEFAULT_CACHE_SIZE: usize = 100;

/// 文件元数据缓存
#[derive(Debug, Clone)]
pub struct FileMetadata {
    /// 文件最后修改时间（Unix 时间戳，毫秒）
    pub modified_timestamp: u64,
    /// 文件大小（字节）
    pub size_bytes: u64,
    /// 文件内容哈希（可选，用于精确检测）
    pub content_hash: Option<u64>,
}

impl FileMetadata {
    /// 从文件系统读取元数据
    pub fn from_path(path: &str) -> Result<Self, std::io::Error> {
        let metadata = fs::metadata(path)?;
        let modified = metadata
            .modified()?
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let size_bytes = metadata.len();
        let content_hash = if size_bytes > 0 {
            compute_lightweight_hash(path)?
        } else {
            None
        };

        Ok(Self {
            modified_timestamp: modified,
            size_bytes,
            content_hash,
        })
    }

    /// 计算文件内容哈希
    pub fn compute_hash(path: &str) -> Result<u64, std::io::Error> {
        use std::io::BufReader;

        let file = fs::File::open(path)?;
        let mut reader = BufReader::new(file);
        let mut buffer = Vec::new();
        reader.read_to_end(&mut buffer)?;

        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        hasher.write(&buffer);
        Ok(hasher.finish())
    }

    /// 检查文件是否已变更
    pub fn has_changed(&self, current: &FileMetadata) -> bool {
        // 首先检查修改时间
        if self.modified_timestamp != current.modified_timestamp {
            return true;
        }

        // 如果时间相同但大小不同，说明有问题
        if self.size_bytes != current.size_bytes {
            return true;
        }

        // 如果有内容哈希，进行精确比较
        if let (Some(old_hash), Some(new_hash)) = (self.content_hash, current.content_hash) {
            return old_hash != new_hash;
        }

        false
    }
}

/// 计算轻量级内容哈希（仅读文件首尾部分字节）
///
/// 与全量 `compute_hash` 不同，此函数只读取文件头部和尾部各 4KB，
/// 结合文件大小计算哈希，避免大文件全量 I/O，适合快速变更检测。
fn compute_lightweight_hash(path: &str) -> Result<Option<u64>, std::io::Error> {
    let mut file = fs::File::open(path)?;
    let file_size = file.metadata()?.len();
    if file_size == 0 {
        return Ok(None);
    }

    const SAMPLE_SIZE: u64 = 4096;
    let mut hasher = std::collections::hash_map::DefaultHasher::new();

    // 读取头部 4KB（使用 by_ref 避免 take 消耗 file）
    let mut head = Vec::with_capacity(SAMPLE_SIZE as usize);
    file.by_ref().take(SAMPLE_SIZE).read_to_end(&mut head)?;
    hasher.write(&head);
    hasher.write_u64(head.len() as u64);
    hasher.write_u64(file_size);

    // 读取尾部 4KB（如果文件大于 SAMPLE_SIZE）
    if file_size > SAMPLE_SIZE {
        file.seek(SeekFrom::End(-(SAMPLE_SIZE as i64)))?;
        let mut tail = Vec::with_capacity(SAMPLE_SIZE as usize);
        file.by_ref().take(SAMPLE_SIZE).read_to_end(&mut tail)?;
        hasher.write(&tail);
        hasher.write_u64(tail.len() as u64);
    }

    Ok(Some(hasher.finish()))
}

/// 章节缓存信息
#[derive(Debug, Clone)]
pub struct CachedChapter {
    /// 章节索引
    pub chapter_index: i32,
    /// 章节标题
    pub title: String,
    /// 章节起始位置（字节偏移）
    pub start_index: i64,
    /// 章节结束位置（字节偏移）
    pub end_index: i64,
    /// 章节内容长度（字节）
    pub content_length: i64,
    /// 章节内容哈希
    pub content_hash: u64,
    /// 缓存时间戳
    pub cached_at: u64,
}

/// 增量解析结果
#[derive(Debug, Clone)]
pub struct IncrementalParseResult {
    /// 完整解析结果
    pub parse_result: ParseResult,
    /// 新增的章节 ID 列表
    pub new_chapters: Vec<String>,
    /// 变更的章节 ID 列表
    pub modified_chapters: Vec<String>,
    /// 删除的章节 ID 列表
    pub deleted_chapters: Vec<String>,
    /// 是否需要完全重新解析
    pub full_reparse_required: bool,
}

impl IncrementalParseResult {
    /// 创建完全重新解析的结果
    pub fn full_reparse(parse_result: ParseResult) -> Self {
        let chapter_ids: Vec<String> = parse_result
            .chapters
            .iter()
            .map(|c| c.chapter_id.clone())
            .collect();
        Self {
            parse_result,
            new_chapters: chapter_ids.clone(),
            modified_chapters: Vec::new(),
            deleted_chapters: Vec::new(),
            full_reparse_required: true,
        }
    }

    /// 创建增量解析结果
    pub fn incremental(
        parse_result: ParseResult,
        new_chapters: Vec<String>,
        modified_chapters: Vec<String>,
    ) -> Self {
        Self {
            parse_result,
            new_chapters,
            modified_chapters,
            deleted_chapters: Vec::new(),
            full_reparse_required: false,
        }
    }
}

/// 缓存的文件数据（包含文件类型和章节列表）
#[derive(Debug, Clone)]
struct CachedFileData {
    file_type: String,
    chapters: Vec<CachedChapter>,
}

/// 增量解析器
///
/// 跟踪文件变更，支持增量解析。
pub struct IncrementalParser {
    /// 文件元数据缓存（使用 LRU 淘汰策略）
    file_metadata: LruCache<String, FileMetadata>,
    /// 章节缓存（使用 LRU 淘汰策略，包含文件类型信息）
    chapter_cache: LruCache<String, CachedFileData>,
    /// 上次解析时间戳
    last_parse_timestamp: LruCache<String, u64>,
}

impl IncrementalParser {
    /// 创建新的增量解析器
    pub fn new() -> Self {
        let cache_size = NonZeroUsize::new(DEFAULT_CACHE_SIZE)
            .expect("DEFAULT_CACHE_SIZE is 100, which is always non-zero");
        Self {
            file_metadata: LruCache::new(cache_size),
            chapter_cache: LruCache::new(cache_size),
            last_parse_timestamp: LruCache::new(cache_size),
        }
    }

    /// 检查文件是否需要重新解析
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    ///
    /// # 返回值
    ///
    /// * `true` - 文件已变更，需要重新解析
    /// * `false` - 文件未变更，可使用缓存
    pub fn needs_reparse(&mut self, file_path: &str) -> bool {
        // 检查是否有缓存的元数据
        if let Some(cached) = self.file_metadata.get(file_path) {
            match FileMetadata::from_path(file_path) {
                Ok(current) => cached.has_changed(&current),
                Err(_) => true, // 无法读取当前元数据，需要重新解析
            }
        } else {
            true // 没有缓存，需要解析
        }
    }

    /// 增量解析文件
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    /// * `parser` - 解析器实例
    ///
    /// # 返回值
    ///
    /// * `Ok(IncrementalParseResult)` - 解析成功
    /// * `Err(ParserError)` - 解析失败
    pub fn parse_incremental<P: BookParser + ?Sized>(
        &mut self,
        file_path: &str,
        parser: &P,
    ) -> ApiResult<IncrementalParseResult> {
        let current_metadata = FileMetadata::from_path(file_path).map_err(|e| {
            ParserError::file_read_error(file_path, format!("读取文件元数据失败：{}", e))
        })?;

        // 检查是否需要完全重新解析
        if let Some(cached_metadata) = self.file_metadata.get(file_path) {
            if !cached_metadata.has_changed(&current_metadata) {
                // 文件未变更，返回缓存结果
                tracing::debug!("文件未变更，使用缓存：{}", file_path);
                return self.get_cached_result(file_path, parser);
            }
        }

        // 完全重新解析
        tracing::info!("文件已变更或首次解析：{}", file_path);
        let parse_result = parser.parse(file_path)?;

        // 更新缓存
        self.update_cache(file_path, current_metadata, &parse_result)?;

        Ok(IncrementalParseResult::full_reparse(parse_result))
    }

    /// 获取缓存的解析结果
    fn get_cached_result<P: BookParser + ?Sized>(
        &mut self,
        file_path: &str,
        parser: &P,
    ) -> ApiResult<IncrementalParseResult> {
        // 从缓存重建 ParseResult
        if let Some(cached_data) = self.chapter_cache.get(file_path) {
            let chapter_infos: Vec<ChapterInfo> = cached_data
                .chapters
                .iter()
                .map(|c| {
                    // 使用稳定的章节 ID：基于文件路径和章节索引生成
                    // 确保同一章节在多次解析中 ID 一致
                    let stable_id = format!("{}:chapter_{}", file_path, c.chapter_index);
                    let chapter_id = format!("{:x}", md5::compute(&stable_id));

                    ChapterInfo {
                        chapter_id,
                        title: c.title.clone(),
                        start_index: c.start_index, // 使用缓存的位置信息
                        end_index: c.end_index,     // 使用缓存的位置信息
                        content_length: c.content_length, // 使用缓存的内容长度
                        index: c.chapter_index,
                        level: 0,
                    }
                })
                .collect();

            // 需要重新获取书籍信息
            let metadata = parser.extract_metadata(file_path)?;

            let parse_result = ParseResult {
                book_info: crate::ffi::BookInfo {
                    book_id: format!("cached_{}", file_path),
                    title: metadata.title,
                    author: metadata.author,
                    chapter_count: metadata.chapter_count,
                    total_characters: metadata.total_characters,
                    file_path: file_path.to_string(),
                    file_type: cached_data.file_type.clone(),
                    cover_path: metadata.cover_path,
                },
                chapters: chapter_infos,
            };

            return Ok(IncrementalParseResult {
                parse_result,
                new_chapters: Vec::new(),
                modified_chapters: Vec::new(),
                deleted_chapters: Vec::new(),
                full_reparse_required: false,
            });
        }

        // 缓存未命中，需要重新解析
        Err(ParserError::Other("缓存未命中，需要重新解析".to_string()))
    }

    /// 更新缓存
    fn update_cache(
        &mut self,
        file_path: &str,
        metadata: FileMetadata,
        parse_result: &ParseResult,
    ) -> Result<(), ParserError> {
        // 更新文件元数据
        self.file_metadata.put(file_path.to_string(), metadata);

        // 更新章节缓存
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let chapters: Vec<CachedChapter> = parse_result
            .chapters
            .iter()
            .map(|c| {
                let mut hasher = std::collections::hash_map::DefaultHasher::new();
                hasher.write(c.title.as_bytes());
                hasher.write(&c.start_index.to_le_bytes());
                hasher.write(&c.end_index.to_le_bytes());
                hasher.write(&c.content_length.to_le_bytes());
                let content_hash = hasher.finish();

                CachedChapter {
                    chapter_index: c.index,
                    title: c.title.clone(),
                    start_index: c.start_index,
                    end_index: c.end_index,
                    content_length: c.content_length,
                    content_hash,
                    cached_at: now,
                }
            })
            .collect();

        let cached_data = CachedFileData {
            file_type: parse_result.book_info.file_type.clone(),
            chapters,
        };

        self.chapter_cache.put(file_path.to_string(), cached_data);
        self.last_parse_timestamp.put(file_path.to_string(), now);

        Ok(())
    }

    /// 清除指定文件的缓存
    pub fn clear_cache(&mut self, file_path: &str) {
        self.file_metadata.pop(file_path);
        self.chapter_cache.pop(file_path);
        self.last_parse_timestamp.pop(file_path);
        tracing::debug!("缓存已清除：{}", file_path);
    }

    /// 清除所有缓存
    pub fn clear_all(&mut self) {
        self.file_metadata.clear();
        self.chapter_cache.clear();
        self.last_parse_timestamp.clear();
        tracing::info!("所有缓存已清除");
    }

    /// 获取缓存统计信息
    pub fn get_cache_stats(&self) -> CacheStats {
        CacheStats {
            file_count: self.file_metadata.len(),
            chapter_count: self.chapter_cache.iter().map(|(_, v)| v.chapters.len()).sum(),
            total_memory_estimate: self.estimate_memory_usage(),
        }
    }

    /// 估算内存使用量
    fn estimate_memory_usage(&self) -> usize {
        // 粗略估算
        let metadata_size = self.file_metadata.len() * std::mem::size_of::<FileMetadata>();
        let chapter_size = self
            .chapter_cache
            .iter()
            .map(|(_, v)| v.chapters.len() * std::mem::size_of::<CachedChapter>())
            .sum::<usize>();
        metadata_size + chapter_size
    }
}

impl Default for IncrementalParser {
    fn default() -> Self {
        Self::new()
    }
}

/// 缓存统计信息
#[derive(Debug, Clone)]
#[frb(non_opaque)]
pub struct CacheStats {
    /// 缓存的文件数量
    pub file_count: usize,
    /// 缓存的章节数量
    pub chapter_count: usize,
    /// 估算的内存使用量（字节）
    pub total_memory_estimate: usize,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_file_metadata_from_path() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        fs::write(&file_path, "test content").unwrap();

        let metadata = FileMetadata::from_path(file_path.to_str().unwrap()).unwrap();
        assert!(metadata.size_bytes > 0);
        assert!(metadata.modified_timestamp > 0);
    }

    #[test]
    fn test_file_metadata_has_changed() {
        let old_metadata = FileMetadata {
            modified_timestamp: 1000,
            size_bytes: 100,
            content_hash: Some(12345),
        };

        let same_metadata = FileMetadata {
            modified_timestamp: 1000,
            size_bytes: 100,
            content_hash: Some(12345),
        };

        let different_metadata = FileMetadata {
            modified_timestamp: 2000,
            size_bytes: 100,
            content_hash: Some(12345),
        };

        assert!(!old_metadata.has_changed(&same_metadata));
        assert!(old_metadata.has_changed(&different_metadata));
    }

    #[test]
    fn test_incremental_parser_needs_reparse() {
        let mut parser = IncrementalParser::new();

        // 首次应该需要解析
        assert!(parser.needs_reparse("non_existent.txt"));
    }

    #[test]
    fn test_incremental_parser_clear_cache() {
        let mut parser = IncrementalParser::new();

        parser.file_metadata.put(
            "test.txt".to_string(),
            FileMetadata {
                modified_timestamp: 1000,
                size_bytes: 100,
                content_hash: None,
            },
        );

        parser.clear_cache("test.txt");
        assert!(!parser.file_metadata.contains(&"test.txt".to_string()));
    }

    #[test]
    fn test_cache_stats() {
        let mut parser = IncrementalParser::new();

        parser.file_metadata.put(
            "test.txt".to_string(),
            FileMetadata {
                modified_timestamp: 1000,
                size_bytes: 100,
                content_hash: None,
            },
        );

        let stats = parser.get_cache_stats();
        assert_eq!(stats.file_count, 1);
    }
}
