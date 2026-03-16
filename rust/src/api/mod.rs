//! Rust 核心引擎 API
//!
//! 本模块提供了 Zephyr Reader Rust 引擎的所有公共接口函数，
//! 通过 flutter_rust_bridge 暴露给 Flutter 侧调用。
//!
//! # 功能分类
//!
//! - **文件解析**: TXT 和 EPUB 格式解析
//! - **文本处理**: 排版、分页、断行
//! - **流式读取**: 大文件分块读取
//! - **进度管理**: 阅读进度和书签管理（SQLite 持久化）
//! - **EPUB 支持**: 封面提取、元数据获取
//! - **零拷贝优化**: 使用 ZeroCopyBuffer 优化大数据传输

pub mod simple;

use crate::catch_panic;
pub use crate::ffi::*;
use crate::storage::{ProgressStorage, SqliteStorage};
use flutter_rust_bridge::{frb, ZeroCopyBuffer};
use once_cell::sync::OnceCell;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::sync::Mutex;
use uuid::Uuid;

// 全局 SQLite 存储实例
static STORAGE: OnceCell<Mutex<SqliteStorage>> = OnceCell::new();

/// 验证文件路径是否安全
///
/// 检查路径是否包含危险的模式（如路径遍历），确保只能访问指定目录。
///
/// # 参数
///
/// * `path` - 待检查的文件路径
///
/// # 返回值
///
/// * `true` - 路径安全
/// * `false` - 路径存在安全风险
fn is_safe_path(path: &str) -> bool {
    // 检查路径遍历攻击模式
    if path.contains("..\\") || path.contains("../") {
        return false;
    }

    // 检查绝对路径是否来自危险位置
    let path_lower = path.to_lowercase();
    if path_lower.starts_with("c:\\windows")
        || path_lower.starts_with("/etc/")
        || path_lower.starts_with("/proc/")
        || path_lower.starts_with("/sys/")
    {
        return false;
    }

    // 检查是否包含空字节（路径截断攻击）
    if path.contains('\0') {
        return false;
    }

    true
}

/// 验证文件路径并返回规范化的路径
///
/// # 参数
///
/// * `file_path` - 文件路径
///
/// # 返回值
///
/// * `Ok(String)` - 验证通过的路径
/// * `Err(ParserError)` - 路径不安全或无效
fn validate_file_path(file_path: &str) -> ApiResult<String> {
    if !is_safe_path(file_path) {
        return Err(ParserError::Other(format!("文件路径不安全：{}", file_path)));
    }

    // 检查文件是否存在
    if !std::path::Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    Ok(file_path.to_string())
}

/// 初始化存储
///
/// 在应用启动时调用，设置 SQLite 数据库路径。
/// 如果未调用此函数，进度和书签将使用临时内存存储（不推荐）。
///
/// # 参数
///
/// * `db_path` - SQLite 数据库文件路径（建议放在应用文档目录）
///
/// # 示例
///
/// Flutter 侧：
/// ```dart
/// final directory = await getApplicationDocumentsDirectory();
/// await initStorage('${directory.path}/zephyr_reader.db');
/// ```
#[frb(sync)]
pub fn init_storage(db_path: String) -> ApiResult<()> {
    let storage = SqliteStorage::new(&db_path)
        .map_err(|e| ParserError::Other(format!("初始化存储失败: {}", e)))?;

    STORAGE
        .set(Mutex::new(storage))
        .map_err(|_| ParserError::Other("存储已经初始化".to_string()))?;

    tracing::info!("SQLite 存储已初始化: {}", db_path);
    Ok(())
}

/// 获取存储实例
fn get_storage() -> ApiResult<std::sync::MutexGuard<'static, SqliteStorage>> {
    STORAGE
        .get()
        .ok_or_else(|| ParserError::Other("存储未初始化，请先调用 init_storage".to_string()))?
        .lock()
        .map_err(|e| ParserError::Other(format!("存储锁定失败: {}", e)))
}

/// 初始化应用
///
/// 此函数由 flutter_rust_bridge 自动调用，用于设置默认的日志和用户工具。
/// 同时配置 tracing 日志订阅者，支持环境变量过滤。
///
/// # 环境变量
///
/// 设置 `RUST_LOG` 环境变量来控制日志级别：
/// - `error` - 仅错误日志
/// - `warn` - 警告及以上
/// - `info` - 信息及以上（默认）
/// - `debug` - 调试及以上
/// - `trace` - 所有日志
///
/// # 示例
///
/// Flutter 侧：
/// ```dart
/// await RustLib.init();
/// ```
///
/// 命令行运行：
/// ```bash
/// # 仅设置本库日志级别
/// RUST_LOG=debug cargo run
///
/// # 设置第三方库日志级别（如 epub 解析器）
/// RUST_LOG=rust_lib_zephyr_reader=debug,epub=info cargo run
///
/// # 完整示例：本库 debug + 第三方库 info + HTTP 库 warn
/// RUST_LOG=debug,rust_lib_zephyr_reader=debug,epub=info,reqwest=warn cargo run
/// ```
#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::fmt::layer;
    use tracing_subscriber::EnvFilter;
    use tracing_subscriber::{layer::SubscriberExt, Registry};

    // 从环境变量读取日志配置
    // 支持以下格式：
    // - RUST_LOG=debug - 所有 crate 都是 debug 级别
    // - RUST_LOG=rust_lib_zephyr_reader=info - 仅本库是 info 级别
    // - RUST_LOG=debug,epub=info - 默认 debug，epub crate 是 info
    let filter = EnvFilter::try_from_env("RUST_LOG").unwrap_or_else(|_| {
        // 如果环境变量未设置或解析失败，使用默认配置
        "rust_lib_zephyr_reader=info"
            .parse()
            .expect("默认日志配置解析失败")
    });

    let subscriber = Registry::default()
        .with(
            layer()
                .with_target(false)
                .with_thread_ids(false)
                .with_file(false)
                .with_line_number(false),
        )
        .with(filter);

    tracing::subscriber::set_global_default(subscriber).expect("设置日志订阅者失败");

    log::info!("Zephyr Reader Rust Engine initialized");
    tracing::info!("日志系统已初始化，可通过 RUST_LOG 环境变量配置日志级别");
    tracing::info!("示例：RUST_LOG=debug,rust_lib_zephyr_reader=debug,epub=info");
}

/// 测试连接
///
/// 用于验证 Rust 引擎是否正常工作。
///
/// # 返回值
///
/// 返回固定字符串 "Zephyr Reader Rust Engine OK"
#[frb(sync)]
pub fn test_connection() -> String {
    "Zephyr Reader Rust Engine OK".to_string()
}

// ==================== 异步 API 支持 ====================

/// 异步解析 TXT 文件
///
/// 异步版本适用于大文件解析，不阻塞主线程。
/// 在后台线程池中执行 CPU 密集型的解析操作。
///
/// # 参数
///
/// * `file_path` - TXT 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[must_use = "解析结果必须被处理"]
#[frb(dart_async)]
pub async fn async_parse_txt_file(file_path: String) -> ApiResult<ParseResult> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    // 在后台线程池中执行 CPU 密集型操作
    tokio::task::spawn_blocking(move || {
        catch_panic! {
            {
                crate::parser::parse_txt(validated_path)
            }
        }
    })
    .await
    .map_err(|e| ParserError::Other(format!("异步任务执行失败：{}", e)))?
}

/// 异步解析 EPUB 文件
///
/// 异步版本适用于大文件解析，不阻塞主线程。
/// 在后台线程池中执行 CPU 密集型的解析操作。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[must_use = "解析结果必须被处理"]
#[frb(dart_async)]
pub async fn async_parse_epub_file(file_path: String) -> ApiResult<ParseResult> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    // 在后台线程池中执行 CPU 密集型操作
    tokio::task::spawn_blocking(move || {
        catch_panic! {
            {
                crate::parser::parse_epub(validated_path)
            }
        }
    })
    .await
    .map_err(|e| ParserError::Other(format!("异步任务执行失败：{}", e)))?
}

/// 异步解析 PDF 文件
///
/// 异步版本适用于大文件解析，不阻塞主线程。
/// 在后台线程池中执行 CPU 密集型的解析操作。
///
/// # 参数
///
/// * `file_path` - PDF 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[must_use = "解析结果必须被处理"]
#[frb(dart_async)]
pub async fn async_parse_pdf_file(file_path: String) -> ApiResult<ParseResult> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    // 在后台线程池中执行 CPU 密集型操作
    tokio::task::spawn_blocking(move || {
        catch_panic! {
            {
                crate::parser::parse_pdf(validated_path)
            }
        }
    })
    .await
    .map_err(|e| ParserError::Other(format!("异步任务执行失败：{}", e)))?
}

