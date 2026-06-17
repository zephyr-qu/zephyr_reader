use parking_lot::Mutex;
use std::collections::HashMap;
use std::num::NonZeroUsize;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, LazyLock};

pub(crate) use crate::domain::{AppError, TypesetConfig};
use crate::domain::{PageContent, PaginateResult};
use crate::parser::pdf::provider::PdfContentProvider;
use crate::parser::provider::{ChapterContentProvider, PageData, PagedContentProvider};
use crate::parser::registry::parser_for_file;
use crate::storage::models::{BookFormat, LayoutCache, LayoutCacheKey};
use crate::storage::repos::{BookRepository, ChapterRepository, LayoutCacheRepository};
use crate::storage::storage_pool;
pub use crate::text::PageStreamer;
use crate::text::paginate_all;
use crate::utils::security::validate_file_path;
use flutter_rust_bridge::frb;
use lru::LruCache;

/// 章节内容枚举
#[derive(Debug, Clone)]
#[frb(dart_metadata=("freezed"))]
pub enum ChapterContent {
    Raw(String),
    Pages(Vec<PageContent>),
}

/// 首段 spine 快速提取结果
#[derive(Debug, Clone)]
#[frb]
pub struct FirstSpineResult {
    /// 首个 spine 的前 2000 字符纯文本
    pub text: String,
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
const PROVIDER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

// ==================== Provider LRU 缓存 ====================

type CacheKey = (String, i32);

static PROVIDER_CACHE: LazyLock<Mutex<LruCache<CacheKey, Arc<dyn ChapterContentProvider>>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(PROVIDER_CACHE_CAPACITY)));

// ==================== PageStreamer LRU 缓存 ====================

type StreamerKey = (String, i32, u64);

const STREAMER_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(4) {
    Some(v) => v,
    None => unreachable!(),
};

static STREAMER_CACHE: LazyLock<Mutex<LruCache<StreamerKey, PageStreamer>>> =
    LazyLock::new(|| Mutex::new(LruCache::new(STREAMER_CACHE_CAPACITY)));

// ==================== Pagination Session ====================

/// Handle to a server-side pagination session (file/chapter/config binding).
#[derive(Debug, Clone)]
#[frb]
pub struct PaginationSessionHandle {
    pub session_id: u64,
}

#[derive(Clone)]
struct PaginationSessionEntry {
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    streamer: PageStreamer,
}

static NEXT_SESSION_ID: AtomicU64 = AtomicU64::new(1);

static SESSION_MAP: LazyLock<Mutex<HashMap<u64, PaginationSessionEntry>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn allocate_session_id() -> u64 {
    NEXT_SESSION_ID.fetch_add(1, Ordering::Relaxed)
}

fn lookup_pagination_session(session_id: u64) -> Result<PaginationSessionEntry, AppError> {
    SESSION_MAP
        .lock()
        .get(&session_id)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("pagination session {session_id}"),
        })
}

// ==================== Book ID 路径缓存 ====================

/// 文件路径 → book_id 的 LRU 缓存，避免重复 DB 查询。
/// 每本书的文件路径 → book_id 在单次会话中不变，无需失效处理。
const BOOK_ID_CACHE_CAPACITY: NonZeroUsize = match NonZeroUsize::new(16) {
    Some(v) => v,
    None => unreachable!(),
};

type BookIdCache = LruCache<String, String>;  // file_path → book_id

static BOOK_ID_CACHE: LazyLock<Mutex<BookIdCache>> =
    LazyLock::new(|| Mutex::new(LruCache::new(BOOK_ID_CACHE_CAPACITY)));

// ==================== 导入与解析 ====================

