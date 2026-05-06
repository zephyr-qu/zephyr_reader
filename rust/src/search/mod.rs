//! 全文搜索引擎模块
//! 基于 SQLite FTS5 实现书籍内容搜索
//! 集成 jieba-rs 中文分词支持
//!
//! FTS5 虚拟表与主数据库共享连接，支持事务隔离。

use jieba_rs::Jieba;
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use rusqlite::{params};
use std::sync::Arc;

use crate::api::SearchResult;

/// 全局 Jieba 分词器实例（安全懒加载）
///
/// 使用 `catch_unwind` 包装 `Jieba::new()`，避免词典文件缺失时 panic。
/// 若初始化失败则为 `None`，`tokenize_chinese_text` 会降级为不进行分词。
static JIEBA: Lazy<Option<Jieba>> = Lazy::new(|| std::panic::catch_unwind(Jieba::new).ok());
/// 搜索索引分块大小（字符数）
/// 用于将文档分割成小块进行索引
pub const SEARCH_CHUNK_SIZE: usize = 500;

/// 搜索引擎（基于 SQLite FTS5）
///
/// 与主数据库共享连接，确保索引操作参与主数据库事务。
pub struct SearchEngine {
    db: Arc<Mutex<crate::storage::database::Database>>,
}

impl SearchEngine {
    /// 创建搜索引擎，使用主数据库连接
    pub fn new(db: Arc<Mutex<crate::storage::database::Database>>) -> Self {
        Self { db }
    }

    /// 索引章节内容
    ///
    /// 自动对中文内容进行分词后索引，提升搜索准确率。
    pub fn index_chapter(
        &self,
        book_id: &str,
        chapter_id: i32,
        chapter_title: &str,
        content: &str,
    ) -> Result<(), rusqlite::Error> {
        let start_time = std::time::Instant::now();
        let content_len = content.len();
        tracing::debug!(
            "开始索引章节：book={}, chapter={}, 字符数={}",
            book_id,
            chapter_id,
            content_len
        );

        // 对中文内容进行分词
        let tokenized_content = tokenize_chinese_text(content);
        let tokenized_title = tokenize_chinese_text(chapter_title);
        tracing::trace!(
            "分词完成，原始长度：{}, 分词后长度：{}",
            content_len,
            tokenized_content.len()
        );

        // 将内容分块索引（每块 SEARCH_CHUNK_SIZE 字符）
        let chunk_boundaries: Vec<usize> = tokenized_content
            .char_indices()
            .step_by(SEARCH_CHUNK_SIZE)
            .map(|(byte_idx, _)| byte_idx)
            .chain(std::iter::once(tokenized_content.len()))
            .collect();

        let chunk_count = chunk_boundaries.len() - 1;

        let mut db = self.db.lock();
        let tx = db.conn_mut().transaction()?;

        {
            let mut stmt = tx.prepare(
                "INSERT INTO search_index (book_id, chapter_id, chapter_title, content, position)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
            )?;

            for i in 0..chunk_count {
                let byte_start = chunk_boundaries[i];
                let byte_end = chunk_boundaries[i + 1];
                let chunk_str = &tokenized_content[byte_start..byte_end];
                let position = (i * SEARCH_CHUNK_SIZE) as i64;

                stmt.execute(params![
                    book_id,
                    chapter_id,
                    tokenized_title,
                    chunk_str,
                    position
                ])?;
            }
        }

        tx.commit()?;

        let elapsed = start_time.elapsed();
        tracing::info!(
            "章节索引完成：book={}, chapter={}, 分块数={}, 耗时：{:?}",
            book_id,
            chapter_id,
            chunk_count,
            elapsed
        );

        Ok(())
    }

    /// 搜索书籍内容
    ///
    /// 使用 FTS5 列查询语法过滤 book_id，利用 FTS5 内部索引
    /// 替代 `WHERE book_id = ?` 的后置过滤，提升跨书籍搜索性能。
    fn build_fts5_query(book_id: &str, query: &str) -> String {
        // book_id 通常是 UUID（如 "550e8400-e29b-..."），unicode61 tokenizer 会按连字符拆分。
        // 将各段用 AND 组合可精确匹配目标书籍。
        let book_id_tokens: Vec<&str> = book_id.split('-').filter(|s| !s.is_empty()).collect();
        if book_id_tokens.is_empty() {
            query.to_string()
        } else {
            let book_id_filter = book_id_tokens
                .iter()
                .map(|s| format!("book_id: {}", s))
                .collect::<Vec<_>>()
                .join(" AND ");
            format!("({}) AND ({})", book_id_filter, query)
        }
    }