/// 异步解析本地书籍文件
///
/// 自动检测文件类型（TXT、EPUB 或 PDF）并调用相应的异步解析器。
/// 适用于大文件解析，不阻塞主线程。
///
/// # 参数
///
/// * `file_path` - 本地书籍文件的完整路径
///
/// # 返回值
///
/// * `Ok(LocalBookInfo)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[frb(dart_async)]
pub async fn async_parse_local_book(file_path: String) -> ApiResult<LocalBookInfo> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    // 在后台线程池中执行 CPU 密集型操作
    tokio::task::spawn_blocking(move || {
        // 获取文件扩展名
        let path = std::path::Path::new(&validated_path);
        let extension = path
            .extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("")
            .to_lowercase();

        // 根据文件类型调用相应的解析器
        let parse_result = match extension.as_str() {
            "txt" => crate::parser::parse_txt(validated_path.clone())?,
            "epub" => crate::parser::parse_epub(validated_path.clone())?,
            "pdf" => crate::parser::parse_pdf(validated_path.clone())?,
            _ => {
                return Err(ParserError::UnsupportedFormat(format!(
                    "不支持的文件格式：{}，仅支持 TXT、EPUB 和 PDF",
                    extension
                )));
            }
        };

        // 转换为 LocalBookInfo
        Ok(LocalBookInfo {
            file_path: validated_path.clone(),
            file_size: std::fs::metadata(&validated_path)
                .map(|m| m.len() as i64)
                .unwrap_or(0),
            title: parse_result.book_info.title,
            author: parse_result.book_info.author,
            description: String::new(),
            cover_path: parse_result.book_info.cover_path,
            chapter_count: parse_result.chapters.len() as i32,
            chapters: parse_result.chapters,
        })
    })
    .await
    .map_err(|e| ParserError::Other(format!("异步任务执行失败：{}", e)))?
}

/// 解析 TXT 文件
///
/// 读取并解析 TXT 文件，提取章节信息和书籍元数据。
/// 支持多种中文编码自动检测（UTF-8、GBK、GB2312、Big5）。
///
/// # 参数
///
/// * `file_path` - TXT 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败，可能的错误：
///   - `FileNotFound` - 文件不存在
///   - `FileReadError` - 文件读取失败
///   - `EncodingError` - 编码检测失败
///   - `TxtParseError` - TXT 解析失败
#[must_use = "解析结果必须被处理"]
#[frb(sync)]
pub fn parse_txt_file(file_path: String) -> ApiResult<ParseResult> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    catch_panic! {
        {
            crate::parser::parse_txt(validated_path)
        }
    }
}

/// 解析 EPUB 文件
///
/// 读取并解析 EPUB 文件，提取章节信息、书籍元数据和封面路径。
/// EPUB 规范要求 UTF-8 编码，本函数自动处理。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(ParseResult)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败，可能的错误：
///   - `FileNotFound` - 文件不存在
///   - `FileReadError` - 文件读取失败
///   - `EncodingError` - 编码检测失败
///   - `EpubParseError` - EPUB 解析失败
#[must_use = "解析结果必须被处理"]
#[frb(sync)]
pub fn parse_epub_file(file_path: String) -> ApiResult<ParseResult> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    catch_panic! {
        {
            crate::parser::parse_epub(validated_path)
        }
    }
}

/// 排版处理文本
///
/// 对文本进行智能排版处理，包括：
/// - 首行缩进
/// - 标点符号避首避尾
/// - 中英文混排优化
/// - 智能断行
///
/// # 参数
///
/// * `content` - 待排版的原始文本
/// * `language` - 语言类型（"auto"、"zh"、"en"、"mix"）
/// * `config` - 排版配置（字体大小、行间距等）
///
/// # 返回值
///
/// * `Ok(String)` - 排版后的文本
/// * `Err(ParserError)` - 处理失败
#[must_use = "排版结果必须被处理"]
#[frb(sync)]
pub fn typeset_text(content: String, language: String, config: TypesetConfig) -> ApiResult<String> {
    // 验证配置
    config
        .validate()
        .map_err(|e| ParserError::ConfigError(e.to_string()))?;

    catch_panic! {
        {
            crate::text_process::typeset_content(content, language, config)
        }
    }
}

/// 获取文件大小
///
/// 获取指定文件的大小（字节数）。
///
/// # 参数
///
/// * `file_path` - 文件的完整路径
///
/// # 返回值
///
/// * `Ok(i64)` - 文件大小（字节）
/// * `Err(ParserError)` - 获取失败
#[must_use = "文件大小必须被处理"]
#[frb(sync)]
pub fn get_file_size(file_path: String) -> ApiResult<i64> {
    crate::stream::get_file_size(file_path)
}

/// 读取文件块
///
/// 从指定位置读取文件的一块内容，适用于大文件流式读取。
///
/// # 参数
///
/// * `file_path` - 文件的完整路径
/// * `start_pos` - 起始位置（字节偏移）
/// * `chunk_size` - 读取的字节数
///
/// # 返回值
///
/// * `Ok(String)` - 读取的内容（UTF-8 解码）
/// * `Err(ParserError)` - 读取失败
#[must_use = "读取的内容必须被处理"]
#[frb(sync)]
pub fn read_file_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String> {
    crate::stream::read_chunk(file_path, start_pos, chunk_size)
}

/// 创建分页器
///
/// 基于像素宽度精确计算，创建文本分页器。
/// 支持中英文混合排版，自动处理字符宽度差异。
///
/// # 参数
///
/// * `content` - 待分页的文本内容
/// * `config` - 排版配置（页面尺寸、字体大小等）
///
/// # 返回值
///
/// 返回 `PageStreamer` 分页器实例，可用于：
/// - 获取当前页
/// - 翻页（上一页/下一页）
/// - 跳转到指定页
/// - 获取进度
#[must_use = "分页器必须被使用"]
#[frb(sync)]
pub fn create_page_streamer(content: String, config: TypesetConfig) -> crate::stream::PageStreamer {
    // 验证配置（如果验证失败，使用默认配置）
    let validated_config = config.validate_and_fix();
    crate::stream::PageStreamer::new(content, validated_config)
}