/// 解析书籍文件：验证路径、检查大小限制、选择解析器、保存元数据。
///
/// 完整的导入流程，包括文件校验（大小、安全路径）、格式检测、内容解析
/// 以及将书籍信息和章节写入数据库。
pub async fn parse_book(file_path: String) -> Result<String, AppError> {
    tracing::info!("[parse_book] start: file_path={}", file_path);
    let validated_path = validate_file_path(&file_path)?;
    tracing::debug!(
        "[parse_book] path validated: validated_path={}",
        validated_path
    );

    let metadata = tokio::fs::metadata(&validated_path)
        .await
        .map_err(|e| AppError::FileReadError { path: validated_path.clone().into(), details: e.to_string().into() })?;
    tracing::debug!("[parse_book] file size: {} bytes", metadata.len());
    if metadata.len() > MAX_FILE_SIZE {
        tracing::warn!(
            "[parse_book] file size exceeded: {} > {} bytes",
            metadata.len(),
            MAX_FILE_SIZE
        );
        return Err(AppError::SecurityError { reason: format!(
            "file size exceeds limit (max {} MB)",
            MAX_FILE_SIZE / 1024 / 1024
        ).into(), path: validated_path.into() });
    }

    // 导入去重：检查 file_path 是否已存在，避免重复导入
    let pool = storage_pool()?;
    if let Some(existing) = BookRepository::find_by_file_path(&pool, &validated_path).await? {
        tracing::info!(
            "[parse_book] already exists: book_id={}, path={}",
            existing.book_id,
            validated_path
        );
        return Ok(existing.book_id);
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
    BookRepository::save(&pool, &result.book_info).await?;
    BookRepository::save_metadata(&pool, &result.book_info).await?;
    ChapterRepository::save(&pool, &result.book_info.book_id, &result.chapters).await?;
    Ok(result.book_info.book_id)
}


// ==================== 章节内容 ====================

async fn extract_chapter_content(file_path: &str, chapter_index: i32) -> Result<String, AppError> {
    let parser = parser_for_file(file_path)?;
    parser.extract_chapter(file_path, chapter_index).await
}


// ==================== 排版缓存 ====================

/// 尝试从缓存获取分页结果
async fn try_get_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
    config_hash: u64,
) -> Option<Vec<PageContent>> {
    let storage = crate::storage::storage()?;
    let pool = match storage.pool() {
        Ok(p) => p,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] miss: pool unavailable: {e}");
            return None;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return None,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] miss: book lookup failed: {e}");
            return None;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id.clone(),
        chapter_index,
        chunk_index,
        config_hash,
    };
    let kv = storage.kv();
    let cache_repo = LayoutCacheRepository::new(kv);
    match cache_repo.get_layout_cache(&cache_key) {
        Ok(Some(cache)) => {
            tracing::debug!("cache[{chunk_index:?}] HIT: {}", cache_key);
            Some(cache.pages)
        }
        Ok(None) => None,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] read failed: {}", e);
            None
        }
    }
}

/// 保存排版结果到缓存（写入失败不影响阅读）
async fn try_save_cached(
    validated_path: &str,
    chapter_index: i32,
    chunk_index: Option<u32>,
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
            tracing::warn!("cache[{chunk_index:?}] save skipped: pool unavailable: {e}");
            return;
        }
    };
    let book = match BookRepository::find_by_file_path(&pool, validated_path).await {
        Ok(Some(b)) => b,
        Ok(None) => return,
        Err(e) => {
            tracing::warn!("cache[{chunk_index:?}] save skipped: book lookup failed: {e}");
            return;
        }
    };
    let cache_key = LayoutCacheKey {
        book_id: book.book_id,
        chapter_index,
        chunk_index,
        config_hash,
    };
    let cache = LayoutCache::new(config_hash, pages);
    let cache_repo = LayoutCacheRepository::new(storage.kv());
    if let Err(e) = cache_repo.save_layout_cache(&cache_key, &cache) {
        tracing::warn!("cache[{chunk_index:?}] save failed: {}", e);
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
            .map_err(|e| AppError::TaskPanic { task_name: "txt provider".into(), details: e.to_string().into() })??;
            Arc::new(provider)
        }
        BookFormat::Epub => {
            // Fetch spine bounds from DB *before* spawn_blocking —
            // get_chapter_bounds is async (DB query).
            let (start_idx, end_idx) = get_chapter_bounds(validated_path, chapter_index).await?;
            // Detect stale pre-migration books: start/end both DEFAULT 0
            if start_idx == 0 && end_idx == 0 {
                return Err(AppError::StaleBookData {
                    message: "Chapter bounds missing. Please re-import this book.".into(),
                });
            }
            let path = validated_path.to_string();
            let provider = tokio::task::spawn_blocking(move || {
                crate::parser::epub::provider::EpubContentProvider::open_from_bounds(
                    &path, start_idx, end_idx,
                )
            })
            .await
            .map_err(|e| AppError::TaskPanic { task_name: "epub provider".into(), details: e.to_string().into() })??;
            Arc::new(provider)
        }
        BookFormat::Md => {
            let content = tokio::fs::read_to_string(validated_path)
                .await
                .map_err(|e| AppError::FileReadError { path: validated_path.into(), details: e.to_string().into() })?;
            Arc::new(crate::parser::md::MdContentProvider::new(content))
        }
        BookFormat::Pdf => {
            return Err(AppError::InvalidInput { reason: "PDF does not support range-based text access".into() });
        }
    };

    let mut cache = PROVIDER_CACHE.lock();
    if !cache.contains(&cache_key) {
        cache.put(cache_key, p.clone());
    }
    Ok(p)
}

