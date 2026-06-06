use parking_lot::Mutex;
use std::num::NonZeroUsize;
use std::sync::{Arc, LazyLock};

pub(crate) use crate::domain::{AppError, TypesetConfig};
use crate::domain::{PageContent, ParseResult};
use crate::parser::book_parser::BookMetadata;
use crate::parser::pdf::provider::PdfContentProvider;
use crate::parser::provider::{ChapterContentProvider, PageData, PagedContentProvider};
use crate::parser::registry::parser_for_file;
use crate::storage::models::{BookFormat, LayoutCache, LayoutCacheKey};
use crate::storage::repos::{BookRepository, ChapterRepository, LayoutCacheRepository};
use crate::storage::storage_pool;
pub use crate::text::PageStreamer;
use crate::text::paginate_all;
use crate::utils::security::validate_file_path_async;
use flutter_rust_bridge::frb;
use lru::LruCache;

/// 章节内容枚举
#[derive(Debug, Clone)]
#[frb(dart_metadata=("freezed"))]
pub enum ChapterContent {
    Raw(String),
    Pages(Vec<PageContent>),
}

/// 构造 Pages 变体，当页数 > 100 时记录警告（防止偶发大章节 FFI 序列化瓶颈）
fn chapter_content_pages(pages: Vec<PageContent>) -> ChapterContent {
    if pages.len() > 100 {
        tracing::warn!(
            "ChapterContent::Pages has {} pages (>100), potential FFI serialization bottleneck",
            pages.len()
        );
    }
    ChapterContent::Pages(pages)
}

const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;
const PAGINATION_CHUNK_SIZE: u64 = 8192;
const PROVIDER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

// ==================== Provider LRU 缓存 ====================

type CacheKey = (String, i32);

static PROVIDER_CACHE: LazyLock<Mutex<LruCache<CacheKey, Arc<dyn ChapterContentProvider>>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(PROVIDER_CACHE_CAPACITY)));

// ==================== 格式检测 ====================

#[frb]
pub async fn get_supported_formats() -> Result<Vec<String>, AppError> {
    let formats: &[&str] = &[
        "txt", "text", "epub", "pdf", "md", "markdown", "mdown", "mkdn",
    ];
    Ok(formats.iter().map(|s| s.to_string()).collect())
}
#[frb(sync)]
pub fn supports_format(format: &str) -> bool {
    matches!(
        format.to_lowercase().as_str(),
        "txt" | "text" | "epub" | "pdf" | "md" | "markdown" | "mdown" | "mkdn"
    )
}

// ==================== 导入与解析 ====================

#[frb]
pub async fn parse_book(file_path: String) -> Result<ParseResult, AppError> {
    tracing::info!("[parse_book] start: file_path={}", file_path);
    let validated_path = validate_file_path_async(&file_path).await?;
    tracing::debug!(
        "[parse_book] path validated: validated_path={}",
        validated_path
    );

    let metadata = tokio::fs::metadata(&validated_path)
        .await
        .map_err(|e| AppError::file_read_error(&validated_path, e.to_string()))?;
    tracing::debug!("[parse_book] file size: {} bytes", metadata.len());
    if metadata.len() > MAX_FILE_SIZE {
        tracing::warn!(
            "[parse_book] file size exceeded: {} > {} bytes",
            metadata.len(),
            MAX_FILE_SIZE
        );
        return Err(AppError::security_error(
            format!(
                "file size exceeds limit (max {} MB)",
                MAX_FILE_SIZE / 1024 / 1024
            ),
            &validated_path,
        ));
    }

    let extension = std::path::Path::new(&validated_path)
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("unknown")
        .to_string();
    tracing::info!(
        "[parse_book] parsing: extension={}, path={}",
        extension,
        validated_path
    );
    let parser = parser_for_file(&validated_path)?;
    let result = parser.parse(&validated_path).await?;
    tracing::info!(
        "[parse_book] parse complete: title={}, chapters={}, total_chars={}",
        result.book_info.title,
        result.chapters.len(),
        result.book_info.total_characters
    );
    let pool = storage_pool()?;
    BookRepository::save(&pool, &result.book_info).await?;
    BookRepository::save_metadata(&pool, &result.book_info).await?;
    ChapterRepository::save(&pool, &result.book_info.book_id, &result.chapters).await?;
    Ok(result)
}