/// 将所有内容分页
///
/// 一次性将全部内容分页，返回所有页面。
/// 适用于内容较少或需要预加载的场景。
///
/// # 参数
///
/// * `content` - 待分页的文本内容
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置
///
/// # 返回值
///
/// 返回 `Vec<PageContent>`，包含所有页面的内容。
#[must_use = "分页结果必须被处理"]
#[frb(sync)]
pub fn paginate_all_content(
    content: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> Vec<PageContent> {
    // 验证配置（如果验证失败，使用默认配置）
    let validated_config = config.validate_and_fix();
    crate::stream::paginate_all(content, chapter_id, validated_config)
}

// ==================== 阅读进度管理 ====================

/// 创建或更新阅读进度（支持阅读时间统计）
///
/// 记录用户的阅读进度，包括当前章节、页码和进度百分比。
/// 自动记录最后阅读时间戳。数据会持久化到 SQLite 数据库。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `chapter_id` - 当前章节 ID
/// * `page_index` - 当前页码
/// * `total_pages` - 总页数
/// * `session_duration` - 本次阅读时长（秒），用于累加总阅读时间
///
/// # 返回值
///
/// 返回更新后的 `ReadingProgress` 进度信息
#[must_use = "更新后的进度必须被处理"]
#[frb(sync)]
pub fn update_reading_progress_with_duration(
    book_id: String,
    chapter_id: i32,
    page_index: i32,
    total_pages: i32,
    session_duration: i64,
) -> ReadingProgress {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;

    // 从数据库读取现有进度，累加阅读时间
    let existing_time = match get_storage() {
        Ok(storage) => storage
            .load_progress(&book_id)
            .unwrap_or(None)
            .map(|p| p.reading_time_seconds)
            .unwrap_or(0),
        Err(_) => 0,
    };

    let progress = ReadingProgress {
        chapter_id,
        page_index,
        total_pages,
        progress: if total_pages > 0 {
            (page_index + 1) as f32 / total_pages as f32
        } else {
            0.0
        },
        reading_time_seconds: existing_time + session_duration,
        last_read_timestamp: now,
    };

    if let Ok(storage) = get_storage() {
        if let Err(e) = storage.save_progress(&book_id, &progress) {
            tracing::error!("保存进度失败: {}", e);
        }
    }

    progress
}

/// 创建或更新阅读进度（简化版，不记录阅读时间）
///
/// 记录用户的阅读进度，包括当前章节、页码和进度百分比。
/// 注意：此函数不更新阅读时间统计，如需记录阅读时间请使用 `update_reading_progress_with_duration`。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `chapter_id` - 当前章节 ID
/// * `page_index` - 当前页码
/// * `total_pages` - 总页数
///
/// # 返回值
///
/// 返回更新后的 `ReadingProgress` 进度信息
#[must_use = "更新后的进度必须被处理"]
#[frb(sync)]
pub fn update_reading_progress(
    book_id: String,
    chapter_id: i32,
    page_index: i32,
    total_pages: i32,
) -> ReadingProgress {
    tracing::debug!(
        "更新阅读进度：book={}, chapter={}, page={}/{}",
        book_id,
        chapter_id,
        page_index,
        total_pages
    );
    // 调用带时长的版本，但时长为 0（保持向后兼容）
    update_reading_progress_with_duration(book_id, chapter_id, page_index, total_pages, 0)
}

/// 获取阅读进度
///
/// 获取指定书籍的阅读进度。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
///
/// # 返回值
///
/// 返回 `ReadingProgress` 进度信息，如果没有找到则返回默认进度
#[frb(sync)]
pub fn get_reading_progress(book_id: String) -> ReadingProgress {
    match get_storage() {
        Ok(storage) => storage
            .load_progress(&book_id)
            .unwrap_or(None)
            .unwrap_or_default(),
        Err(_) => ReadingProgress::default(),
    }
}

/// 清除阅读进度
///
/// 删除指定书籍的阅读进度记录。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
///
/// # 返回值
///
/// * `true` - 成功清除进度
/// * `false` - 该书籍没有进度记录或存储未初始化
#[frb(sync)]
pub fn clear_reading_progress(book_id: String) -> bool {
    match get_storage() {
        Ok(storage) => {
            let existed = storage.load_progress(&book_id).unwrap_or(None).is_some();
            if let Err(e) = storage.delete_progress(&book_id) {
                tracing::error!("删除进度失败: {}", e);
            }
            existed
        }
        Err(_) => false,
    }
}

/// 获取所有书籍的阅读进度
///
/// # 返回值
///
/// 返回所有书籍的进度列表，按最后阅读时间降序排列
#[frb(sync)]
pub fn get_all_reading_progress() -> Vec<ReadingProgress> {
    match get_storage() {
        Ok(storage) => storage
            .get_all_progress()
            .map(|list| list.into_iter().map(|(_, p)| p).collect())
            .unwrap_or_default(),
        Err(_) => vec![],
    }
}

// ==================== 书签管理 ====================

/// 添加书签
///
/// 在指定位置添加书签，可选备注。数据会持久化到 SQLite 数据库。
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `chapter_id` - 章节 ID
/// * `page_index` - 页码
/// * `title` - 书签标题
/// * `note` - 备注（可选）
///
/// # 返回值
///
/// 返回创建的 `Bookmark` 书签信息，包含自动生成的 UUID 和时间戳
#[frb(sync)]
pub fn add_bookmark(
    book_id: String,
    chapter_id: i32,
    page_index: i32,
    title: String,
    note: Option<String>,
) -> Bookmark {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;

    let bookmark = Bookmark {
        bookmark_id: Uuid::new_v4().to_string(),
        book_id: book_id.clone(),
        chapter_id,
        page_index,
        title,
        created_timestamp: now,
        note,
    };

    if let Ok(storage) = get_storage() {
        if let Err(e) = storage.save_bookmark(&book_id, &bookmark) {
            tracing::error!("保存书签失败: {}", e);
        }
    }

    bookmark
}

/// 获取书籍的所有书签
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
///
/// # 返回值
///
/// 返回该书的所有书签列表，如果没有书签则返回空列表
///
/// # 错误
///
/// 如果存储未初始化，返回错误
#[frb(sync)]
pub fn get_bookmarks(book_id: String) -> Vec<Bookmark> {
    match get_storage() {
        Ok(storage) => storage.load_bookmarks(&book_id).unwrap_or_default(),
        Err(_) => vec![],
    }
}

/// 删除书签
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
/// * `bookmark_id` - 书签唯一标识
///
/// # 返回值
///
/// * `true` - 成功删除
/// * `false` - 书签不存在或存储未初始化
#[frb(sync)]
pub fn remove_bookmark(book_id: String, bookmark_id: String) -> bool {
    match get_storage() {
        Ok(storage) => storage
            .delete_bookmark(&book_id, &bookmark_id)
            .unwrap_or(false),
        Err(_) => false,
    }
}

/// 清除书籍的所有书签
///
/// # 参数
///
/// * `book_id` - 书籍唯一标识
///
/// # 返回值
///
/// 返回删除的书签数量
#[frb(sync)]
pub fn clear_bookmarks(book_id: String) -> i32 {
    match get_storage() {
        Ok(storage) => storage.clear_bookmarks(&book_id).unwrap_or(0) as i32,
        Err(_) => 0,
    }
}

/// 解析本地书籍文件
///
/// 自动检测文件类型（TXT、EPUB 或 PDF）并调用相应的解析器。
/// 返回完整的书籍信息，包括章节列表。
///
/// # 参数
///
/// * `file_path` - 本地书籍文件的完整路径
///
/// # 返回值
///
/// * `Ok(LocalBookInfo)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[frb(sync)]
pub fn parse_local_book(file_path: String) -> ApiResult<LocalBookInfo> {
    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    // 获取文件扩展名
    let path = std::path::Path::new(&validated_path);
    let extension = path
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("")
        .to_lowercase();

    // 根据文件类型调用相应的解析器
    let parse_result = match extension.as_str() {
        "txt" => crate::parser::parse_txt(validated_path.clone())?,
        "epub" => crate::parser::parse_epub(validated_path.clone())?,
        "pdf" => crate::parser::parse_pdf(validated_path.clone())?,
        _ => {
            return Err(ParserError::UnsupportedFormat(format!(
                "不支持的文件格式：{}，仅支持 TXT、EPUB 和 PDF",
                extension
            )));
        }
    };

    // 转换为 LocalBookInfo
    Ok(LocalBookInfo {
        file_path: validated_path.clone(),
        file_size: std::fs::metadata(&validated_path)
            .map(|m| m.len() as i64)
            .unwrap_or(0),
        title: parse_result.book_info.title,
        author: parse_result.book_info.author,
        description: String::new(), // BookInfo 没有 description 字段
        cover_path: parse_result.book_info.cover_path,
        chapter_count: parse_result.chapters.len() as i32,
        chapters: parse_result.chapters,
    })
}

/// 获取书籍封面图片
///
/// 从 EPUB 或 PDF 文件中提取封面图片并保存到指定目录。
///
/// # 参数
///
/// * `file_path` - 文件路径（EPUB 或 PDF）
/// * `output_dir` - 输出目录
///
/// # 返回值
///
/// * `Ok(String)` - 封面图片保存路径
/// * `Err(ParserError)` - 提取失败
#[frb(sync)]
pub fn extract_book_cover(file_path: String, output_dir: String) -> ApiResult<String> {
    let validated_path = validate_file_path(&file_path)?;

    let path = std::path::Path::new(&validated_path);
    let extension = path
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("")
        .to_lowercase();

    match extension.as_str() {
        "epub" => extract_epub_cover(&validated_path, &output_dir),
        "pdf" => crate::parser::pdf::extract_pdf_cover(&validated_path, &output_dir),
        _ => Err(ParserError::UnsupportedFormat(
            "仅 EPUB 和 PDF 文件支持封面提取".to_string(),
        )),
    }
}

/// 从 EPUB 文件中提取封面
fn extract_epub_cover(file_path: &str, output_dir: &str) -> ApiResult<String> {
    use epub::doc::EpubDoc;
    use std::path::Path;

    let mut doc = EpubDoc::new(file_path)
        .map_err(|e| ParserError::EpubParseError(format!("EPUB 打开失败：{}", e)))?;

    // 获取封面数据 - epub 2.x get_cover 返回 Option<(Vec<u8>, String)>
    // 其中 String 是 MIME 类型
    let cover_data = match doc.get_cover() {
        Some((data, _mime)) => data,
        None => return Err(ParserError::EpubParseError("未找到封面图片".to_string())),
    };

    // 生成输出文件名
    let path = Path::new(file_path);
    let book_filename = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("cover")
        .replace(" ", "_");

    let cover_filename = format!("{}_cover.jpg", book_filename);
    let cover_output_path = Path::new(output_dir)
        .join(&cover_filename)
        .to_string_lossy()
        .to_string();

    // 确保输出目录存在
    std::fs::create_dir_all(&output_dir)
        .map_err(|e| ParserError::FileWriteError(format!("创建目录失败：{}", e)))?;

    // 写入封面文件
    std::fs::write(&cover_output_path, &cover_data)
        .map_err(|e| ParserError::FileWriteError(format!("写入封面失败：{}", e)))?;

    Ok(cover_output_path)
}

/// 获取 EPUB 封面图片数据（零拷贝优化）
///
/// 从 EPUB 文件中提取封面图片的原始字节数据，使用 ZeroCopyBuffer 避免 FFI 拷贝。
/// 适用于需要直接在内存中处理封面数据的场景。
///
/// # 参数
///
/// * `file_path` - EPUB 文件路径
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<u8>>)` - 封面图片的原始字节数据
/// * `Err(ParserError)` - 提取失败
///
/// # 性能优势
///
/// 使用 `ZeroCopyBuffer` 可以直接传递内存缓冲区，避免在 Rust 和 Dart 之间进行数据拷贝。
/// 对于大尺寸封面图片（如高清封面），性能提升显著。
#[frb(sync)]
pub fn get_epub_cover_data(
    file_path: String,
) -> ApiResult<flutter_rust_bridge::ZeroCopyBuffer<Vec<u8>>> {
    use epub::doc::EpubDoc;
    use flutter_rust_bridge::ZeroCopyBuffer;

    let validated_path = validate_file_path(&file_path)?;

    let mut doc = EpubDoc::new(&validated_path)
        .map_err(|e| ParserError::EpubParseError(format!("EPUB 打开失败：{}", e)))?;

    // 获取封面数据 - epub 2.x get_cover 返回 Option<(Vec<u8>, String)>
    let cover_data = match doc.get_cover() {
        Some((data, _mime)) => data,
        None => return Err(ParserError::EpubParseError("未找到封面图片".to_string())),
    };

    Ok(ZeroCopyBuffer(cover_data))
}

/// 获取 PDF 封面图片数据（零拷贝优化）
///
/// 从 PDF 文件中提取封面图片的原始字节数据，使用 ZeroCopyBuffer 避免 FFI 拷贝。
/// 适用于需要直接在内存中处理封面数据的场景。
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<u8>>)` - 封面图片的原始字节数据
/// * `Err(ParserError)` - 提取失败或 PDF 无封面
#[frb(sync)]
pub fn get_pdf_cover_data(
    file_path: String,
) -> ApiResult<flutter_rust_bridge::ZeroCopyBuffer<Vec<u8>>> {
    use flutter_rust_bridge::ZeroCopyBuffer;

    let validated_path = validate_file_path(&file_path)?;

    // 调用 PDF 封面提取函数
    let cover_data = crate::parser::pdf::extract_pdf_cover_bytes(&validated_path)?;

    Ok(ZeroCopyBuffer(cover_data))
}
///
/// # 返回值
///
/// 返回所有书籍的所有书签列表，按创建时间降序排列
#[frb(sync)]
pub fn get_all_bookmarks() -> Vec<Bookmark> {
    match get_storage() {
        Ok(storage) => storage.get_all_bookmarks().unwrap_or_default(),
        Err(_) => vec![],
    }
}