/// 快速获取章节首段文本（仅读第一个 spine，不做分页）。
///
/// Dart 侧用于快速渲染第 0 页，全文和分页后台异步补齐。
/// EPUB: 只读第一个 spine 的 HTML → 截断为 8KB → html_to_plain_text → 再截断 2000 字符
/// TXT/MD: 读文件前 2000 字符
#[frb]
pub async fn get_chapter_first_spine_only(
    file_path: String,
    chapter_index: i32,
) -> Result<FirstSpineResult, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    let text = if format == BookFormat::Epub {
        let (start_idx, _) = get_chapter_bounds(&validated_path, chapter_index).await?;
        let path = validated_path.clone();
        let idx = chapter_index;
        let spine_start = start_idx;
        tokio::task::spawn_blocking(move || -> Result<String, AppError> {
            let mut epub =
                crate::parser::epub::unzip::EpubFile::open(&path)
                    .map_err(|e| AppError::ChapterExtractError { index: idx, reason: e.to_string().into() })?;
            let spine = epub.spine();
            let start = spine_start.max(0) as usize;
            if start >= spine.len() {
                return Ok(String::new());
            }

            let href = &spine[start];
            let html = epub
                .read_resource(href)
                .map_err(|e| AppError::ChapterExtractError { index: idx, reason: e.to_string().into() })?;

            // 截断 HTML 到 8KB 避免 html_to_plain_text 处理大文件
            let truncated: String = html.chars().take(8 * 1024).collect();
            let plain =
                crate::parser::epub::provider::html_to_plain_text(&truncated);
            // 只取前 2000 字符用作首屏
            Ok(plain.chars().take(2000).collect())
        })
        .await
        .map_err(|e| AppError::TaskPanic { task_name: "first_spine".into(), details: e.to_string().into() })??
    } else {
        // TXT/MD: 读前 2000 字符
        let content = tokio::fs::read_to_string(&validated_path)
            .await
            .map_err(|e| AppError::FileReadError { path: validated_path.into(), details: e.to_string().into() })?;
        content.chars().take(2000).collect()
    };

    Ok(FirstSpineResult { text })
}

/// 获取章节前 N 字符（惰性转换，只读取必要的 spine）。
///
/// EPUB: 只转换覆盖前 `max_chars` 字符的 spine item，其余保持未转换状态。
/// TXT/MD: 直接读取文件前 N 字符。
#[frb]
pub async fn get_chapter_partial(
    file_path: String,
    chapter_index: i32,
    max_chars: u64,
) -> Result<String, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

    if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        if matches!(format, BookFormat::Txt | BookFormat::Md) {
            // max_chars 是字符数，但 read_text_range 用字节偏移。
            let read_end = (max_chars * 3).min(provider.content_length());
            let content = provider.read_text_range(0, read_end)?;
            Ok(content.chars().take(max_chars as usize).collect())
        } else {
            Ok(provider.read_text_range(0, max_chars)?)
        }
    } else {
        let text = extract_chapter_content(&validated_path, chapter_index).await?;
        Ok(text.chars().take(max_chars as usize).collect())
    }
}

/// 获取指定章节的原始文本内容。
///
/// 返回章节全文的字符串，适用于无需分页的场景。
#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
    config: Option<TypesetConfig>,
) -> Result<ChapterContent, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let format = format_from_file_path(&validated_path)?;

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
                    try_get_cached(&validated_path, chapter_index, None, config_hash).await
                {
                    return Ok(chapter_content_pages(pages));
                }

                let chapter_idx = chapter_index;
                let pages =
                    tokio::task::spawn_blocking(move || paginate_all(text, chapter_idx, cfg))
                        .await
                        .map_err(|e| AppError::TaskPanic { task_name: "pagination".into(), details: e.to_string().into() })?;

                // 写缓存
                try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone())
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
                    try_get_cached(&validated_path, chapter_index, None, config_hash).await
                {
                    return Ok(chapter_content_pages(pages));
                }

                let pages = paginate_all(text, chapter_index, cfg);

                // 写缓存
                try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone())
                    .await;

                Ok(chapter_content_pages(pages))
            }
            None => Ok(ChapterContent::Raw(text)),
        }
    }
}


/// 分页排版指定文件的所有章节。
///
/// 返回完整的分页结果，适用于全量排版场景。

#[frb]
pub async fn paginate_all_content(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<Vec<PageContent>, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();

    // 查缓存
    if let Some(pages) = try_get_cached(&validated_path, chapter_index, None, config_hash).await {
        return Ok(pages);
    }

    // 优先使用 Provider LRU 路径（与 getChapter 共享解析器缓存，避免重复 I/O）
    let format = format_from_file_path(&validated_path)?;
    let content = if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        let (start, end) = if format == BookFormat::Epub {
            (0u64, content_len)
        } else {
            let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
            (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
        };
        provider.read_text_range(start, end)?
    } else {
        extract_chapter_content(&validated_path, chapter_index).await?
    };

    let chapter_idx = chapter_index;
    let pages = tokio::task::spawn_blocking(move || paginate_all(content, chapter_idx, config))
        .await
        .map_err(|e| AppError::TaskPanic { task_name: "pagination".into(), details: e.to_string().into() })?;

    try_save_cached(&validated_path, chapter_index, None, config_hash, pages.clone()).await;

    Ok(pages)
}

