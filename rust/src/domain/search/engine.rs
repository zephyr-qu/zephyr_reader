//! 搜索引擎 — 基于 SQLite FTS5 + jieba-rs 中文分词

use std::sync::OnceLock;

use jieba_rs::Jieba;
use sqlx::{QueryBuilder, SqlitePool};

use super::models::{IndexStats, SearchResult};

static JIEBA: OnceLock<Jieba> = OnceLock::new();

/// 搜索分块大小（每块 500 个字符）
pub const SEARCH_CHUNK_SIZE: usize = 500;
const SEARCH_OFFSET_VERSION: &str = "2";

/// 将原始 plainText 分块，并保留每块在原文中的 UTF-16 起点。
fn build_search_chunks(content: &str) -> Vec<(i64, String)> {
    if content.is_empty() {
        return Vec::new();
    }

    let mut chunks = Vec::new();
    let mut chunk_start_byte = 0usize;
    let mut chunk_start_utf16 = 0u32;
    let mut utf16_cursor = 0u32;
    let mut chars_in_chunk = 0usize;

    for (byte_index, ch) in content.char_indices() {
        if chars_in_chunk == SEARCH_CHUNK_SIZE {
            chunks.push((
                i64::from(chunk_start_utf16),
                tokenize_chinese_text(&content[chunk_start_byte..byte_index]),
            ));
            chunk_start_byte = byte_index;
            chunk_start_utf16 = utf16_cursor;
            chars_in_chunk = 0;
        }
        utf16_cursor = utf16_cursor.saturating_add(ch.len_utf16() as u32);
        chars_in_chunk += 1;
    }

    if chunk_start_byte < content.len() {
        chunks.push((
            i64::from(chunk_start_utf16),
            tokenize_chinese_text(&content[chunk_start_byte..]),
        ));
    }

    chunks
}
/// 搜索引擎
///
/// 基于 SQLite FTS5 全文检索引擎，支持中文分词（jieba-rs）
pub struct SearchEngine {
    pool: SqlitePool,
}

impl SearchEngine {
    /// 创建新的搜索引擎实例
    ///
    /// FTS5 表会在首次写入时自动创建（如果不存在）
    pub fn new(pool: SqlitePool) -> Self {
        // FTS5 表会在首次写入时自动创建（如果不存在）
        // DDL 在 test 模块中保留作为参考
        Self { pool }
    }

