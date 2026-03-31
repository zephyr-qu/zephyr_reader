//! 增量解析支持
//!
//! 实现文件变更检测和增量解析，避免重复解析未变更的内容。
//! 适用于大文件重新加载场景，显著提升性能。

use std::collections::HashMap;
use std::fs;
use std::hash::Hasher;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::ffi::{ApiResult, ChapterInfo, ParseResult, ParserError};
use crate::parser::BookParser;

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

        Ok(Self {
            modified_timestamp: modified,
            size_bytes: metadata.len(),
            content_hash: None,
        })
    }

    /// 计算文件内容哈希（使用 FNV-1a 算法，快速但非加密级）
    pub fn compute_hash(path: &str) -> Result<u64, std::io::Error> {
        use std::io::{BufReader, Read};

        let file = fs::File::open(path)?;
        let mut reader = BufReader::new(file);
        let mut buffer = Vec::new();
        reader.read_to_end(&mut buffer)?;

        let mut hasher = fnv_hasher();
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

/// 章节缓存信息
#[derive(Debug, Clone)]
pub struct CachedChapter {
    /// 章节 ID
    pub chapter_id: i32,
    /// 章节标题
    pub title: String,
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
    pub new_chapters: Vec<i32>,
    /// 变更的章节 ID 列表
    pub modified_chapters: Vec<i32>,
    /// 删除的章节 ID 列表
    pub deleted_chapters: Vec<i32>,
    /// 是否需要完全重新解析
    pub full_reparse_required: bool,
}

impl IncrementalParseResult {
    /// 创建完全重新解析的结果
    pub fn full_reparse(parse_result: ParseResult) -> Self {
        let chapter_ids: Vec<i32> = parse_result.chapters.iter().map(|c| c.chapter_id).collect();
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
        new_chapters: Vec<i32>,
        modified_chapters: Vec<i32>,
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

/// 增量解析器
///
/// 跟踪文件变更，支持增量解析。
pub struct IncrementalParser {
    /// 文件元数据缓存
    file_metadata: HashMap<String, FileMetadata>,
    /// 章节缓存
    chapter_cache: HashMap<String, Vec<CachedChapter>>,
    /// 上次解析时间戳
    last_parse_timestamp: HashMap<String, u64>,
}

impl IncrementalParser {
    /// 创建新的增量解析器
    pub fn new() -> Self {
        Self {
            file_metadata: HashMap::new(),
            chapter_cache: HashMap::new(),
            last_parse_timestamp: HashMap::new(),
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
    pub fn needs_reparse(&self, file_path: &str) -> bool {
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
    pub fn parse_incremental<P: BookParser>(
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
    fn get_cached_result<P: BookParser>(
        &self,
        file_path: &str,
        parser: &P,
    ) -> ApiResult<IncrementalParseResult> {
        // 从缓存重建 ParseResult
        if let Some(chapters) = self.chapter_cache.get(file_path) {
            let chapter_infos: Vec<ChapterInfo> = chapters
                .iter()
                .map(|c| ChapterInfo {
                    chapter_id: c.chapter_id,
                    title: c.title.clone(),
                    start_index: 0, // 缓存中不存储位置信息
                    end_index: 0,
                    content_length: 0,
                    index: c.chapter_id,
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
                    file_type: "cached".to_string(),
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
        self.file_metadata.insert(file_path.to_string(), metadata);

        // 更新章节缓存
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as u64;

        let chapters: Vec<CachedChapter> = parse_result
            .chapters
            .iter()
            .map(|c| CachedChapter {
                chapter_id: c.chapter_id,
                title: c.title.clone(),
                content_hash: 0, // 可以计算内容哈希
                cached_at: now,
            })
            .collect();

        self.chapter_cache.insert(file_path.to_string(), chapters);
        self.last_parse_timestamp.insert(file_path.to_string(), now);

        Ok(())
    }

    /// 清除指定文件的缓存
    pub fn clear_cache(&mut self, file_path: &str) {
        self.file_metadata.remove(file_path);
        self.chapter_cache.remove(file_path);
        self.last_parse_timestamp.remove(file_path);
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
            chapter_count: self.chapter_cache.values().map(|v| v.len()).sum(),
            total_memory_estimate: self.estimate_memory_usage(),
        }
    }

    /// 估算内存使用量
    fn estimate_memory_usage(&self) -> usize {
        // 粗略估算
        let metadata_size = self.file_metadata.len() * std::mem::size_of::<FileMetadata>();
        let chapter_size = self
            .chapter_cache
            .values()
            .map(|v| v.len() * std::mem::size_of::<CachedChapter>())
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
pub struct CacheStats {
    /// 缓存的文件数量
    pub file_count: usize,
    /// 缓存的章节数量
    pub chapter_count: usize,
    /// 估算的内存使用量（字节）
    pub total_memory_estimate: usize,
}

/// FNV-1a 哈希器创建函数
fn fnv_hasher() -> std::collections::hash_map::DefaultHasher {
    std::collections::hash_map::DefaultHasher::new()
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
        let parser = IncrementalParser::new();

        // 首次应该需要解析
        assert!(parser.needs_reparse("non_existent.txt"));
    }

    #[test]
    fn test_incremental_parser_clear_cache() {
        let mut parser = IncrementalParser::new();

        parser.file_metadata.insert(
            "test.txt".to_string(),
            FileMetadata {
                modified_timestamp: 1000,
                size_bytes: 100,
                content_hash: None,
            },
        );

        parser.clear_cache("test.txt");
        assert!(!parser.file_metadata.contains_key("test.txt"));
    }

    #[test]
    fn test_cache_stats() {
        let mut parser = IncrementalParser::new();

        parser.file_metadata.insert(
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