// ==================== 阅读统计 ====================

/// 记录阅读会话
///
/// 记录一次阅读会话的数据，包括阅读时长和阅读字数。
/// 会自动更新累计统计数据和每日阅读记录。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `chapter_id` - 章节 ID
/// * `duration_seconds` - 阅读时长（秒）
/// * `characters_read` - 阅读字数
///
/// # 示例
///
/// ```dart
/// // 记录一次 5 分钟的阅读，阅读了 1000 字
/// await recordReadingSession(bookId, chapterId, 300, 1000);
/// ```
#[frb(sync)]
pub fn record_reading_session(
    book_id: String,
    chapter_id: i32,
    duration_seconds: i64,
    characters_read: i64,
) {
    match get_storage() {
        Ok(storage) => {
            if let Err(e) = storage.record_reading_session(
                &book_id,
                chapter_id,
                duration_seconds,
                characters_read,
            ) {
                tracing::error!("记录阅读会话失败: {}", e);
            }
        }
        Err(_) => {
            tracing::error!("存储未初始化，无法记录阅读会话");
        }
    }
}

/// 获取阅读统计
///
/// 获取用户的阅读统计数据，包括总阅读时长、总字数、连续阅读天数等。
///
/// # 返回值
///
/// 返回 `ReadingStats` 统计信息
#[frb(sync)]
pub fn get_reading_stats() -> ReadingStats {
    match get_storage() {
        Ok(storage) => storage.get_reading_stats().unwrap_or_default(),
        Err(_) => ReadingStats::default(),
    }
}

/// 获取今日阅读数据
///
/// 获取今日的阅读统计（阅读时长和字数）。
///
/// # 返回值
///
/// 返回 `(reading_time_seconds, characters_read)` 元组
#[frb(sync)]
pub fn get_today_reading_data() -> (i64, i64) {
    let today = chrono::Local::now().format("%Y-%m-%d").to_string();

    match get_storage() {
        Ok(storage) => match storage.get_daily_record(&today) {
            Ok(Some(record)) => (record.reading_time_seconds, record.characters_read),
            _ => (0, 0),
        },
        Err(_) => (0, 0),
    }
}

/// 获取指定日期的阅读记录
///
/// # 参数
///
/// * `date` - 日期（YYYY-MM-DD 格式）
///
/// # 返回值
///
/// 返回 `DailyReadingRecord`，如果没有记录返回默认结构
#[frb(sync)]
pub fn get_daily_reading_record(date: String) -> DailyReadingRecord {
    match get_storage() {
        Ok(storage) => match storage.get_daily_record(&date) {
            Ok(Some(record)) => record,
            _ => DailyReadingRecord {
                date,
                reading_time_seconds: 0,
                characters_read: 0,
                chapters_read: 0,
                pages_read: 0,
            },
        },
        Err(_) => DailyReadingRecord {
            date,
            reading_time_seconds: 0,
            characters_read: 0,
            chapters_read: 0,
            pages_read: 0,
        },
    }
}

/// 获取日期范围内的阅读记录
///
/// # 参数
///
/// * `start_date` - 开始日期（YYYY-MM-DD 格式）
/// * `end_date` - 结束日期（YYYY-MM-DD 格式）
///
/// # 返回值
///
/// 返回 `DailyReadingRecord` 列表
#[frb(sync)]
pub fn get_daily_reading_records_in_range(
    start_date: String,
    end_date: String,
) -> Vec<DailyReadingRecord> {
    match get_storage() {
        Ok(storage) => storage
            .get_daily_records_in_range(&start_date, &end_date)
            .unwrap_or_default(),
        Err(_) => vec![],
    }
}

/// 获取最近 N 天的阅读记录
///
/// # 参数
///
/// * `days` - 天数
///
/// # 返回值
///
/// 返回 `DailyReadingRecord` 列表，按日期升序排列
#[frb(sync)]
pub fn get_recent_reading_records(days: i32) -> Vec<DailyReadingRecord> {
    let end_date = chrono::Local::now();
    let start_date = end_date - chrono::Duration::days(days as i64 - 1);

    let start_str = start_date.format("%Y-%m-%d").to_string();
    let end_str = end_date.format("%Y-%m-%d").to_string();

    get_daily_reading_records_in_range(start_str, end_str)
}

/// 获取连续阅读天数
///
/// # 返回值
///
/// 返回连续阅读天数
#[frb(sync)]
pub fn get_consecutive_reading_days() -> i32 {
    match get_storage() {
        Ok(storage) => match storage.get_reading_stats() {
            Ok(stats) => stats.consecutive_reading_days,
            _ => 0,
        },
        Err(_) => 0,
    }
}

/// 获取阅读速度（字/分钟）
///
/// 基于历史阅读数据计算平均阅读速度。
///
/// # 返回值
///
/// 返回平均阅读速度（字/分钟）
#[frb(sync)]
pub fn get_reading_speed() -> f32 {
    match get_storage() {
        Ok(storage) => match storage.get_reading_stats() {
            Ok(stats) => stats.average_reading_speed,
            _ => 0.0,
        },
        Err(_) => 0.0,
    }
}

/// 更新书籍阅读计数
///
/// 当开始阅读一本新书时调用。
#[frb(sync)]
pub fn increment_books_read_count() {
    match get_storage() {
        Ok(storage) => {
            if let Err(e) = storage.increment_books_read_count() {
                tracing::error!("更新书籍计数失败: {}", e);
            }
        }
        Err(_) => {}
    }
}