#[frb]
pub async fn extract_metadata(file_path: String) -> Result<BookMetadata, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;

    if let Some(storage) = crate::storage::storage() {
        let Ok(pool) = storage.pool() else {
            return Err(AppError::database_error("Storage pool unavailable"));
        };
        if let Ok(Some(book)) = BookRepository::find_by_file_path(&pool, &validated_path).await {
            if let Ok(metadata) = tokio::fs::metadata(&validated_path).await {
                let size_match = book.file_size == metadata.len() as i64;
                let mtime_match = book
                    .file_mtime
                    .and_then(|stored| {
                        metadata.modified().ok().and_then(|m| {
                            m.duration_since(std::time::UNIX_EPOCH)
                                .ok()
                                .map(|d| (d.as_secs() as i64) == stored)
                        })
                    })
                    .unwrap_or(false);
                if size_match && mtime_match {
                    return Ok(BookMetadata {
                        title: book.title,
                        author: book.author.unwrap_or_default(),
                        description: None,
                        cover_path: None,
                        publisher: book.publisher,
                        translator: book.translator,
                        isbn: book.isbn,
                        publish_year: None,
                        language: None,
                        chapter_count: book.chapter_count,
                        total_characters: book.total_characters,
                    });
                }
            }
        }
    }

    let parser = parser_for_file(&validated_path)?;
    parser.extract_metadata(&validated_path).await
}

// ==================== 章节内容 ====================

async fn try_read_cached_chapter(validated_path: &str, chapter_index: i32) -> Option<String> {
    let storage = crate::storage::storage()?;
    let pool = storage.pool().ok()?;

    let book = BookRepository::find_by_file_path(&pool, validated_path)
        .await
        .ok()??;

    let chapter_path = storage
        .data_dir()
        .join("chapters")
        .join(&book.book_id)
        .join(format!("{}.txt", chapter_index));

    tokio::fs::read_to_string(&chapter_path).await.ok()
}

async fn write_chapter_cache(validated_path: &str, chapter_index: i32, content: &str) {
    let storage = match crate::storage::storage() {
        Some(s) => s,
        None => return,
    };
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(_) => return,
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        _ => return,
    };
    let chapter_path = storage
        .data_dir()
        .join("chapters")
        .join(&book.book_id)
        .join(format!("{}.txt", chapter_index));
    if let Some(parent) = chapter_path.parent() {
        if let Err(e) = tokio::fs::create_dir_all(parent).await {
            tracing::warn!("failed to create chapter cache directory: {}", e);
        }
    }
    if let Err(e) = tokio::fs::write(&chapter_path, content).await {
        tracing::warn!("failed to write chapter cache: {}", e);
    }
}

async fn extract_chapter_content(file_path: &str, chapter_index: i32) -> Result<String, AppError> {
    if let Some(cached) = try_read_cached_chapter(file_path, chapter_index).await {
        return Ok(cached);
    }

    let parser = parser_for_file(file_path)?;
    let text = parser.extract_chapter(file_path, chapter_index).await?;

    write_chapter_cache(file_path, chapter_index, &text).await;

    Ok(text.to_owned())
}

// ==================== 排版缓存 ====================