    /// 搜索书籍内容
    pub fn search(
        &self,
        book_id: &str,
        query: &str,
        limit: usize,
    ) -> Result<Vec<SearchResult>, rusqlite::Error> {
        // 对搜索关键词也进行分词
        let tokenized_query = tokenize_chinese_text(query);
        // 转义 FTS5 特殊字符
        let safe_query = escape_fts5_query(&tokenized_query);
        // 构建包含 book_id 过滤的 FTS5 MATCH 表达式
        let fts5_query = Self::build_fts5_query(book_id, &safe_query);

        let db = self.db.lock();
        let mut stmt = db.conn().prepare(
            "SELECT chapter_id, chapter_title, content, position, bm25(search_index) as score
             FROM search_index
             WHERE search_index MATCH ?1
             ORDER BY score
             LIMIT ?2",
        )?;

        let results = stmt.query_map(params![fts5_query, limit as i64], |row| {
            Ok(SearchResult {
                chapter_id: row.get(0)?,
                chapter_title: row.get(1)?,
                snippet: truncate_snippet(&row.get::<_, String>(2)?, 100),
                position: row.get(3)?,
                score: row.get(4)?,
            })
        })?;

        let mut collected = Vec::new();
        for search_result in results.flatten() {
            collected.push(search_result);
        }

        Ok(collected)
    }

    /// 删除书籍的所有索引
    pub fn delete_book(&self, book_id: &str) -> Result<(), rusqlite::Error> {
        self.db
            .lock()
            .conn()
            .execute("DELETE FROM search_index WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    /// 清除所有索引
    pub fn clear_all(&self) -> Result<(), rusqlite::Error> {
        self.db
            .lock()
            .conn()
            .execute("DELETE FROM search_index", [])?;
        Ok(())
    }
}

/// 检查 Jieba 分词器是否成功初始化
///
/// 应在引擎初始化时调用，以确保搜索功能可用。
/// 若 Jieba 初始化失败，返回错误信息。
pub fn ensure_jieba() -> Result<(), String> {
    JIEBA
        .as_ref()
        .ok_or_else(|| "Jieba 分词器初始化失败：词典文件可能缺失或损坏".to_string())
        .map(|_| ())
}

/// 对中文文本进行分词
///
/// 使用 jieba-rs 对中文内容进行分词（精确模式），提升搜索准确率。
/// 对于混合文本，会自动处理中英文边界。
///
/// # 降级行为
///
/// 若 Jieba 初始化失败（词典文件缺失等），则原样返回文本（不分词）。
pub fn tokenize_chinese_text(text: &str) -> String {
    let jieba = match JIEBA.as_ref() {
        Some(j) => j,
        None => return text.to_string(), // fallback: no tokenization
    };
    // 使用 jieba 精确模式分词（cut_all=false），避免索引膨胀
    let words: Vec<&str> = jieba.cut(text, false);
    words.join(" ")
}

/// 转义 FTS5 查询中的特殊字符
///
/// FTS5 使用双引号作为标识符引用，以下字符需要转义：
/// - " 替换为 ""（双引号转义）
/// - * ^ ~ 等特殊字符也需要转义
fn escape_fts5_query(query: &str) -> String {
    let escaped = query
        .replace('"', "\"\"")
        .replace('*', "\"*\"")
        .replace('^', "\"^\"")
        .replace('~', "\"~\"");

    if escaped.trim().is_empty() {
        return "\"\"".to_string();
    }
    format!("\"{}\"", escaped)
}

/// 截断摘要文本
fn truncate_snippet(text: &str, max_len: usize) -> String {
    let char_count = text.chars().count();
    if char_count <= max_len {
        return text.to_string();
    }
    text.chars().take(max_len).collect::<String>() + "..."
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::database::Database;
    use std::sync::Arc;
    use tempfile::TempDir;

    fn create_test_engine() -> (SearchEngine, TempDir) {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db = Database::new(&db_path).unwrap();
        let engine = SearchEngine::new(Arc::new(Mutex::new(db)));
        (engine, temp_dir)
    }

    #[test]
    fn test_search_engine_create() {
        let (_, _temp_dir) = create_test_engine();
    }

    #[test]
    fn test_search_engine_index_chapter() {
        let (engine, _temp_dir) = create_test_engine();

        let result = engine.index_chapter(
            "book1",
            1,
            "第一章 开始",
            "这是一个测试章节，包含一些中文内容。Hello world! This is English content.",
        );
        assert!(result.is_ok(), "章节索引失败：{:?}", result);
    }

    #[test]
    fn test_search_chinese_content() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter(
                "book1",
                1,
                "第一章 测试",
                "这是一个测试章节，包含一些中文内容。搜索引擎应该能找到这段文字。",
            )
            .unwrap();

        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(!results.is_empty(), "中文搜索应该返回结果");
        assert!(results[0].score.is_finite(), "相关度评分应该是有效数字");
    }

    #[test]
    fn test_search_english_content() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter(
                "book1",
                1,
                "Chapter 1",
                "This is a test chapter with English content. The search engine should find this text.",
            )
            .unwrap();

        let results = engine.search("book1", "test", 10).unwrap();
        assert!(!results.is_empty(), "英文搜索应该返回结果");
    }