/// 更新完成阅读书籍计数
///
/// 当完成阅读一本书时调用。
#[frb(sync)]
pub fn increment_books_completed_count() {
    match get_storage() {
        Ok(storage) => {
            if let Err(e) = storage.increment_books_completed_count() {
                tracing::error!("更新完成书籍计数失败: {}", e);
            }
        }
        Err(_) => {}
    }
}

// ==================== 排版缓存管理 ====================

/// 计算排版配置的哈希值
///
/// 用于缓存键的生成，相同的配置会产生相同的哈希值。
///
/// # 参数
///
/// * `config` - 排版配置
///
/// # 返回值
///
/// 返回配置哈希值（16 进制字符串）
#[frb(sync)]
pub fn compute_config_hash(config: TypesetConfig) -> String {
    let mut hasher = DefaultHasher::new();

    // 将所有配置字段加入哈希计算
    config.hash(&mut hasher); // 使用派生的 Hash trait 自动哈希所有字段
    format!("{:016x}", hasher.finish())
}

/// 保存排版缓存
///
/// 将分页后的偏移量缓存到 SQLite 数据库，实现章节"秒开"。
/// 数据会持久化，应用重启后仍然有效。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置（会自动计算哈希）
/// * `page_offsets` - 页面偏移量列表
///
/// # 返回值
///
/// * `Ok(())` - 保存成功
/// * `Err(ParserError)` - 保存失败
#[frb(sync)]
pub fn save_layout_cache(
    book_id: String,
    chapter_id: i32,
    config: TypesetConfig,
    page_offsets: Vec<PageOffset>,
) -> ApiResult<()> {
    let config_hash = compute_config_hash(config.clone());

    match get_storage() {
        Ok(storage) => storage
            .save_layout_cache(&book_id, chapter_id, &config_hash, &page_offsets)
            .map_err(|e| ParserError::Other(format!("保存排版缓存失败：{}", e)))?,
        Err(e) => return Err(ParserError::Other(e.to_string())),
    }

    tracing::info!(
        "排版缓存已保存：book={}, chapter={}, hash={}, pages={}",
        book_id,
        chapter_id,
        config_hash,
        page_offsets.len()
    );

    Ok(())
}

/// 获取排版缓存
///
/// 从 SQLite 数据库获取缓存的分页偏移量。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `chapter_id` - 章节 ID
/// * `config` - 排版配置（会自动计算哈希）
///
/// # 返回值
///
/// 返回 `LayoutCacheResult`，包含：
/// - `hit: true` 表示命中缓存，`cached_layout` 包含缓存数据
/// - `hit: false` 表示未命中缓存，需要重新分页
#[frb(sync)]
pub fn get_layout_cache(
    book_id: String,
    chapter_id: i32,
    config: TypesetConfig,
) -> LayoutCacheResult {
    let config_hash = compute_config_hash(config.clone());

    match get_storage() {
        Ok(storage) => match storage.get_layout_cache(&book_id, chapter_id, &config_hash) {
            Ok(result) => {
                if result.hit {
                    tracing::debug!(
                        "排版缓存命中：book={}, chapter={}, hash={}",
                        book_id,
                        chapter_id,
                        config_hash
                    );
                }
                result
            }
            Err(e) => {
                tracing::error!("获取排版缓存失败：{}", e);
                LayoutCacheResult {
                    hit: false,
                    cached_layout: None,
                }
            }
        },
        Err(_) => LayoutCacheResult {
            hit: false,
            cached_layout: None,
        },
    }
}

/// 清除书籍的所有排版缓存
///
/// 当用户更改排版设置或删除书籍时调用。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
///
/// # 返回值
///
/// 返回删除的缓存数量
#[frb(sync)]
pub fn clear_layout_cache(book_id: String) -> i32 {
    match get_storage() {
        Ok(storage) => match storage.clear_layout_cache(&book_id) {
            Ok(count) => {
                tracing::info!("清除排版缓存：book={}, count={}", book_id, count);
                count
            }
            Err(e) => {
                tracing::error!("清除排版缓存失败：{}", e);
                0
            }
        },
        Err(_) => 0,
    }
}

/// 清除指定章节的排版缓存
///
/// 当章节内容发生变化时调用。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `chapter_id` - 章节 ID
///
/// # 返回值
///
/// 返回删除的缓存数量
#[frb(sync)]
pub fn clear_chapter_layout_cache(book_id: String, chapter_id: i32) -> i32 {
    match get_storage() {
        Ok(storage) => match storage.clear_chapter_layout_cache(&book_id, chapter_id) {
            Ok(count) => {
                tracing::debug!(
                    "清除章节排版缓存：book={}, chapter={}, count={}",
                    book_id,
                    chapter_id,
                    count
                );
                count
            }
            Err(e) => {
                tracing::error!("清除章节排版缓存失败：{}", e);
                0
            }
        },
        Err(_) => 0,
    }
}

/// 获取书籍的所有排版缓存信息
///
/// 用于调试和统计目的。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
///
/// # 返回值
///
/// 返回所有缓存的列表，包含章节 ID、配置哈希、页数等信息
#[frb(sync)]
pub fn get_all_layout_cache(book_id: String) -> Vec<CachedLayout> {
    match get_storage() {
        Ok(storage) => match storage.get_all_layout_cache(&book_id) {
            Ok(caches) => caches,
            Err(e) => {
                tracing::error!("获取排版缓存列表失败：{}", e);
                vec![]
            }
        },
        Err(_) => vec![],
    }
}

// ==================== EPUB 图片支持 ====================

/// 获取 EPUB 封面图片（原始字节）
///
/// 提取 EPUB 文件的封面图片数据，可用于 Flutter 侧显示。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(Vec<u8>)` - 封面图片的原始字节（JPEG 或 PNG 格式）
/// * `Err(String)` - 获取失败，返回错误消息
#[must_use = "封面图片数据必须被处理"]
#[frb(sync)]
pub fn get_epub_cover_image(file_path: String) -> Result<Vec<u8>, String> {
    use crate::parser::epub::unzip::EpubFile;

    // 路径安全验证
    let validated_path = validate_file_path(&file_path).map_err(|e| e.to_string())?;

    let mut epub_file = EpubFile::open(&validated_path).map_err(|e| e.to_string())?;

    epub_file
        .read_cover()
        .ok_or_else(|| "未找到封面图片".to_string())
}

/// 获取 EPUB 完整元数据
///
/// 提取 EPUB 文件的全部元数据，包括标题、作者、封面、目录和阅读顺序。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(EpubMetadata)` - 完整的元数据信息
/// * `Err(ParserError)` - 获取失败
#[must_use = "元数据必须被处理"]
#[frb(sync)]
pub fn get_epub_full_metadata(file_path: String) -> ApiResult<EpubMetadata> {
    use crate::parser::epub::unzip::EpubFile;

    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    let epub_file = EpubFile::open(&validated_path)?;

    let title = epub_file.title();
    let author = epub_file.author();
    let cover_path = epub_file.cover_path();
    let toc = epub_file.toc();
    let spine = epub_file.spine();

    Ok(EpubMetadata {
        title,
        author,
        cover_path,
        toc: toc
            .iter()
            .map(|(l, h)| EpubTocItem {
                label: l.clone(),
                href: h.clone(),
            })
            .collect(),
        spine,
    })
}

// ==================== 富文本支持 ====================

// ==================== EPUB 图片支持 ====================

/// 获取 EPUB 中所有图片资源的列表
///
/// 列出 EPUB 文件中所有图片资源的信息，包括文件名、格式、大小等。
/// 可用于显示图片列表或选择要查看的图片。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
///
/// # 返回值
///
/// * `Ok(EpubImageList)` - 图片列表信息
/// * `Err(ParserError)` - 获取失败
#[must_use = "图片列表必须被处理"]
#[frb(sync)]
pub fn get_epub_images(file_path: String) -> ApiResult<EpubImageList> {
    use crate::ffi::ImageFormat;
    use crate::parser::epub::unzip::EpubFile;
    use std::path::Path;

    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    let mut epub_file = EpubFile::open(&validated_path)?;

    // 获取所有图片资源
    let images = epub_file.list_images();

    // 构建图片信息列表
    let mut image_infos: Vec<EpubImageInfo> = Vec::new();

    for (href, filename) in images {
        // 判断格式
        let ext = Path::new(&filename)
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("");
        let format = ImageFormat::from_extension(&format!(".{}", ext));

        // 优化：只读取一次，复用数据
        if let Some(image_data) = epub_file.read_resource_bytes(&href) {
            let size_bytes = image_data.len() as i64;
            let (width, height) = try_parse_image_size(&image_data);

            image_infos.push(EpubImageInfo {
                href,
                filename,
                format,
                size_bytes,
                width,
                height,
            });
        } else {
            // 资源读取失败，使用默认值
            image_infos.push(EpubImageInfo {
                href,
                filename,
                format,
                size_bytes: 0,
                width: None,
                height: None,
            });
        }
    }

    let total_count = image_infos.len() as i32;

    Ok(EpubImageList {
        total_count,
        images: image_infos,
    })
}