/// 尝试从排版缓存获取分页结果
async fn try_get_cached_pages(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
) -> Option<Vec<PageContent>> {
    let storage = crate::storage::storage()?;
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("layout cache miss: pool unavailable: {e}");
            return None;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return None,
        Err(e) => {
            tracing::warn!("layout cache miss: book lookup failed: {e}");
            return None;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id.clone(),
        chapter_index,
        chunk_index: None,
        config_hash,
    };
    let kv = storage.kv();
    let cache_repo = LayoutCacheRepository::new(kv);
    match cache_repo.get_layout_cache(&cache_key) {
        Ok(Some(cache)) => {
            tracing::debug!("layout cache HIT: {}", cache_key);
            Some(cache.pages)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("layout cache read failed: {}", e);
            None
        }
    }
}

/// 保存排版结果到缓存（写入失败不影响阅读）
async fn try_save_cached_pages(
    validated_path: &str,
    chapter_index: i32,
    config_hash: u64,
    pages: Vec<PageContent>,
) {
    let storage = match crate::storage::storage() {
        Some(s) => s,
        None => return,
    };
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("layout cache save skipped: pool unavailable: {e}");
            return;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return,
        Err(e) => {
            tracing::warn!("layout cache save skipped: book lookup failed: {e}");
            return;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id,
        chapter_index,
        chunk_index: None,
        config_hash,
    };
    let cache = LayoutCache::new(config_hash, pages);
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_layout_cache(&cache_key, &cache) {
        tracing::warn!("layout cache save failed: {}", e);
    }
}

// ==================== Chunk 级排版缓存 ====================

/// 尝试从 chunk 缓存获取分页结果
async fn try_get_cached_chunk(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: u32,
    config_hash: u64,
) -> Option<Vec<PageContent>> {
    let storage = crate::storage::storage()?;
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("chunk cache miss: pool unavailable: {e}");
            return None;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return None,
        Err(e) => {
            tracing::warn!("chunk cache miss: book lookup failed: {e}");
            return None;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id.clone(),
        chapter_index,
        chunk_index: Some(chunk_index),
        config_hash,
    };
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    match cache_repo.get_layout_cache(&cache_key) {
        Ok(Some(cache)) => {
            tracing::debug!("chunk cache HIT: {}", cache_key);
            Some(cache.pages)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("chunk cache read failed: {}", e);
            None
        }
    }
}

/// 保存 chunk 排版结果到缓存（写入失败不影响阅读）
async fn try_save_cached_chunk(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: u32,
    config_hash: u64,
    pages: Vec<PageContent>,
) {
    let storage = match crate::storage::storage() {
        Some(s) => s,
        None => return,
    };
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("chunk cache save skipped: pool unavailable: {e}");
            return;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return,
        Err(e) => {
            tracing::warn!("chunk cache save skipped: book lookup failed: {e}");
            return;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id,
        chapter_index,
        chunk_index: Some(chunk_index),
        config_hash,
    };
    let cache = LayoutCache::new(config_hash, pages);
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_layout_cache(&cache_key, &cache) {
        tracing::warn!("chunk cache save failed: {}", e);
    }
}

/// 从 LRU 缓存获取或创建 Provider
async fn get_or_create_provider(
    validated_path: &str,
    chapter_index: i32,
    format: &BookFormat,
) -> Result<Arc<dyn ChapterContentProvider>, AppError> {
    let cache_key = (validated_path.to_string(), chapter_index);
    {
        let mut cache = PROVIDER_CACHE.lock();
        if let Some(cached) = cache.get(&cache_key) {
            return Ok(cached.clone());
        }
    }

    let p: Arc<dyn ChapterContentProvider> = match format {
        BookFormat::Txt => {
            let path = validated_path.to_string();
            let provider = tokio::task::spawn_blocking(move || {
                crate::parser::txt::TxtContentProvider::open(&path)
            })
            .await
            .map_err(|e| AppError::task_panic("txt provider", e.to_string()))??;
            Arc::new(provider)
        }
        BookFormat::Epub => {
            let path = validated_path.to_string();
            let provider = tokio::task::spawn_blocking(move || {
                crate::parser::epub::provider::EpubContentProvider::open(&path, chapter_index)
            })
            .await
            .map_err(|e| AppError::task_panic("epub provider", e.to_string()))??;
            Arc::new(provider)
        }
        BookFormat::Md => {
            let content = tokio::fs::read_to_string(validated_path)
                .await
                .map_err(|e| AppError::file_read_error(validated_path, e.to_string()))?;
            Arc::new(crate::parser::md::MdContentProvider::new(content))
        }
        BookFormat::Pdf => {
            return Err(AppError::invalid_input(
                "PDF does not support range-based text access",
            ));
        }
    };

    let mut cache = PROVIDER_CACHE.lock();
    if !cache.contains(&cache_key) {
        cache.put(cache_key, p.clone());
    }
    Ok(p)
}