/// 轻量级分页排版（只获取页面描述符，文本按需加载）。
///
/// 创建 `PageStreamer` 并缓存到 LRU 缓存中，Dart 侧通过 `get_page_content` 按需获取页面内容。
/// 如果指定 `max_chars`，只读取前 N 字符进行分页（惰性转换，只转换必要的 spine），
/// 用于初始快速分页。不指定则读取全文。
/// 与 `paginate_all_content` 相比，显著减少 FFI 数据量（只传偏移量，不传文本）。
#[frb]
pub async fn paginate_chapter(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let start = std::time::Instant::now();

    // 提取章节文本（只读取必要的 spine，惰性转换）
    let format = format_from_file_path(&validated_path)?;
    let (content, is_partial) = if matches!(format, BookFormat::Txt | BookFormat::Md | BookFormat::Epub) {
        let provider = get_or_create_provider(&validated_path, chapter_index, &format).await?;
        let content_len = provider.content_length();
        // 短路：如果 max_chars >= 全文长度，降级为完整分页（避免不完整结果）
        let effective_max = match max_chars {
            Some(limit) if limit >= content_len => None,
            x => x,
        };
        match effective_max {
            Some(limit) => {
                if matches!(format, BookFormat::Txt | BookFormat::Md) {
                    // max_chars 是字符数，但 read_text_range 用字节偏移。
                    // UTF-8 CJK 最多 3 字节/字符，预读 limit*3 字节再取 limit 个字符。
                    let read_end = (limit * 3).min(content_len);
                    let content = provider.read_text_range(0, read_end)?;
                    let partial: String = content.chars().take(limit as usize).collect();
                    (partial, true)
                } else {
                    // EPUB: same char-take logic as TXT/MD.
                    // read_text_range uses byte offsets; pre-read limit*3
                    // bytes then truncate to limit chars (CJK safety).
                    let read_end = (limit * 3).min(content_len);
                    let content = provider.read_text_range(0, read_end)?;
                    let partial: String = content.chars().take(limit as usize).collect();
                    (partial, true)
                }
            }
            None => {
                let (start, end) = if format == BookFormat::Epub {
                    (0u64, content_len)
                } else {
                    let (cs, ce) = get_chapter_bounds(&validated_path, chapter_index).await?;
                    (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
                };
                (provider.read_text_range(start, end)?, false)
            }
        }
    } else {
        (extract_chapter_content(&validated_path, chapter_index).await?, false)
    };

    // 全章分页 KV 缓存命中路径：跳过 CPU 排版直接复用
    if max_chars.is_none() {
        if let Some(pages) = try_get_cached(&validated_path, chapter_index, None, config_hash).await {
            let streamer = PageStreamer::from_pages(pages);
            let descriptors = streamer.get_descriptors();
            STREAMER_CACHE.lock().put((validated_path, chapter_index, config_hash), streamer);
            tracing::info!(
                "[Timing] paginate_chapter cache=HIT config_hash={:016x} chapter={} elapsed={:?}",
                config_hash, chapter_index, start.elapsed()
            );
            return Ok(PaginateResult {
                descriptors,
                config_hash,
                is_partial: false,
            });
        }
    }

    let mut streamer = PageStreamer::new(content, config);
    streamer.is_partial = is_partial;
    let descriptors = streamer.get_descriptors();

    // 提取全页内容用于 KV 缓存保存（在 streamer 移入 STREAMER_CACHE 之前完成）
    let cached_pages = if !is_partial {
        let total = descriptors.len();
        Some(
            (0..total)
                .filter_map(|i| streamer.get_page(i, chapter_index))
                .collect::<Vec<PageContent>>(),
        )
    } else {
        None
    };

    // 缓存 PageStreamer 供后续按需获取页面内容
    {
        let mut cache = STREAMER_CACHE.lock();
        cache.put((validated_path.clone(), chapter_index, config_hash), streamer);
    }

    // 全章分页完成后写入持久化 KV 缓存
    if let Some(pages) = cached_pages {
        try_save_cached(&validated_path, chapter_index, None, config_hash, pages).await;
    }

    tracing::info!(
        "[Timing] paginate_chapter cache=MISS config_hash={:016x} chapter={} elapsed={:?}",
        config_hash, chapter_index, start.elapsed()
    );
    Ok(PaginateResult {
        descriptors,
        config_hash,
        is_partial,
    })
}

/// 按需获取单页内容（同步，纯内存操作）。
///
/// 从 LRU 缓存中查找对应章节的 `PageStreamer`，调用 `get_page` 获取指定页的文本内容。
/// 如果缓存中不存在（过期或被驱逐），返回空字符串，调用方应回退到 `paginate_all_content`。
#[frb(sync)]
pub fn get_page_content(
    file_path: String,
    chapter_index: i32,
    config_hash: u64,
    page_index: i32,
) -> String {
    let key = (file_path, chapter_index, config_hash);
    let mut cache = STREAMER_CACHE.lock();
    if let Some(streamer) = cache.get(&key) {
        if let Some(page) = streamer.get_page(page_index as usize, chapter_index) {
            return page.content;
        }
    }
    String::new()
}

/// Create a pagination session and run initial pagination for the chapter.
///
/// Stores `(file_path, chapter_index, config_hash)` server-side so Dart can
/// fetch page text via [get_session_page_content] without repeating path/config args.
#[frb]
pub async fn create_pagination_session(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let result = paginate_chapter(
        validated_path.clone(),
        chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let session_id = allocate_session_id();
    let streamer_key = (validated_path.clone(), chapter_index, result.config_hash);
    let streamer = STREAMER_CACHE
        .lock()
        .get(&streamer_key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("page streamer for session {session_id}"),
        })?;

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: validated_path,
            chapter_index,
            config,
            streamer,
        },
    );

    Ok((PaginationSessionHandle { session_id }, result))
}