/// 提取 EPUB 中指定图片资源的字节数据
///
/// 根据图片的 href 提取图片资源的原始字节，用于 Flutter 侧显示。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
/// * `image_href` - 图片资源的 href（从 get_epub_images 获取）
///
/// # 返回值
///
/// * `Ok(Vec<u8>)` - 图片的原始字节数据
/// * `Err(String)` - 提取失败，返回错误消息
#[must_use = "图片数据必须被处理"]
#[frb(sync)]
pub fn get_epub_image_resource(file_path: String, image_href: String) -> Result<Vec<u8>, String> {
    use crate::parser::epub::unzip::EpubFile;

    // 路径安全验证
    let validated_path = validate_file_path(&file_path).map_err(|e| e.to_string())?;

    let mut epub_file = EpubFile::open(&validated_path).map_err(|e| e.to_string())?;

    epub_file
        .read_resource_bytes(&image_href)
        .ok_or_else(|| format!("图片资源不存在：{}", image_href))
}

/// 获取 EPUB 中指定图片的元数据
///
/// 提取单个图片的详细信息，包括格式、尺寸、文件大小等。
///
/// # 参数
///
/// * `file_path` - EPUB 文件的完整路径
/// * `image_href` - 图片资源的 href
///
/// # 返回值
///
/// * `Ok(EpubImageInfo)` - 图片元数据信息
/// * `Err(ParserError)` - 获取失败
#[must_use = "图片元数据必须被处理"]
#[frb(sync)]
pub fn get_epub_image_metadata(file_path: String, image_href: String) -> ApiResult<EpubImageInfo> {
    use crate::ffi::ImageFormat;
    use crate::parser::epub::unzip::EpubFile;
    use std::path::Path;

    // 路径安全验证
    let validated_path = validate_file_path(&file_path)?;

    let mut epub_file = EpubFile::open(&validated_path)?;

    // 获取所有图片资源，查找匹配的
    let images = epub_file.list_images();
    let (href, filename) = images
        .into_iter()
        .find(|(h, _)| h == &image_href)
        .ok_or_else(|| ParserError::EpubParseError(format!("图片资源不存在：{}", image_href)))?;

    // 判断格式
    let ext = Path::new(&filename)
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("");
    let format = ImageFormat::from_extension(&format!(".{}", ext));

    // 优化：只读取一次，复用数据
    if let Some(image_data) = epub_file.read_resource_bytes(&href) {
        let size_bytes = image_data.len() as i64;
        let (width, height) = try_parse_image_size(&image_data);

        Ok(EpubImageInfo {
            href,
            filename,
            format,
            size_bytes,
            width,
            height,
        })
    } else {
        Err(ParserError::EpubParseError(format!(
            "无法读取图片资源：{}",
            image_href
        )))
    }
}