    #[test]
    fn test_search_mixed_content() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter(
                "book1",
                1,
                "第一章 Chapter 1",
                "这是测试 This is a test. 搜索引擎 search engine.",
            )
            .unwrap();

        let cn_results = engine.search("book1", "测试", 10).unwrap();
        assert!(!cn_results.is_empty(), "中文搜索应该返回结果");

        let en_results = engine.search("book1", "test", 10).unwrap();
        assert!(!en_results.is_empty(), "英文搜索应该返回结果");
    }

    #[test]
    fn test_search_relevance_ranking() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter(
                "book1",
                1,
                "第一章",
                "测试 测试 测试 测试 测试 测试 测试 测试 测试 测试",
            )
            .unwrap();

        engine
            .index_chapter(
                "book1",
                2,
                "第二章",
                "测试 其他内容 其他内容 其他内容",
            )
            .unwrap();

        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(results.len() >= 2, "应该找到至少两个结果");
        assert!(
            results[0].score <= results[1].score,
            "高频关键词的章节应该排在前面的 (分数更低)"
        );
    }

    #[test]
    fn test_search_no_results() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter("book1", 1, "第一章", "这是测试内容")
            .unwrap();

        let results = engine.search("book1", "不存在的关键词", 10).unwrap();
        assert!(results.is_empty(), "搜索不存在的关键词应该返回空结果");
    }

    #[test]
    fn test_search_limit() {
        let (engine, _temp_dir) = create_test_engine();

        for i in 1..=20 {
            engine
                .index_chapter(
                    "book1",
                    i,
                    &format!("第 {} 章", i),
                    &format!("这是第 {} 个测试章节，包含测试内容", i),
                )
                .unwrap();
        }

        let results = engine.search("book1", "测试", 5).unwrap();
        assert!(results.len() <= 5, "返回结果数不应超过限制");
    }

    #[test]
    fn test_search_delete_book() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter("book1", 1, "第一章", "测试内容 1")
            .unwrap();
        engine
            .index_chapter("book2", 1, "第一章", "测试内容 2")
            .unwrap();

        engine.delete_book("book1").unwrap();

        let results_book1 = engine.search("book1", "测试", 10).unwrap();
        assert!(results_book1.is_empty(), "删除后 book1 应该没有搜索结果");

        let results_book2 = engine.search("book2", "测试", 10).unwrap();
        assert!(!results_book2.is_empty(), "book2 应该还有搜索结果");
    }

    #[test]
    fn test_search_clear_all() {
        let (engine, _temp_dir) = create_test_engine();

        engine
            .index_chapter("book1", 1, "第一章", "测试内容")
            .unwrap();

        engine.clear_all().unwrap();

        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(results.is_empty(), "清除所有索引后应该没有搜索结果");
    }

    #[test]
    fn test_chinese_tokenization_basic() {
        let text = "这是一个测试";
        let tokenized = tokenize_chinese_text(text);
        assert!(tokenized.contains(' '), "分词后应该包含空格分隔符");
        assert!(tokenized.contains("测试"), "分词后应该包含原始词汇");
    }

    #[test]
    fn test_chinese_tokenization_mixed() {
        let text = "Hello 世界 This is 测试";
        let tokenized = tokenize_chinese_text(text);
        assert!(tokenized.contains("Hello"), "应该保留英文单词");
        assert!(tokenized.contains("测试"), "应该包含中文词汇");
    }

    #[test]
    fn test_chinese_tokenization_empty() {
        let text = "";
        let tokenized = tokenize_chinese_text(text);
        assert_eq!(tokenized, "", "空字符串分词后应该还是空");
    }

    #[test]
    fn test_truncate_snippet() {
        let short_text = "短文本";
        let result = truncate_snippet(short_text, 100);
        assert_eq!(result, short_text, "短文本不应该被截断");

        let long_text = "这是一个非常长的文本，超过了最大长度限制，应该被截断并添加省略号";
        let result = truncate_snippet(long_text, 10);
        assert!(result.len() <= long_text.len(), "长文本应该被截断");
        assert!(result.ends_with("..."), "截断后应该添加省略号");
    }

    #[test]
    fn test_search_result_structure() {
        let result = SearchResult {
            chapter_id: 1,
            chapter_title: "第一章".to_string(),
            snippet: "测试片段".to_string(),
            position: 0,
            score: 0.5,
        };

        assert_eq!(result.chapter_id, 1);
        assert_eq!(result.chapter_title, "第一章");
        assert_eq!(result.snippet, "测试片段");
        assert_eq!(result.position, 0);
        assert!((result.score - 0.5).abs() < f32::EPSILON);
    }
}