/// Create a pagination session by adopting an existing streamer from cache.
///
/// 1. Look up `STREAMER_CACHE[(path, chapter_index, config_hash)]`
/// 2. **Hit**: allocate a new session id + bind the cached `PageStreamer`,
///    return its descriptors (**no** `paginate_chapter` call).
/// 3. **Miss**: return `AppError::NotFound` — the caller should fall back to
///    `create_pagination_session` + normal load.
#[frb]
pub async fn create_pagination_session_adopt(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
) -> Result<(PaginationSessionHandle, PaginateResult), AppError> {
    let validated_path = validate_file_path(&file_path)?;
    let config = config.validate_and_fix();
    let config_hash = config.config_hash();
    let key = (validated_path.clone(), chapter_index, config_hash);

    let streamer = STREAMER_CACHE
        .lock()
        .get(&key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("page streamer for chapter {chapter_index} (config_hash={config_hash:016x})"),
        })?;

    let descriptors = streamer.get_descriptors();
    let is_partial = streamer.is_partial;

    let session_id = allocate_session_id();
    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: validated_path,
            chapter_index,
            config,
            streamer,
        },
    );

    Ok((
        PaginationSessionHandle { session_id },
        PaginateResult {
            descriptors,
            config_hash,
            is_partial,
        },
    ))
}
/// Internal helper: re-paginate a session and atomically update config + streamer.
///
/// `config` should already be validated. The old streamer cache entry is
/// evicted when the (path, chapter, hash) key changes, mirroring the dispose
/// strategy so orphans cannot accumulate.
async fn apply_session_repagination(
    session_id: u64,
    entry: PaginationSessionEntry,
    config: Option<TypesetConfig>,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let config = config
        .map(|c| c.validate_and_fix())
        .unwrap_or_else(|| entry.config.clone());
    let old_key = (
        entry.file_path.clone(),
        entry.chapter_index,
        entry.config.config_hash(),
    );

    let result = paginate_chapter(
        entry.file_path.clone(),
        entry.chapter_index,
        config.clone(),
        max_chars,
    )
    .await?;

    let new_key = (
        entry.file_path.clone(),
        entry.chapter_index,
        result.config_hash,
    );
    let streamer = STREAMER_CACHE
        .lock()
        .get(&new_key)
        .cloned()
        .ok_or_else(|| AppError::NotFound {
            entity: format!("page streamer for session {session_id}"),
        })?;

    if old_key != new_key {
        STREAMER_CACHE.lock().pop(&old_key);
    }

    SESSION_MAP.lock().insert(
        session_id,
        PaginationSessionEntry {
            file_path: entry.file_path,
            chapter_index: entry.chapter_index,
            config,
            streamer,
        },
    );

    Ok(result)
}

/// Re-paginate an existing session with a new config in-place.
/// `max_chars` is `None` to expand to full chapter.
#[frb]
pub async fn repaginate_session(
    handle: PaginationSessionHandle,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<PaginateResult, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    apply_session_repagination(handle.session_id, entry, Some(config), max_chars).await
}