#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
    config: Option<TypesetConfig>,
) -> Result<ChapterContent, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    let format = format_from_extension(&validated_path);

    // 支持分块格式走 Provider 路径
    if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();

        let (start, end) = if format == BookFormat::Epub {
            (0u64, content_len)
        } else {
            let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
        };

        let text = provider.read_text_range(start, end)?;

        match config {
            Some(cfg) => {
                let cfg = cfg.validate_and_fix();
                let config_hash = cfg.config_hash();

                // 查缓存
                if let Some(pages) =
                    try_get_cached_pages(&validated_path, chapter_index, config_hash).await
                {
                    return Ok(chapter_content_pages(pages));
                }

                let chapter_idx = chapter_index;
                let pages =
                    tokio::task::spawn_blocking(move || paginate_all(text, chapter_idx, cfg))
                        .await
                        .map_err(|e| AppError::task_panic("pagination", e.to_string()))?;

                // 写缓存
                try_save_cached_pages(&validated_path, chapter_index, config_hash, pages.clone())
                    .await;

                Ok(chapter_content_pages(pages))
            }
            None => Ok(ChapterContent::Raw(text)),
        }
    } else {
        // 旧路径（PDF 等格式的 fallback）
        let text = extract_chapter_content(&validated_path, chapter_index).await?;
        match config {
            Some(cfg) => {
                let cfg = cfg.validate_and_fix();
                let config_hash = cfg.config_hash();

                // 查缓存
                if let Some(pages) =
                    try_get_cached_pages(&validated_path, chapter_index, config_hash).await
                {
                    return Ok(chapter_content_pages(pages));
                }

                let pages = paginate_all(text, chapter_index, cfg);

                // 写缓存
                try_save_cached_pages(&validated_path, chapter_index, config_hash, pages.clone())
                    .await;

                Ok(chapter_content_pages(pages))
            }
            None => Ok(ChapterContent::Raw(text)),
        }
    }
}

#[frb]
pub async fn create_page_streamer(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<PageStreamer, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    let content = extract_chapter_content(&validated_path, chapter_index).await?;
    let config = config.validate_and_fix();
    Ok(PageStreamer::new(content, config))
}

#[frb]
pub async fn paginate_all_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<PageContent>, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();

    // 查缓存
    if let Some(pages) = try_get_cached_pages(&validated_path, chapter_index, config_hash).await {
        return Ok(pages);
    }

    let content = extract_chapter_content(&validated_path, chapter_index).await?;
    let pages = paginate_all(content, chapter_index, config);

    // 写缓存
    try_save_cached_pages(&validated_path, chapter_index, config_hash, pages.clone()).await;

    Ok(pages)
}

// ==================== Provider 管理 ====================