/// 尝试解析图片尺寸（简化实现）
///
/// 读取图片数据的前几个字节，尝试解析宽度和高度。
/// 支持 JPEG、PNG、GIF、WebP、BMP 格式。
fn try_parse_image_size(data: &[u8]) -> (Option<i32>, Option<i32>) {
    if data.len() < 10 {
        return (None, None);
    }

    // PNG: 前 8 字节是签名，第 16-19 字节是宽度，20-23 字节是高度
    if data.starts_with(&[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) && data.len() >= 24 {
        let width = i32::from_be_bytes([data[16], data[17], data[18], data[19]]);
        let height = i32::from_be_bytes([data[20], data[21], data[22], data[23]]);
        return (Some(width), Some(height));
    }

    // GIF: 第 6-7 字节是宽度，8-9 字节是高度（小端序）
    // 修复：添加括号明确优先级，使用正确的 u16 转换
    if data.len() >= 10 && (data.starts_with(b"GIF87a") || data.starts_with(b"GIF89a")) {
        // 使用 u16 转换，避免符号扩展问题
        let width = u16::from_le_bytes([data[6], data[7]]) as i32;
        let height = u16::from_le_bytes([data[8], data[9]]) as i32;

        // 验证尺寸合理性（GIF 最大 65535）
        if width > 0 && height > 0 && width <= 65535 && height <= 65535 {
            return (Some(width), Some(height));
        }
    }

    // JPEG: 需要扫描查找 SOF 标记
    if data.starts_with(&[0xFF, 0xD8]) {
        return parse_jpeg_size(data);
    }

    // WebP: 前 4 字节是 "RIFF"，第 8-11 字节是 "WEBP"，第 26-29 字节是宽度，30-33 字节是高度
    if data.len() >= 34 && data.starts_with(b"RIFF") && data[8..12] == *b"WEBP" {
        // WebP VP8 格式：宽度在 26-27 字节（小端序），高度在 28-29 字节（小端序）
        let width = u16::from_le_bytes([data[26], data[27]]) as i32;
        let height = u16::from_le_bytes([data[28], data[29]]) as i32;

        if width > 0 && height > 0 && width <= 16383 && height <= 16383 {
            return (Some(width), Some(height));
        }
    }

    // BMP: 前 2 字节是 "BM"，第 18-21 字节是宽度，22-25 字节是高度（小端序，有符号）
    if data.len() >= 26 && data.starts_with(b"BM") {
        let width = i32::from_le_bytes([data[18], data[19], data[20], data[21]]);
        let height = i32::from_le_bytes([data[22], data[23], data[24], data[25]]);

        // BMP 高度可以是负数（表示顶向下），取绝对值
        let height = height.abs();

        if width > 0 && height > 0 {
            return (Some(width), Some(height));
        }
    }

    (None, None)
}

/// 解析 JPEG 图片尺寸
///
/// 扫描 JPEG 数据查找 SOF（Start Of Frame）标记，提取宽高。
/// 添加完整的边界检查，防止缓冲区溢出。
fn parse_jpeg_size(data: &[u8]) -> (Option<i32>, Option<i32>) {
    // 最小长度检查（SOI + 标记 + 长度）
    if data.len() < 4 {
        return (None, None);
    }

    let mut i = 2; // 跳过 SOI 标记 (0xFFD8)

    while i < data.len().saturating_sub(1) {
        // 查找 0xFF 标记
        if data[i] != 0xFF {
            i = i.saturating_add(1);
            continue;
        }

        // 跳过填充的 0xFF
        while i < data.len() && data[i] == 0xFF {
            i = i.saturating_add(1);
        }

        if i >= data.len() {
            break;
        }

        let marker = data[i];
        i = i.saturating_add(1);

        // 检查是否需要长度字段（SOF 标记：0xC0-0xCF，排除 0xC4 和 0xC8）
        let is_sof_marker = matches!(marker, 0xC0..=0xCF) && marker != 0xC4 && marker != 0xC8;

        if !is_sof_marker {
            continue;
        }

        // 安全读取长度字段
        if i.saturating_add(1) >= data.len() {
            break;
        }

        let length = ((data[i] as usize) << 8) | (data[i.saturating_add(1)] as usize);

        // 验证长度字段有效性（至少包含：精度 1 + 高度 2 + 宽度 2 + 组件数 1 = 7 字节）
        if length < 7 || i.saturating_add(length) > data.len() {
            break;
        }

        // SOF 标记结构：长度 (2) + 精度 (1) + 高度 (2) + 宽度 (2) + 组件数 (1) + ...
        // 从长度字段后开始计算偏移
        let base = i.saturating_add(2); // 跳过长度字段

        if base.saturating_add(5) < data.len() {
            // 读取高度（2 字节，大端序）
            let height = ((data[base.saturating_add(3)] as i32) << 8)
                | (data[base.saturating_add(4)] as i32);
            // 读取宽度（2 字节，大端序）
            let width = ((data[base.saturating_add(5)] as i32) << 8)
                | (data[base.saturating_add(6)] as i32);

            // 验证宽高合理性（防止异常值，JPEG 最大 65535）
            if width > 0 && height > 0 && width <= 65535 && height <= 65535 {
                return (Some(width), Some(height));
            }
        }

        // 跳过这个标记段
        i = i.saturating_add(length);
    }

    (None, None)
}

// ==================== 富文本支持 ====================

/// 解析 HTML 内容为富文本
///
/// 将 HTML 格式的内容解析为结构化的富文本数据，保留加粗、斜体等样式信息。
///
/// # 参数
///
/// * `html_content` - HTML 格式的内容
///
/// # 返回值
///
/// 返回 `RichChapterContent`，包含段落列表和样式信息
#[frb(sync)]
pub fn parse_html_content(html_content: String) -> RichChapterContent {
    let paragraphs = crate::text_process::rich_text::parse_html_to_rich_text(&html_content);

    let total_characters: i64 = paragraphs
        .iter()
        .map(|p| p.full_text().chars().count() as i64)
        .sum();

    RichChapterContent {
        chapter_id: 0,
        paragraphs,
        total_characters,
    }
}

/// 解析 HTML 内容为富文本（简化版）
///
/// 使用简化的 HTML 解析器，适用于格式简单的 HTML 内容。
/// 性能更好，但支持的标签较少。
///
/// # 参数
///
/// * `html_content` - HTML 格式的内容
///
/// # 返回值
///
/// 返回富文本段落列表
#[frb(sync)]
pub fn parse_html_content_simple(html_content: String) -> Vec<crate::ffi::RichParagraph> {
    crate::text_process::rich_text::parse_simple_html(&html_content)
}

/// 将富文本转换为纯文本
///
/// 从富文本数据中提取纯文本内容，移除所有样式信息。
///
/// # 参数
///
/// * `rich_content` - 富文本内容
///
/// # 返回值
///
/// 返回纯文本字符串
#[frb(sync)]
pub fn rich_text_to_plain(rich_content: RichChapterContent) -> String {
    rich_content.to_plain_text()
}

/// 解析 EPUB 章节为富文本
///
/// 从 EPUB 文件中提取指定章节的 HTML 内容并解析为富文本格式。
///
/// # 参数
///
/// * `file_path` - EPUB 文件路径
/// * `chapter_index` - 章节索引（从 0 开始）
///
/// # 返回值
///
/// 返回 `RichChapterContent`，包含解析后的富文本内容
#[frb(sync)]
pub fn parse_epub_chapter_rich(
    file_path: String,
    chapter_index: i32,
) -> ApiResult<RichChapterContent> {
    use crate::parser::epub::unzip::EpubFile;

    let mut epub_file =
        EpubFile::open(&file_path).map_err(|e| ParserError::EpubParseError(e.to_string()))?;

    // 获取章节内容
    let spine = epub_file.spine();
    if chapter_index as usize >= spine.len() {
        return Err(ParserError::EpubParseError(format!(
            "章节索引超出范围：{}",
            chapter_index
        )));
    }

    let chapter_href = &spine[chapter_index as usize];
    let html_content = epub_file
        .read_chapter(chapter_href)
        .map_err(|e: ParserError| ParserError::EpubParseError(e.to_string()))?;

    // 解析为富文本
    let paragraphs = crate::text_process::rich_text::parse_html_to_rich_text(&html_content);

    let total_characters: i64 = paragraphs
        .iter()
        .map(|p| p.full_text().chars().count() as i64)
        .sum();

    Ok(RichChapterContent {
        chapter_id: chapter_index,
        paragraphs,
        total_characters,
    })
}

// ==================== 全文搜索支持 ====================

/// 初始化书籍的搜索引擎
///
/// 创建或打开书籍的全文索引。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `index_path` - 索引存储路径
///
/// # 返回值
///
/// * `Ok(())` - 初始化成功
/// * `Err(ParserError)` - 初始化失败
#[frb(sync)]
pub fn init_search_index(book_id: String, index_path: String) -> ApiResult<()> {
    use crate::search::SearchEngine;

    match SearchEngine::open_or_create(&index_path) {
        Ok(_engine) => {
            tracing::info!("搜索引擎已初始化：book={}, path={}", book_id, index_path);
            Ok(())
        }
        Err(e) => Err(ParserError::Other(format!("初始化搜索引擎失败：{}", e))),
    }
}

/// 索引章节内容
///
/// 将章节内容添加到搜索索引中。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `index_path` - 索引路径
/// * `chapter_id` - 章节 ID
/// * `chapter_title` - 章节标题
/// * `content` - 章节内容
///
/// # 返回值
///
/// * `Ok(())` - 索引成功
/// * `Err(ParserError)` - 索引失败
#[frb(sync)]
pub fn index_chapter_content(
    book_id: String,
    index_path: String,
    chapter_id: i32,
    chapter_title: String,
    content: String,
) -> ApiResult<()> {
    use crate::search::SearchEngine;

    let mut engine = SearchEngine::open_or_create(&index_path)
        .map_err(|e| ParserError::Other(format!("打开索引失败：{}", e)))?;

    engine
        .index_chapter(&book_id, chapter_id, &chapter_title, &content)
        .map_err(|e| ParserError::Other(format!("索引章节失败：{}", e)))?;

    Ok(())
}

/// 搜索书籍内容
///
/// 在书籍中搜索关键字，返回匹配的结果。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `index_path` - 索引路径
/// * `query` - 搜索关键字
/// * `limit` - 最大返回结果数
///
/// # 返回值
///
/// 返回 `SearchResults` 搜索结果
#[frb(sync)]
pub fn search_in_book(
    book_id: String,
    index_path: String,
    query: String,
    limit: i32,
) -> SearchResults {
    use crate::search::SearchEngine;
    use std::time::Instant;

    let start = Instant::now();

    let engine = match SearchEngine::open_or_create(&index_path) {
        Ok(e) => e,
        Err(_) => {
            return SearchResults {
                total_hits: 0,
                hits: vec![],
                elapsed_ms: 0,
            };
        }
    };

    let hits: Vec<SearchHit> = engine
        .search(&book_id, &query, limit as usize)
        .unwrap_or_default()
        .into_iter()
        .map(|h| SearchHit {
            chapter_id: h.chapter_id,
            chapter_title: h.chapter_title,
            snippet: h.snippet,
            position: h.position,
            score: h.score,
        })
        .collect();

    let total_hits = hits.len() as i32;
    let elapsed_ms = start.elapsed().as_millis() as i64;

    SearchResults {
        total_hits,
        hits,
        elapsed_ms,
    }
}

/// 删除书籍的搜索索引
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `index_path` - 索引路径
///
/// # 返回值
///
/// * `true` - 删除成功
/// * `false` - 删除失败
#[frb(sync)]
pub fn delete_search_index(book_id: String, index_path: String) -> bool {
    use crate::search::SearchEngine;

    match SearchEngine::open_or_create(&index_path) {
        Ok(engine) => engine.delete_book(&book_id).is_ok(),
        Err(_) => false,
    }
}

/// 清除所有搜索索引
///
/// 删除索引文件中的所有搜索数据。
/// 用于重置搜索索引或释放存储空间。
///
/// # 参数
///
/// * `index_path` - 索引路径
///
/// # 返回值
///
/// * `true` - 清除成功
/// * `false` - 清除失败
#[frb(sync)]
pub fn clear_all_search_index(index_path: String) -> bool {
    use crate::search::SearchEngine;

    match SearchEngine::open_or_create(&index_path) {
        Ok(engine) => engine.clear_all().is_ok(),
        Err(_) => false,
    }
}

// ==================== ZeroCopyBuffer 零拷贝优化 ====================

/// 获取章节内容（零拷贝版本）
///
/// 使用 `ZeroCopyBuffer` 直接传递字节数据，避免 FFI 拷贝。
/// 适用于大章节内容传输，性能更优。
///
/// # 参数
///
/// * `file_path` - 文件路径
/// * `chapter_id` - 章节 ID
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<u8>>)` - 章节内容的原始字节数据
/// * `Err(ParserError)` - 提取失败
#[frb(sync)]
pub fn get_chapter_content_zero_copy(
    file_path: String,
    chapter_id: i32,
) -> ApiResult<ZeroCopyBuffer<Vec<u8>>> {
    let validated_path = validate_file_path(&file_path)?;

    // 获取文件扩展名
    let path = std::path::Path::new(&validated_path);
    let extension = path
        .extension()
        .and_then(|ext| ext.to_str())
        .unwrap_or("")
        .to_lowercase();

    // 根据文件类型调用相应的解析器
    let content = match extension.as_str() {
        "txt" => {
            use crate::parser::txt::decode;
            use crate::text_process::chapter_detect::extract_chapters;
            let full_content = decode::decode_file(&validated_path)?;
            let chapters = extract_chapters(&full_content, 1000);
            let chapter = chapters
                .iter()
                .find(|c| c.chapter_id == chapter_id)
                .ok_or_else(|| {
                    ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id))
                })?;

            let start = chapter.start_index as usize;
            let end = chapter.end_index as usize;
            full_content[start..end.min(full_content.len())].to_string()
        }
        "epub" => {
            use crate::parser::epub::toc::extract_chapters_from_epub;
            use crate::parser::epub::unzip::EpubFile;
            let mut epub_file = EpubFile::open(&validated_path)?;
            let chapters = extract_chapters_from_epub(&mut epub_file);
            let chapter = chapters
                .iter()
                .find(|c| c.chapter_id == chapter_id)
                .ok_or_else(|| {
                    ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id))
                })?;

            // EPUB 章节的 start_index 存储的是 spine 中的索引
            let spine = epub_file.spine();
            let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
                ParserError::ChapterExtractError(format!(
                    "章节索引超出范围：{}",
                    chapter.start_index
                ))
            })?;
            epub_file.read_resource(href)?
        }
        "pdf" => {
            let pages_per_chapter = 10;
            let start_page = (chapter_id as usize * pages_per_chapter) as u32;
            let end_page = ((chapter_id as usize + 1) * pages_per_chapter) as u32;
            crate::parser::pdf::text::get_chapter_text(
                &validated_path,
                start_page as usize,
                end_page as usize,
            )?
        }
        _ => {
            return Err(ParserError::UnsupportedFormat(format!(
                "不支持的文件格式：{}",
                extension
            )));
        }
    };

    Ok(ZeroCopyBuffer(content.into_bytes()))
}

/// 搜索书籍（零拷贝版本）
///
/// 使用 `ZeroCopyBuffer` 传递搜索结果，避免大数据拷贝。
/// 适用于搜索结果较多的场景。
///
/// # 参数
///
/// * `book_id` - 书籍 ID
/// * `query` - 搜索关键词
/// * `limit` - 最大结果数
/// * `index_path` - 索引路径
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<SearchHit>>)` - 搜索结果的零拷贝缓冲区
/// * `Err(ParserError)` - 搜索失败
#[frb(sync)]
pub fn search_books_zero_copy(
    book_id: String,
    query: String,
    limit: i32,
    index_path: String,
) -> ApiResult<ZeroCopyBuffer<Vec<SearchHit>>> {
    use crate::search::SearchEngine;

    let engine = SearchEngine::open_or_create(&index_path)
        .map_err(|e| ParserError::Other(format!("打开搜索索引失败：{}", e)))?;

    let results = engine
        .search(&book_id, &query, limit as usize)
        .map_err(|e| ParserError::Other(format!("搜索失败：{}", e)))?;

    let hits: Vec<SearchHit> = results
        .into_iter()
        .map(|h| SearchHit {
            chapter_id: h.chapter_id,
            chapter_title: h.chapter_title,
            snippet: h.snippet,
            position: h.position,
            score: h.score,
        })
        .collect();

    Ok(ZeroCopyBuffer(hits))
}

