//! 搜索引擎 — 基于 SQLite FTS5 + jieba-rs 中文分词

use std::sync::OnceLock;

use jieba_rs::Jieba;
use sqlx::{QueryBuilder, SqlitePool};

use crate::domain::SearchResult;

static JIEBA: OnceLock<Jieba> = OnceLock::new();

pub const SEARCH_CHUNK_SIZE: usize = 500;
pub struct SearchEngine {
    pool: SqlitePool,
}

impl SearchEngine {
    pub fn new(pool: SqlitePool) -> Self {
        // FTS5 表会在首次写入时自动创建（如果不存在）
        // DDL 在 test 模块中保留作为参考
        Self { pool }
    }

    /// 确保 FTS5 表已创建（幂等，可重复调用）
    pub async fn ensure_table(&self) -> Result<(), sqlx::Error> {
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
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    /// 索引章节内容（幂等：先删后插）
    pub async fn index_chapter(
        &self,
        book_id: &str,
        chapter_id: &str,
        chapter_index: &str,
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

        let tokenized_content = tokenize_chinese_text(content);
        let tokenized_title = tokenize_chinese_text(chapter_title);

        // M1: 使用 char_indices 直接分块，避免 Vec<char> 中间分配
        let char_count = tokenized_content.chars().count();
        let num_chunks = char_count.div_ceil(SEARCH_CHUNK_SIZE);
        let char_boundaries: Vec<usize> = tokenized_content
            .char_indices()
            .map(|(i, _)| i)
            .collect();

        let mut chunks: Vec<(i64, String)> = Vec::with_capacity(num_chunks);

        for i in 0..num_chunks {
            let char_start = i * SEARCH_CHUNK_SIZE;
            let char_end = ((i + 1) * SEARCH_CHUNK_SIZE).min(char_count);
            let byte_start = char_boundaries[char_start];
            let byte_end = if char_end < char_count {
                char_boundaries[char_end]
            } else {
                tokenized_content.len()
            };
            let position = char_start as i64;
            chunks.push((
                position,
                tokenized_content[byte_start..byte_end].to_string(),
            ));
        }

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
                    .push_bind(chapter_index)
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
            "SELECT book_id, chapter_id, chapter_title, \
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
            "SELECT book_id, chapter_id, chapter_title, \
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

    pub async fn delete_by_book(&self, book_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM search_index WHERE book_id = ?")
            .bind(book_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn clear_all(&self) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM search_index")
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}

// ==================== 辅助函数 ====================

/// 初始化 Jieba 分词器（幂等，编译期嵌入词典数据）
pub fn ensure_jieba() -> Result<(), String> {
    JIEBA.get_or_init(|| Jieba::new());
    Ok(())
}

/// 对中文文本进行分词，非中文原样返回
pub fn tokenize_chinese_text(text: &str) -> String {
    let jieba = JIEBA.get_or_init(|| Jieba::new());

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

/// 统一用双引号包裹所有 FTS5 特殊字符，不插入额外空格
fn escape_fts5_query(query: &str) -> String {
    const SPECIAL: &[char] = &['"', '*', '^', '~', '+', '-', '(', ')', '>', '<'];
    let mut result = String::with_capacity(query.len() + 8);
    for c in query.chars() {
        if SPECIAL.contains(&c) {
            result.push('"');
            if c == '"' {
                result.push('"'); // FTS5 中 "" 是引号的转义
            } else {
                result.push(c);
            }
            result.push('"');
        } else {
            result.push(c);
        }
    }
    let trimmed = result.trim().to_string();
    if trimmed.is_empty() {
        String::new()
    } else {
        trimmed
    }
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
}