/// Expand session to full chapter.
/// `config = None` reuses the entry's stored config; `Some(c)` swaps in new
/// config first (delegates to [repaginate_session]).
#[frb]
pub async fn paginate_session_full(
    handle: PaginationSessionHandle,
    config: Option<TypesetConfig>,
) -> Result<PaginateResult, AppError> {
    if let Some(cfg) = config {
        return repaginate_session(handle, cfg, None).await;
    }
    let entry = lookup_pagination_session(handle.session_id)?;
    apply_session_repagination(handle.session_id, entry, None, None).await
}

/// Get page content by session handle (sync).
/// Throws `AppError` if session not found.
#[frb(sync)]
pub fn get_session_page_content(
    handle: PaginationSessionHandle,
    page_index: i32,
) -> Result<String, AppError> {
    let entry = lookup_pagination_session(handle.session_id)?;
    Ok(entry
        .streamer
        .get_page(page_index as usize, entry.chapter_index)
        .map(|p| p.content)
        .unwrap_or_default())
}

/// Compute config hash from a TypesetConfig (sync).
/// Exposes `TypesetConfig::config_hash()` to Dart since FRB
/// does not expose impl methods for non_opaque structs.
#[frb(sync)]
pub fn compute_config_hash(config: TypesetConfig) -> u64 {
    config.config_hash()
}

pub fn dispose_pagination_session(handle: PaginationSessionHandle) -> Result<(), AppError> {
    let entry = SESSION_MAP
        .lock()
        .remove(&handle.session_id)
        .ok_or_else(|| AppError::NotFound {
            entity: format!("pagination session {}", handle.session_id),
        })?;

    // Evict the streamer from STREAMER_CACHE — the entry holds its own clone
    let streamer_key = (entry.file_path, entry.chapter_index, entry.config.config_hash());
    STREAMER_CACHE.lock().pop(&streamer_key);

    Ok(())
}

// ==================== Provider 管理 ====================

/// 从文件路径推断格式
fn format_from_file_path(file_path: &str) -> Result<BookFormat, AppError> {
    let ext = std::path::Path::new(file_path)
        .extension()
        .and_then(|e| e.to_str())
        .ok_or_else(|| {
            AppError::UnsupportedFormat {
                format: "file has no extension".into(),
            }
        })?;
    crate::parser::registry::format_from_extension(ext)
}

/// 从 DB 获取章节边界信息（TXT/MD 的文件字节偏移，EPUB/PDF 的 spine/页索引）
pub(crate) async fn get_chapter_bounds(
    validated_path: &str,
    chapter_index: i32,
) -> Result<(i32, i32), AppError> {
    let pool = storage_pool()?;
    // 从 LRU 缓存获取 book_id，避免重复的 find_by_file_path DB 查询
    // 注意：parking_lot::MutexGuard 不是 Send，必须在 await 前释放锁
    if let Some(book_id) = {
        let mut cache = BOOK_ID_CACHE.lock();
        cache.get(validated_path).cloned()
    } {
        let chapter = ChapterRepository::find_by_index(&pool, &book_id, chapter_index)
            .await?
            .ok_or_else(|| AppError::ChapterExtractError { index: chapter_index, reason: "chapter not found in DB".into() })?;
        return Ok((chapter.start_index as i32, chapter.end_index as i32));
    }

    let book = BookRepository::find_by_file_path(&pool, validated_path)
        .await?
        .ok_or_else(|| AppError::FileNotFound { path: validated_path.into() })?;
    let book_id = book.book_id.clone();
    // 填充缓存（不持有锁跨 await）
    {
        let mut cache = BOOK_ID_CACHE.lock();
        cache.put(validated_path.to_string(), book_id.clone());
    }

    let chapter = ChapterRepository::find_by_index(&pool, &book_id, chapter_index)
        .await?
        .ok_or_else(|| AppError::ChapterExtractError { index: chapter_index, reason: "chapter not found in DB".into() })?;

    Ok((chapter.start_index as i32, chapter.end_index as i32))
}



/// 获取 PDF 指定页面的文本内容
///
/// PDF 不走分块排版路径，直接返回单页文本。
/// Flutter 端直接渲染，无需经过排版引擎。
// TODO: Dart 侧尚未接入 PDF 阅读
#[frb]
pub async fn get_pdf_page(file_path: String, page_index: u32) -> Result<PageData, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    tokio::task::spawn_blocking(move || {
        let provider = PdfContentProvider::open(&validated_path)?;
        provider.get_page(page_index)
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "pdf page".into(), details: e.to_string().into() })?
}

/// 获取 PDF 总页数
#[frb]
// TODO: Dart 侧尚未接入 PDF 阅读
pub async fn get_pdf_total_pages(file_path: String) -> Result<u32, AppError> {
    let validated_path = validate_file_path(&file_path)?;
    tokio::task::spawn_blocking(move || {
        let provider = crate::parser::pdf::provider::PdfContentProvider::open(&validated_path)?;
        Ok(provider.total_pages())
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "pdf total pages".into(), details: e.to_string().into() })?
}