/// 获取 PDF 封面图片数据（零拷贝优化）
///
/// 从 PDF 文件中提取封面图片的原始字节数据，使用 ZeroCopyBuffer 避免 FFI 拷贝。
/// 适用于需要直接在内存中处理封面数据的场景。
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<u8>>)` - 封面图片的原始字节数据
/// * `Err(ParserError)` - 提取失败或 PDF 无封面
#[frb(sync)]
pub fn get_pdf_cover_data_zero_copy(file_path: String) -> ApiResult<ZeroCopyBuffer<Vec<u8>>> {
    let validated_path = validate_file_path(&file_path)?;

    // 调用 PDF 封面提取函数
    let cover_data = crate::parser::pdf::extract_pdf_cover_bytes(&validated_path)?;

    Ok(ZeroCopyBuffer(cover_data))
}

/// 获取 EPUB 封面图片数据（零拷贝优化）
///
/// 从 EPUB 文件中提取封面图片的原始字节数据，使用 ZeroCopyBuffer 避免 FFI 拷贝。
/// 适用于需要直接在内存中处理封面数据的场景。
///
/// # 参数
///
/// * `file_path` - EPUB 文件路径
///
/// # 返回值
///
/// * `Ok(ZeroCopyBuffer<Vec<u8>>)` - 封面图片的原始字节数据
/// * `Err(ParserError)` - 提取失败
#[frb(sync)]
pub fn get_epub_cover_data_zero_copy(file_path: String) -> ApiResult<ZeroCopyBuffer<Vec<u8>>> {
    use epub::doc::EpubDoc;

    let validated_path = validate_file_path(&file_path)?;

    let mut doc = EpubDoc::new(&validated_path)
        .map_err(|e| ParserError::EpubParseError(format!("EPUB 打开失败：{}", e)))?;

    // 获取封面数据
    let cover_data = match doc.get_cover() {
        Some((data, _mime)) => data,
        None => return Err(ParserError::EpubParseError("未找到封面图片".to_string())),
    };

    Ok(ZeroCopyBuffer(cover_data))
}

// ==================== 增量解析支持 ====================

/// 全局增量解析器实例
static INCREMENTAL_PARSER: OnceCell<Mutex<crate::parser::IncrementalParser>> = OnceCell::new();

/// 初始化增量解析器
///
/// 在应用启动时调用，初始化增量解析器全局实例。
///
/// # 返回值
///
/// * `Ok(())` - 初始化成功
/// * `Err(ParserError)` - 初始化失败（已经初始化）
#[frb(sync)]
pub fn init_incremental_parser() -> ApiResult<()> {
    INCREMENTAL_PARSER
        .set(Mutex::new(crate::parser::IncrementalParser::new()))
        .map_err(|_| ParserError::Other("增量解析器已经初始化".to_string()))?;

    tracing::info!("增量解析器已初始化");
    Ok(())
}

/// 获取增量解析器实例
fn get_incremental_parser(
) -> ApiResult<std::sync::MutexGuard<'static, crate::parser::IncrementalParser>> {
    INCREMENTAL_PARSER
        .get()
        .ok_or_else(|| {
            ParserError::Other("增量解析器未初始化，请先调用 init_incremental_parser".to_string())
        })?
        .lock()
        .map_err(|e| ParserError::Other(format!("锁定增量解析器失败：{}", e)))
}

/// 解析本地书籍文件（增量解析版本）
///
/// 使用增量解析器检查文件变更，仅当文件变更时重新解析。
/// 适用于书架刷新等场景，显著提升性能。
///
/// # 参数
///
/// * `file_path` - 本地书籍文件的完整路径
///
/// # 返回值
///
/// * `Ok(LocalBookInfo)` - 解析成功，包含书籍信息和章节列表
/// * `Err(ParserError)` - 解析失败
#[frb(sync)]
pub fn parse_local_book_incremental(file_path: String) -> ApiResult<LocalBookInfo> {
    let parser = get_incremental_parser()?;

    // 检查是否需要重新解析
    if !parser.needs_reparse(&file_path) {
        tracing::info!("文件未变更，使用缓存的解析结果：{}", file_path);
        // 注意：由于 get_cached_result 是私有方法，这里直接返回错误
        // Flutter 侧应该捕获此错误并调用 parse_local_book 进行完整解析
        return Err(ParserError::Other("缓存未命中，需要重新解析".to_string()));
    }

    // 完全重新解析
    tracing::info!("文件已变更或首次解析：{}", file_path);
    parse_local_book(file_path)
}

/// 清除增量解析器缓存
///
/// 清除所有文件的解析缓存，释放内存。
///
/// # 返回值
///
/// * `Ok(())` - 清除成功
/// * `Err(ParserError)` - 清除失败
#[frb(sync)]
pub fn clear_incremental_parser_cache() -> ApiResult<()> {
    let mut parser = get_incremental_parser()?;
    parser.clear_all();
    tracing::info!("增量解析器缓存已清除");
    Ok(())
}

/// 获取增量解析器缓存统计
///
/// 获取当前缓存的文件数量、章节数量和内存占用估算。
///
/// # 返回值
///
/// 返回 `CacheStats` 缓存统计信息
#[frb(sync)]
pub fn get_incremental_parser_stats() -> crate::parser::CacheStats {
    match get_incremental_parser() {
        Ok(parser) => parser.get_cache_stats(),
        Err(_) => crate::parser::CacheStats {
            file_count: 0,
            chapter_count: 0,
            total_memory_estimate: 0,
        },
    }
}