/// 从文件路径推断格式
fn format_from_extension(file_path: &str) -> BookFormat {
    let ext = std::path::Path::new(file_path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");
    match ext {
        "txt" | "text" => BookFormat::Txt,
        "epub" => BookFormat::Epub,
        "md" | "markdown" | "mdown" | "mkdn" => BookFormat::Md,
        "pdf" => BookFormat::Pdf,
        _ => BookFormat::Txt,
    }
}

/// 从 DB 获取章节边界信息（TXT/MD 的文件字节偏移，EPUB/PDF 的 spine/页索引）
async fn get_chapter_bounds(
    validated_path: &str,
    chapter_index: i32,
) -> Result<(i32, i32), AppError> {
    let pool = storage_pool()?;
    let book = BookRepository::find_by_file_path(&pool, validated_path)
        .await?
        .ok_or_else(|| AppError::file_not_found(validated_path))?;

    let chapter = ChapterRepository::find_by_index(&pool, &book.book_id, chapter_index)
        .await?
        .ok_or_else(|| AppError::chapter_extract_error(chapter_index, "chapter not found in DB"))?;

    Ok((chapter.start_index  as i32, chapter.end_index  as i32))
}

/// 轻量分块排版：将文本按行分割为多页
fn paginate_chunk(
    text: &str,
    chunk_start_offset: u64,
    chapter_index: i32,
    config: &TypesetConfig,
) -> Vec<PageContent> {
    let lines: Vec<&str> = text.lines().collect();
    if lines.is_empty() {
        return Vec::new();
    }

    let font_size = config.font_size as f32;
    let line_spacing = config.line_spacing;
    let page_height_px = config.page_height as f32;
    let line_height = (font_size * line_spacing).max(1.0);
    let lines_per_page = ((page_height_px / line_height) as usize).max(5);

    let mut pages = Vec::new();
    let mut acc_offset = chunk_start_offset;

    for (page_idx, chunk) in lines.chunks(lines_per_page).enumerate() {
        let page_text = chunk.join("\n");
        let page_len = page_text.len() as u64;
        pages.push(PageContent {
            chapter_index,
            page_index: page_idx as i32,
            content: page_text,
            is_last_page: false,
            start_offset: acc_offset as i32,
            end_offset: (acc_offset + page_len) as i32,
        });
        acc_offset += page_len;
    }

    pages
}

// ==================== 新版分块排版 API ====================

/// 获取分块排版内容
///
/// 按 chunk 粒度读取章节内容并排版，适用于 TXT/MD/EPUB 格式。
/// PDF 格式应使用 `get_pdf_page` / `get_pdf_total_pages`。
///
/// 偏移语义因格式而异：
/// - TXT/MD：章节字节偏移（相对于文件的 start_index/end_index）
/// - EPUB：0-based 纯文本偏移
#[frb]
pub async fn get_paginated_chunk(
    file_path: String,
    chapter_index: i32,
    chunk_index: u32,
    config: TypesetConfig,
) -> Result<Vec<PageContent>, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let format = format_from_extension(&validated_path);

    if format == BookFormat::Pdf {
        return Err(AppError::invalid_input(
            "PDF does not support chunked text access, use get_pdf_page instead",
        ));
    }

    // 查 chunk 缓存
    if let Some(pages) =
        try_get_cached_chunk(&validated_path, chapter_index, chunk_index, config_hash).await
    {
        return Ok(pages);
    }

    let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
    let content_len = provider.content_length();

    // 计算偏移范围
    // EPUB：0-based，TXT/MD：文件字节偏移 + chunk 偏移
    let (range_start, range_end) = if format == BookFormat::Epub {
        let s = chunk_index as u64 * PAGINATION_CHUNK_SIZE;
        let e = (s + PAGINATION_CHUNK_SIZE).min(content_len);
        (s, e)
    } else {
        let (chapter_start, chapter_end) =
            get_chapter_bounds(&validated_path, chapter_index).await?;
        let chapter_start = chapter_start.max(0) as u64;
        let chapter_end = (chapter_end.max(0) as u64).min(content_len);

        let s = chapter_start + chunk_index as u64 * PAGINATION_CHUNK_SIZE;
        let e = (s + PAGINATION_CHUNK_SIZE).min(chapter_end);
        (s, e)
    };

    if range_start >= range_end || range_start >= content_len {
        return Ok(Vec::new());
    }

    let text = provider.read_text_range(range_start, range_end)?;
    if text.is_empty() {
        return Ok(Vec::new());
    }

    let pages = paginate_chunk(&text, range_start, chapter_index, &config);

    // 写 chunk 缓存
    try_save_cached_chunk(
        &validated_path,
        chapter_index,
        chunk_index,
        config_hash,
        pages.clone(),
    )
    .await;

    let mut pages = pages;
    if let Some(last) = pages.last_mut() {
        last.is_last_page = range_end >= content_len;
    }

    Ok(pages)
}