/// 检查格式是否已实现分块排版 Provider
// TODO: Dart 侧尚未接入 PDF 阅读
#[frb(sync)]
pub fn supports_chunked_pagination(file_path: String) -> bool {
    matches!(
        format_from_file_path(&file_path),
        Ok(BookFormat::Txt | BookFormat::Md | BookFormat::Epub)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use crate::storage::{STORAGE, db::StorageManager};
    use tempfile::TempDir;
    use std::sync::LazyLock;

    /// Shared temp dir for all storage-dependent tests — leaks the TempDir.
    static SHARED_DIR: LazyLock<PathBuf> = LazyLock::new(|| {
        let tmp = TempDir::new().unwrap();
        let path = tmp.path().to_path_buf();
        let _ = Box::leak(Box::new(tmp));
        path
    });
    /// Initialize STORAGE exactly once, using the shared temp dir.
    async fn ensure_shared_storage() {
        use tokio::sync::Mutex;
        static INIT: Mutex<bool> = Mutex::const_new(false);
        if STORAGE.get().is_some() {
            return;
        }
        let mut done = INIT.lock().await;
        if *done {
            return;
        }
        if STORAGE.get().is_some() {
            return;
        }
        let mgr = StorageManager::new(SHARED_DIR.as_path()).await.unwrap();
        STORAGE.set(mgr).unwrap_or_else(|_| panic!("STORAGE init conflict"));
        *done = true;
    }

    #[test]
    fn test_format_from_file_path() {
        assert_eq!(format_from_file_path("book.txt"), Ok(BookFormat::Txt));
        assert_eq!(format_from_file_path("book.epub"), Ok(BookFormat::Epub));
        assert_eq!(format_from_file_path("book.md"), Ok(BookFormat::Md));
        assert_eq!(format_from_file_path("book.pdf"), Ok(BookFormat::Pdf));
        assert_eq!(format_from_file_path("book.markdown"), Ok(BookFormat::Md));
        assert_eq!(
            format_from_file_path("book.mobi"),
            Err(AppError::UnsupportedFormat { format: "Unknown format: mobi".into() })
        );
        assert_eq!(
            format_from_file_path("book_no_ext"),
            Err(AppError::UnsupportedFormat { format: "file has no extension".into() })
        );
    }

    #[test]
    fn test_supports_chunked_pagination() {
        assert!(supports_chunked_pagination("book.txt".to_string()));
        assert!(supports_chunked_pagination("book.epub".to_string()));
        assert!(supports_chunked_pagination("book.md".to_string()));
        assert!(!supports_chunked_pagination("book.pdf".to_string()));
    }

    #[tokio::test]
    async fn diagnose_content_extraction_pipeline() {
        ensure_shared_storage().await;
        let content = "第一章 混合内容\n\nToday was the day. 他站在窗前。\n";
        let file_path_buf = SHARED_DIR.join("test_book_diag.txt");
        std::fs::write(&file_path_buf, content).unwrap();
        let file_path = file_path_buf.to_string_lossy().to_string();

        let book_id = parse_book(file_path.clone()).await
            .expect("parse_book should succeed");
        let pool = storage_pool().unwrap();
        let _book = BookRepository::find_by_id(&pool, &book_id).await
            .expect("find_by_id should succeed")
            .expect("book should exist");
        let _chapters = ChapterRepository::find_by_book(&pool, &book_id).await
            .expect("find_by_book should succeed");

        let validated = validate_file_path(&file_path)
            .expect("validate should succeed");
        let bounds = get_chapter_bounds(&validated, 0).await
            .expect("get_chapter_bounds should succeed");
        let format = format_from_file_path(&validated)
            .expect("test TXT file should have known extension");
        let provider = get_or_create_provider(&validated, 0, &format).await
            .expect("get_or_create_provider should succeed");
        let content_len = provider.content_length();

        let (start, end) = {
            let (cs, ce) = bounds;
            (cs.max(0) as u64, (ce.max(0) as u64).min(content_len))
        };
        let text = provider.read_text_range(start, end)
            .expect("read_text_range should succeed");

        let config = TypesetConfig::default();
        let pages = paginate_all_content(file_path.clone(), 0, config).await
            .expect("paginate_all_content should succeed");

        assert!(!text.is_empty(), "Content extraction should return non-empty text");
        assert!(!pages.is_empty(), "PaginateAllContent should produce at least 1 page");
    }

    #[tokio::test]
    async fn test_paginate_chapter_cache_hit_roundtrip() {
        ensure_shared_storage().await;
        let content = "第一章 测试内容\n\nThis is a test chapter for cache roundtrip.\n我们来测试缓存是否正常工作。";
        let file_path_buf = SHARED_DIR.join("test_cache_hit.txt");
        std::fs::write(&file_path_buf, content).unwrap();
        let file_path = file_path_buf.to_string_lossy().to_string();

        parse_book(file_path.clone()).await
            .expect("parse_book should succeed");

        let config = TypesetConfig::default();

        // First call: cache MISS, should compute and save to KV
        let result1 = paginate_chapter(
            file_path.clone(), 0, config.clone(), None,
        ).await.expect("paginate_chapter should succeed (MISS)");
        assert!(!result1.is_partial, "full chapter should not be partial");
        assert!(!result1.descriptors.is_empty(), "should have at least 1 page");

        // Second call: cache HIT, should return immediately from KV
        let result2 = paginate_chapter(
            file_path.clone(), 0, config.clone(), None,
        ).await.expect("paginate_chapter should succeed (HIT)");

        assert_eq!(
            result1.descriptors, result2.descriptors,
            "cache HIT should return same descriptors as MISS"
        );
        assert_eq!(result1.config_hash, result2.config_hash,
            "same config should produce same hash");
    }

    #[tokio::test]
    async fn test_paginate_chapter_config_change_misses_cache() {
        ensure_shared_storage().await;
        let content = "Different config test content 不同配置测试\nThis should produce different pagination.";
        let file_path_buf = SHARED_DIR.join("test_config_miss.txt");
        std::fs::write(&file_path_buf, content).unwrap();
        let file_path = file_path_buf.to_string_lossy().to_string();

        parse_book(file_path.clone()).await
            .expect("parse_book should succeed");

        let config1 = TypesetConfig::default();

        // First call with default config (populates KV cache)
        paginate_chapter(
            file_path.clone(), 0, config1.clone(), None,
        ).await.expect("first paginate should succeed");

        // Second call with different font_size → different config_hash → MISS
        let mut config2 = TypesetConfig::default();
        config2.font_size = config2.font_size + 8;
        let result2 = paginate_chapter(
            file_path.clone(), 0, config2.clone(), None,
        ).await.expect("second paginate (diff config) should succeed");

        assert_ne!(result2.config_hash, config1.config_hash(),
            "different config should produce different hash");
    }

    #[tokio::test]
    async fn test_paginate_chapter_partial_skips_full_cache() {
        ensure_shared_storage().await;
        let content = "Partial cache test. This is a longer text that should have enough content for partial pagination. 部分缓存测试内容用来验证跳过全章缓存逻辑。";
        let file_path_buf = SHARED_DIR.join("test_partial_skip.txt");
        std::fs::write(&file_path_buf, content).unwrap();
        let file_path = file_path_buf.to_string_lossy().to_string();

        parse_book(file_path.clone()).await
            .expect("parse_book should succeed");

        let config = TypesetConfig::default();

        // First do full paginate to populate KV cache
        paginate_chapter(
            file_path.clone(), 0, config.clone(), None,
        ).await.expect("full paginate should succeed");

        // Partial paginate should NOT read from full KV cache
        let partial_result = paginate_chapter(
            file_path.clone(), 0, config.clone(), Some(15),
        ).await.expect("partial paginate should succeed");

        assert!(partial_result.is_partial, "partial pagination should be marked partial");
        assert!(!partial_result.descriptors.is_empty(), "partial paginate should still produce pages");
    }

    #[tokio::test]
    async fn test_stale_epub_bounds_returns_stale_book_data() {
        ensure_shared_storage().await;
        let fixture = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/fixtures/medium.epub");
        let file_path = fixture.to_string_lossy().to_string();

        // Parse EPUB to populate DB with valid chapter data
        let book_id = parse_book(file_path.clone()).await
            .expect("parse_book should succeed");

        // Corrupt the first chapter's bounds to simulate stale pre-migration data
        let pool = storage_pool().unwrap();
        let mut chapters = ChapterRepository::find_by_book(&pool, &book_id).await
            .expect("find_by_book should succeed");
        assert!(!chapters.is_empty(), "EPUB fixture should have at least one chapter");

        chapters[0].start_index = 0;
        chapters[0].end_index = 0;
        ChapterRepository::save(&pool, &book_id, &chapters[..1]).await
            .expect("save corrupted chapter should succeed");

        let validated = validate_file_path(&file_path)
            .expect("validate should succeed");

        // Clear provider cache and book_id cache for a clean slate
        PROVIDER_CACHE.lock().clear();
        BOOK_ID_CACHE.lock().clear();

        let result = get_or_create_provider(&validated, 0, &BookFormat::Epub).await;
        assert!(result.as_ref().is_err_and(|e| matches!(e, AppError::StaleBookData { .. })),
            "expected StaleBookData, got {:?}", result.as_ref().err());
    }
}