    /// 确保 FTS5 表已创建（幂等，可重复调用）
    pub async fn ensure_table(&self) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        sqlx::query(
            "CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
                content,
                book_id UNINDEXED,
                chapter_id UNINDEXED,
                chapter_index UNINDEXED,
                chapter_title UNINDEXED,
                position UNINDEXED,
                tokenize='unicode61'
            )",
        )
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "CREATE TABLE IF NOT EXISTS search_meta(
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )",
        )
        .execute(&mut *tx)
        .await?;

        let stored_version = sqlx::query_scalar::<_, String>(
            "SELECT value FROM search_meta WHERE key = 'offset_version'",
        )
        .fetch_optional(&mut *tx)
        .await?;
        if stored_version.as_deref() != Some(SEARCH_OFFSET_VERSION) {
            sqlx::query("DELETE FROM search_index")
                .execute(&mut *tx)
                .await?;
            sqlx::query(
                "INSERT INTO search_meta(key, value) VALUES('offset_version', ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            )
            .bind(SEARCH_OFFSET_VERSION)
            .execute(&mut *tx)
            .await?;
            tracing::info!(
                target: "search_index",
                offset_version = SEARCH_OFFSET_VERSION,
                "search index invalidated for UTF-16 offset contract"
            );
        }
        tx.commit().await?;
        Ok(())
    }

    /// 索引章节内容（幂等：先删后插）
    pub async fn index_chapter(
        &self,
        book_id: &str,
        chapter_id: &str,
        chapter_index: i32,
        chapter_title: &str,
        content: &str,
    ) -> Result<(), sqlx::Error> {
        let start_time = std::time::Instant::now();
        tracing::debug!(
            "indexing chapter: book={}, chapter={}, chars={}",
            book_id,
            chapter_id,
            content.len()
        );

        let tokenized_title = tokenize_chinese_text(chapter_title);
        let chunks = build_search_chunks(content);

        let mut tx = self.pool.begin().await?;

        // 幂等：先清除该章节的旧索引
        sqlx::query("DELETE FROM search_index WHERE book_id = ? AND chapter_index = ?")
            .bind(book_id)
            .bind(chapter_index)
            .execute(&mut *tx)
            .await?;

        // M2: 批量 INSERT 减少 SQLite round-trip
        if !chunks.is_empty() {
            let mut query_builder = QueryBuilder::new(
                "INSERT INTO search_index (book_id, chapter_id, chapter_index, chapter_title, content, position) ",
            );
            query_builder.push_values(chunks.iter(), |mut b, (position, chunk_str)| {
                b.push_bind(book_id)
                    .push_bind(chapter_id)
                    .push_bind(chapter_index.to_string())
                    .push_bind(&tokenized_title)
                    .push_bind(chunk_str)
                    .push_bind(position);
            });
            query_builder.build().execute(&mut *tx).await?;
        }

        tx.commit().await?;

        tracing::info!(
            "chapter indexed: book={}, chapter={}, chunks={}, elapsed={:?}",
            book_id,
            chapter_id,
            chunks.len(),
            start_time.elapsed()
        );
        Ok(())
    }

    /// 搜索指定书籍
    pub async fn search(
        &self,
        book_id: &str,
        query: &str,
        limit: usize,
    ) -> Result<Vec<SearchResult>, sqlx::Error> {
        let safe_query = escape_fts5_query(&tokenize_chinese_text(query));
        if safe_query.is_empty() {
            return Ok(Vec::new());
        }

        sqlx::query_as::<_, SearchResult>(
            "SELECT book_id, chapter_id, CAST(chapter_index AS INTEGER) AS chapter_index, chapter_title, \
                    snippet(search_index, 0, '<mark>', '</mark>', '...', 48) AS snippet, \
                    position, \
                    position AS char_offset, \
                    bm25(search_index) AS score \
             FROM search_index \
             WHERE book_id = ? AND search_index MATCH ? \
             ORDER BY score LIMIT ?",
        )
        .bind(book_id)
        .bind(&safe_query)
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await
    }

    /// 统计搜索匹配数
    pub async fn count_matches(
        &self,
        book_id: &str,
        query: &str,
        chapter_index: Option<i32>,
    ) -> Result<i64, sqlx::Error> {
        let safe_query = escape_fts5_query(&tokenize_chinese_text(query));
        if safe_query.is_empty() {
            return Ok(0);
        }

        match chapter_index {
            Some(ci) => {
                sqlx::query_scalar::<_, i64>(
                    "SELECT COUNT(*) FROM search_index \
                     WHERE book_id = ? AND search_index MATCH ? AND chapter_index = ?",
                )
                .bind(book_id)
                .bind(&safe_query)
                .bind(ci)
                .fetch_one(&self.pool)
                .await
            }
            None => {
                sqlx::query_scalar::<_, i64>(
                    "SELECT COUNT(*) FROM search_index \
                     WHERE book_id = ? AND search_index MATCH ?",
                )
                .bind(book_id)
                .bind(&safe_query)
                .fetch_one(&self.pool)
                .await
            }
        }
    }

    /// 搜索所有书籍
    pub async fn search_all_books(
        &self,
        query: &str,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<SearchResult>, sqlx::Error> {
        let safe_query = escape_fts5_query(&tokenize_chinese_text(query));
        if safe_query.is_empty() {
            return Ok(Vec::new());
        }

        sqlx::query_as::<_, SearchResult>(
            "SELECT book_id, chapter_id, CAST(chapter_index AS INTEGER) AS chapter_index, chapter_title, \
                snippet(search_index, 0, '<mark>', '</mark>', '...', 48) AS snippet, \
                position, \
                position AS char_offset, \
                bm25(search_index) AS score \
         FROM search_index \
         WHERE search_index MATCH ? \
         ORDER BY \
            CASE WHEN chapter_index = '-1' THEN 0 ELSE 1 END, \
            score \
         LIMIT ? OFFSET ?",
        )
        .bind(&safe_query)
        .bind(limit as i64)
        .bind(offset as i64)
        .fetch_all(&self.pool)
        .await
    }

    /// 删除指定书籍的所有索引
    pub async fn delete_by_book(&self, book_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM search_index WHERE book_id = ?")
            .bind(book_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 清空所有索引
    pub async fn clear_all(&self) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM search_index")
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    /// 获取索引统计信息
    pub async fn get_index_stats(&self) -> Result<IndexStats, sqlx::Error> {
        sqlx::query_as::<_, IndexStats>(
            "SELECT COUNT(*) as total_chunks, \
                    COUNT(DISTINCT book_id) as indexed_books, \
                    COUNT(DISTINCT book_id || ':' || chapter_index) as indexed_chapters \
             FROM search_index",
        )
        .fetch_one(&self.pool)
        .await
    }
}

// ==================== 辅助函数 ====================

/// 初始化 Jieba 分词器（幂等，编译期嵌入词典数据）
pub fn ensure_jieba() -> Result<(), String> {
    JIEBA.get_or_init(Jieba::new);
    Ok(())
}

/// 对中文文本进行分词，非中文原样返回
pub fn tokenize_chinese_text(text: &str) -> String {
    let jieba = JIEBA.get_or_init(Jieba::new);

    // L2: 避免中间 Vec<&str> 分配，直接 fold 到 String
    let mut result = String::with_capacity(text.len() + 4);
    for word in jieba.cut(text, false).iter().map(|t| t.word) {
        if !result.is_empty() {
            result.push(' ');
        }
        result.push_str(word);
    }
    result
}

/// 将整个查询包裹为 FTS5 短语，使所有特殊字符成为字面量
///
/// FTS5 中需要转义的只有双引号（`""` 在短语内是字面量 `"`），
/// 其余字符（`+`, `-`, `*`, `(`, `)` 等）在短语包裹下均失去操作符语义。
fn escape_fts5_query(query: &str) -> String {
    let trimmed = query.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    // 仅在短语内 `""` 是字面量 `"` 的转义，其他字符无需处理
    let escaped = trimmed.replace('"', "\"\"");
    format!("\"{escaped}\"")
}

#[cfg(test)]
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

    #[test]
    fn test_chinese_tokenization_basic() {
        let result = tokenize_chinese_text("今天天气不错");
        assert!(!result.is_empty());
        assert!(result.contains("今天") || result.contains("天气"));
    }

    #[test]
    fn test_chinese_tokenization_empty() {
        assert_eq!(tokenize_chinese_text(""), "");
    }

    #[test]
    fn test_chinese_tokenization_mixed() {
        let result = tokenize_chinese_text("Hello 世界");
        assert!(result.contains("Hello"));
        assert!(result.contains("世界"));
    }

    #[test]
    fn search_chunk_positions_use_original_utf16_offsets() {
        let content = format!("{}😀B", "A".repeat(SEARCH_CHUNK_SIZE - 1));
        let chunks = build_search_chunks(&content);

        assert_eq!(chunks.len(), 2);
        assert_eq!(chunks[0].0, 0);
        assert_eq!(chunks[1].0, (SEARCH_CHUNK_SIZE + 1) as i64);
        assert_eq!(chunks[1].1, "B");
    }

    #[tokio::test]
    async fn stale_offset_version_clears_derived_search_index() {
        let pool = SqlitePool::connect("sqlite::memory:")
            .await
            .expect("open in-memory sqlite");
        let engine = SearchEngine::new(pool.clone());
        engine.ensure_table().await.expect("create search tables");

        sqlx::query(
            "INSERT INTO search_index(content, book_id, chapter_id, chapter_index, chapter_title, position)
             VALUES('text', 'book', 'chapter', '0', 'title', 1)",
        )
        .execute(&pool)
        .await
        .expect("insert derived row");
        sqlx::query("UPDATE search_meta SET value = '1' WHERE key = 'offset_version'")
            .execute(&pool)
            .await
            .expect("mark stale version");

        engine.ensure_table().await.expect("invalidate stale index");

        let count = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM search_index")
            .fetch_one(&pool)
            .await
            .expect("count search rows");
        assert_eq!(count, 0);
    }
}