/// 获取 PDF 指定页面的文本内容
///
/// PDF 不走分块排版路径，直接返回单页文本。
/// Flutter 端直接渲染，无需经过排版引擎。
#[frb]
pub async fn get_pdf_page(file_path: String, page_index: u32) -> Result<PageData, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    tokio::task::spawn_blocking(move || {
        let provider = PdfContentProvider::open(&validated_path)?;
        provider.get_page(page_index)
    })
    .await
    .map_err(|e| AppError::task_panic("pdf page", e.to_string()))?
}

/// 获取 PDF 总页数
#[frb]
pub async fn get_pdf_total_pages(file_path: String) -> Result<u32, AppError> {
    let validated_path = validate_file_path_async(&file_path).await?;
    tokio::task::spawn_blocking(move || {
        let provider = crate::parser::pdf::provider::PdfContentProvider::open(&validated_path)?;
        Ok(provider.total_pages())
    })
    .await
    .map_err(|e| AppError::task_panic("pdf total pages", e.to_string()))?
}

/// 检查格式是否已实现分块排版 Provider
#[frb(sync)]
pub fn supports_chunked_pagination(file_path: String) -> bool {
    let format = format_from_extension(&file_path);
    matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_supported_formats() {
        let _formats = get_supported_formats();
        // assert!(!formats);
    }

    #[test]
    fn test_supports_format() {
        assert!(supports_format("txt") || supports_format("epub") || supports_format("pdf"));
        assert!(!supports_format("unknown"));
    }

    #[test]
    fn test_format_from_extension() {
        assert_eq!(format_from_extension("book.txt"), BookFormat::Txt);
        assert_eq!(format_from_extension("book.epub"), BookFormat::Epub);
        assert_eq!(format_from_extension("book.md"), BookFormat::Md);
        assert_eq!(format_from_extension("book.pdf"), BookFormat::Pdf);
        assert_eq!(format_from_extension("book.markdown"), BookFormat::Md);
    }

    #[test]
    fn test_supports_chunked_pagination() {
        assert!(supports_chunked_pagination("book.txt".to_string()));
        assert!(supports_chunked_pagination("book.epub".to_string()));
        assert!(supports_chunked_pagination("book.md".to_string()));
        assert!(!supports_chunked_pagination("book.pdf".to_string()));
    }

    #[test]
    fn test_paginate_chunk_empty() {
        let config = TypesetConfig::default();
        let pages = paginate_chunk("", 0, 0, &config);
        assert!(pages.is_empty());
    }

    #[test]
    fn test_paginate_chunk_single_line() {
        let config = TypesetConfig {
            font_size: 100,
            page_height: 1000,
            line_spacing: 1.0,
            ..Default::default()
        };
        let pages = paginate_chunk("Hello World", 0, 0, &config);
        assert_eq!(pages.len(), 1);
        assert_eq!(pages[0].content, "Hello World");
    }

    #[test]
    fn test_paginate_chunk_offset_tracking() {
        let config = TypesetConfig {
            font_size: 100,
            page_height: 100,
            line_spacing: 1.0,
            ..Default::default()
        };
        let text = "Line1\nLine2\nLine3\nLine4";
        let pages = paginate_chunk(text, 100, 0, &config);
        assert!(pages.len() >= 1);
        assert!(pages[0].start_offset >= 100);
    }
}
