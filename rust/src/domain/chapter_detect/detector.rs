//! TXT 章节检测器 — 用户自定义规则优先，内置规则兜底

use std::collections::HashMap;
use std::sync::LazyLock;
use std::sync::Mutex;

use regex::Regex;
use sqlx::SqlitePool;

use crate::common::AppError;
use crate::domain::chapter::Chapter;
use crate::domain::chapter_detect::constants::BUILTIN_DETECT_PATTERNS;
use crate::domain::chapter_detect::models::{
    ChapterDetectConfig, CompiledChapterDetectConfig, CompiledPattern,
};
use crate::domain::chapter_detect::repo;

/// 预编译配置缓存（scope → CompiledConfig）
static COMPILED_CONFIG_CACHE: LazyLock<Mutex<HashMap<String, CompiledChapterDetectConfig>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// 编译 DB 配置为预编译形式（过滤 disabled + 编译 regex）
fn compile_config(config: &ChapterDetectConfig) -> CompiledChapterDetectConfig {
    let patterns: Vec<CompiledPattern> = config
        .patterns
        .iter()
        .filter(|p| p.enabled)
        .filter_map(|p| {
            Regex::new(&p.regex).ok().map(|re| CompiledPattern {
                pattern_name: p.pattern_name.clone(),
                regex: re,
            })
        })
        .collect();

    CompiledChapterDetectConfig {
        scope: config.scope.clone(),
        patterns,
    }
}

/// 编译内置规则列表
fn compile_builtin_patterns() -> Vec<CompiledPattern> {
    BUILTIN_DETECT_PATTERNS
        .iter()
        .filter(|p| p.enabled)
        .filter_map(|p| {
            Regex::new(&p.regex).ok().map(|re| CompiledPattern {
                pattern_name: p.pattern_name.clone(),
                regex: re,
            })
        })
        .collect()
}

/// 使用单个 pattern 尝试提取章节
fn try_pattern(content: &str, pattern: &CompiledPattern, book_id: &str) -> Vec<Chapter> {
    let content_len = content.len() as i64;
    let mut chapters: Vec<Chapter> = Vec::new();

    for cap in pattern.regex.captures_iter(content) {
        if let Some(m) = cap.get(0) {
            let start = m.start() as i64;

            // 更新上一章的结束位置
            if let Some(last) = chapters.last_mut() {
                last.end_index = start;
            }

            let chapter_index = chapters.len() as i64;
            let title = m.as_str().trim().to_string();

            chapters.push(Chapter::new(
                book_id,
                &title,
                chapter_index,
                0,
                start,
                content_len,
            ));
        }
    }

    chapters
}

/// 从 DB 加载并编译 scope 配置（带缓存）
async fn load_compiled_config(
    pool: &SqlitePool,
    scope: &str,
) -> Result<CompiledChapterDetectConfig, AppError> {
    // 检查缓存
    {
        let cache = COMPILED_CONFIG_CACHE.lock().unwrap();
        if let Some(config) = cache.get(scope) {
            return Ok(config.clone());
        }
    }

    // 从 DB 加载
    let db_config = repo::load_scope_config(pool, scope).await?;
    let compiled = match db_config {
        Some(config) => compile_config(&config),
        None => CompiledChapterDetectConfig {
            scope: scope.to_string(),
            patterns: vec![],
        },
    };

    // 写入缓存
    {
        let mut cache = COMPILED_CONFIG_CACHE.lock().unwrap();
        cache.insert(scope.to_string(), compiled.clone());
    }

    Ok(compiled)
}

/// 使指定 scope 的缓存失效
pub fn invalidate_cache(scope: &str) {
    let mut cache = COMPILED_CONFIG_CACHE.lock().unwrap();
    cache.remove(scope);
}

/// 使用内置规则检测章节（同步，用于初始解析等无需 DB 的场景）
pub fn detect_with_builtin_only(content: &str, book_id: &str) -> Vec<Chapter> {
    let builtin_patterns = compile_builtin_patterns();
    for pattern in &builtin_patterns {
        let chapters = try_pattern(content, pattern, book_id);
        if !chapters.is_empty() {
            return chapters;
        }
    }
    // 全部未命中 → 整文件当一章
    vec![Chapter::new(
        book_id,
        "Full Text",
        0,
        0,
        0,
        content.len() as i64,
    )]
}

/// 检测章节（异步，加载 DB 配置）
///
/// 检测优先级链（按顺序）：
/// 1. 如果书选择了自定义 scope → 使用 scope 中的用户自定义规则
/// 2. 内置 4 种通用规则兜底
/// 3. 全部未命中 → 整文件当一章
pub async fn detect_chapters(
    content: &str,
    book_id: &str,
    pool: &SqlitePool,
) -> Result<Vec<Chapter>, AppError> {
    let scope = repo::get_book_scope(pool, book_id).await?;

    // 1. 用户自定义规则（非 global scope）
    if scope != "global" {
        let compiled = load_compiled_config(pool, &scope).await?;
        for pattern in &compiled.patterns {
            let chapters = try_pattern(content, pattern, book_id);
            if !chapters.is_empty() {
                return Ok(chapters);
            }
        }
    }

    // 2. 内置通用规则兜底
    Ok(detect_with_builtin_only(content, book_id))
}
