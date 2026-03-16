//! 全文搜索引擎模块
//! 基于 SQLite FTS5 实现书籍内容搜索
//! 集成 jieba-rs 中文分词支持

use jieba_rs::Jieba;
use once_cell::sync::Lazy;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

/// 全局 Jieba 分词器实例（懒加载）
static JIEBA: Lazy<Jieba> = Lazy::new(Jieba::new);

/// 搜索结果项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    /// 章节 ID
    pub chapter_id: i32,
    /// 章节标题
    pub chapter_title: String,
    /// 匹配的文本片段
    pub snippet: String,
    /// 匹配位置（字符偏移）
    pub position: i64,
    /// 相关度评分
    pub score: f32,
}

/// 搜索引擎（基于 SQLite FTS5）
pub struct SearchEngine {
    conn: Connection,
}

impl SearchEngine {
    /// 创建或打开搜索引擎
    pub fn open_or_create(db_path: &str) -> Result<Self, rusqlite::Error> {
        let conn = Connection::open(db_path)?;

        // 创建 FTS5 虚拟表
        conn.execute(
            "CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
                book_id UNINDEXED,
                chapter_id UNINDEXED,
                chapter_title,
                content,
                position UNINDEXED
            )",
            [],
        )?;

        Ok(Self { conn })
    }

    /// 索引章节内容
    ///
    /// 自动对中文内容进行分词后索引，提升搜索准确率。
    pub fn index_chapter(
        &mut self,
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

        // 将内容分块索引（每块 500 字符）
        const CHUNK_SIZE: usize = 500;
        let chars: Vec<char> = tokenized_content.chars().collect();
        let chunk_count = chars.chunks(CHUNK_SIZE).len();

        let tx = self.conn.transaction()?;

        for (i, chunk) in chars.chunks(CHUNK_SIZE).enumerate() {
            let chunk_str: String = chunk.iter().collect();
            let position = (i * CHUNK_SIZE) as i64;

            tx.execute(
                "INSERT INTO search_index (book_id, chapter_id, chapter_title, content, position)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![book_id, chapter_id, tokenized_title, chunk_str, position],
            )?;
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
    pub fn search(
        &self,
        book_id: &str,
        query: &str,
        limit: usize,
    ) -> Result<Vec<SearchResult>, rusqlite::Error> {
        // 对搜索关键词也进行分词
        let tokenized_query = tokenize_chinese_text(query);

        let mut stmt = self.conn.prepare(
            "SELECT chapter_id, chapter_title, content, position, bm25(search_index) as score
             FROM search_index
             WHERE book_id = ?1 AND search_index MATCH ?2
             ORDER BY score
             LIMIT ?3",
        )?;

        let results = stmt.query_map(
            // 将 usize 转换为 i64
            params![book_id, tokenized_query, limit as i64],
            |row| {
                Ok(SearchResult {
                    chapter_id: row.get(0)?,
                    chapter_title: row.get(1)?,
                    snippet: truncate_snippet(&row.get::<_, String>(2)?, 100),
                    position: row.get(3)?,
                    score: row.get(4)?,
                })
            },
        )?;

        let mut collected = Vec::new();
        for result in results {
            if let Ok(search_result) = result {
                collected.push(search_result);
            }
        }

        Ok(collected)
    }

    /// 删除书籍的所有索引
    pub fn delete_book(&self, book_id: &str) -> Result<(), rusqlite::Error> {
        self.conn
            .execute("DELETE FROM search_index WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    /// 清除所有索引
    pub fn clear_all(&self) -> Result<(), rusqlite::Error> {
        self.conn.execute("DELETE FROM search_index", [])?;
        Ok(())
    }
}

/// 对中文文本进行分词
///
/// 使用 jieba-rs 对中文内容进行分词，提升搜索准确率。
/// 对于混合文本，会自动处理中英文边界。
pub fn tokenize_chinese_text(text: &str) -> String {
    // 使用 jieba 分词，结果用空格连接
    let words: Vec<&str> = JIEBA.cut_all(text);
    words.join(" ")
}

/// 截断摘要文本
fn truncate_snippet(text: &str, max_len: usize) -> String {
    let chars: Vec<char> = text.chars().collect();
    if chars.len() <= max_len {
        return text.to_string();
    }
    chars[..max_len].iter().collect::<String>() + "..."
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_search_engine_create() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let engine = SearchEngine::open_or_create(&db_path);
        assert!(engine.is_ok(), "搜索引擎创建失败");
    }

    #[test]
    fn test_search_engine_index_chapter() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引测试内容
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
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引中文内容
        engine
            .index_chapter(
                "book1",
                1,
                "第一章 测试",
                "这是一个测试章节，包含一些中文内容。搜索引擎应该能找到这段文字。",
            )
            .unwrap();

        // 搜索中文关键词
        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(!results.is_empty(), "中文搜索应该返回结果");
        assert!(results[0].score.is_finite(), "相关度评分应该是有效数字");
    }

    #[test]
    fn test_search_english_content() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引英文内容
        engine
            .index_chapter(
                "book1",
                1,
                "Chapter 1",
                "This is a test chapter with English content. The search engine should find this text.",
            )
            .unwrap();

        // 搜索英文关键词
        let results = engine.search("book1", "test", 10).unwrap();
        assert!(!results.is_empty(), "英文搜索应该返回结果");
    }

    #[test]
    fn test_search_mixed_content() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引中英文混合内容
        engine
            .index_chapter(
                "book1",
                1,
                "第一章 Chapter 1",
                "这是测试 This is a test. 搜索引擎 search engine.",
            )
            .unwrap();

        // 搜索中文
        let cn_results = engine.search("book1", "测试", 10).unwrap();
        assert!(!cn_results.is_empty(), "中文搜索应该返回结果");

        // 搜索英文
        let en_results = engine.search("book1", "test", 10).unwrap();
        assert!(!en_results.is_empty(), "英文搜索应该返回结果");
    }

    #[test]
    fn test_search_relevance_ranking() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引多个章节，包含不同密度的关键词
        engine
            .index_chapter(
                "book1",
                1,
                "第一章",
                "测试 测试 测试 测试 测试 测试 测试 测试 测试 测试", // 高频
            )
            .unwrap();

        engine
            .index_chapter(
                "book1",
                2,
                "第二章",
                "测试 其他内容 其他内容 其他内容", // 低频
            )
            .unwrap();

        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(results.len() >= 2, "应该找到至少两个结果");

        // 验证相关度排序（高频应该排在前面）
        // 注意：FTS5 的 bm25 评分越低表示相关度越高
        assert!(
            results[0].score <= results[1].score,
            "高频关键词的章节应该排在前面的 (分数更低)"
        );
    }

    #[test]
    fn test_search_no_results() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引内容
        engine
            .index_chapter("book1", 1, "第一章", "这是测试内容")
            .unwrap();

        // 搜索不存在的关键词
        let results = engine.search("book1", "不存在的关键词", 10).unwrap();
        assert!(results.is_empty(), "搜索不存在的关键词应该返回空结果");
    }

    #[test]
    fn test_search_limit() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引多个章节
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

        // 限制返回结果数量
        let results = engine.search("book1", "测试", 5).unwrap();
        assert!(results.len() <= 5, "返回结果数不应超过限制");
    }

    #[test]
    fn test_search_delete_book() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引两本书
        engine
            .index_chapter("book1", 1, "第一章", "测试内容 1")
            .unwrap();
        engine
            .index_chapter("book2", 1, "第一章", "测试内容 2")
            .unwrap();

        // 删除一本书的索引
        engine.delete_book("book1").unwrap();

        // 搜索 book1 应该没有结果
        let results_book1 = engine.search("book1", "测试", 10).unwrap();
        assert!(results_book1.is_empty(), "删除后 book1 应该没有搜索结果");

        // 搜索 book2 应该还有结果
        let results_book2 = engine.search("book2", "测试", 10).unwrap();
        assert!(!results_book2.is_empty(), "book2 应该还有搜索结果");
    }

    #[test]
    fn test_search_clear_all() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir
            .path()
            .join("search.db")
            .to_str()
            .unwrap()
            .to_string();

        let mut engine = SearchEngine::open_or_create(&db_path).unwrap();

        // 索引内容
        engine
            .index_chapter("book1", 1, "第一章", "测试内容")
            .unwrap();

        // 清除所有索引
        engine.clear_all().unwrap();

        // 搜索应该返回空结果
        let results = engine.search("book1", "测试", 10).unwrap();
        assert!(results.is_empty(), "清除所有索引后应该没有搜索结果");
    }

    #[test]
    fn test_chinese_tokenization_basic() {
        let text = "这是一个测试";
        let tokenized = tokenize_chinese_text(text);
        // 分词后应该包含空格
        assert!(tokenized.contains(' '), "分词后应该包含空格分隔符");
        // 分词后应该包含原始字符
        assert!(tokenized.contains("测试"), "分词后应该包含原始词汇");
    }

    #[test]
    fn test_chinese_tokenization_mixed() {
        let text = "Hello 世界 This is 测试";
        let tokenized = tokenize_chinese_text(text);
        // 分词后应该保留英文单词
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
        // 测试短文本（不需要截断）
        let short_text = "短文本";
        let result = truncate_snippet(short_text, 100);
        assert_eq!(result, short_text, "短文本不应该被截断");

        // 测试长文本（需要截断）
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
