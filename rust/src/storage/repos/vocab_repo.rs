use anyhow::Result;
use chrono::Utc;
use sqlx::{QueryBuilder, SqlitePool};

use super::super::models::*;

pub struct VocabRepository;

impl VocabRepository {
    /// 添加生词条目
    pub async fn save(pool: &SqlitePool, vocab: &Vocab) -> Result<Vocab> {
        sqlx::query(
            "INSERT INTO vocabulary_words \
             (id, word, pinyin, translation, context_sentence, book_id, chapter_index, char_offset, word_list, created_at, review_count, status, dict_source, dict_entry_hash) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 0, ?11, ?12, ?13)",
        )
        .bind(&vocab.id)
        .bind(&vocab.word)
        .bind(&vocab.pinyin)
        .bind(&vocab.translation)
        .bind(&vocab.context_sentence)
        .bind(&vocab.book_id)
        .bind(vocab.chapter_index)
        .bind(vocab.char_offset)
        .bind(&vocab.word_list)
        .bind(vocab.last_reviewed_at.map(|dt| dt.timestamp()))
        .bind(vocab.status.as_ref())
        .bind(&vocab.dict_source)
        .bind(&vocab.dict_entry_hash)
        .execute(pool)
        .await?;

        Ok(vocab.clone())
    }

    /// 按条件筛选生词
    pub async fn find_by_status(
        pool: &SqlitePool,
        book_id: Option<&str>,
        status: Option<VocabStatus>,
        word_list: Option<&str>,
    ) -> Result<Vec<Vocab>> {
        let mut builder = QueryBuilder::<sqlx::Sqlite>::new("SELECT * FROM vocabulary_words");

        // 构建 WHERE 子句
        let mut has_condition = false;

        if let Some(bid) = book_id {
            if !has_condition {
                builder.push(" WHERE ");
                has_condition = true;
            } else {
                builder.push(" AND ");
            }
            builder.push("book_id = ");
            builder.push_bind(bid);
        }

        if let Some(st) = status {
            if !has_condition {
                builder.push(" WHERE ");
                has_condition = true;
            } else {
                builder.push(" AND ");
            }
            builder.push("status = ");
            builder.push_bind(st.as_ref());
        }

        if let Some(wl) = word_list {
            if !has_condition {
                builder.push(" WHERE ");
            } else {
                builder.push(" AND ");
            }
            builder.push("word_list = ");
            builder.push_bind(wl);
        }

        builder.push(" ORDER BY created_at DESC");

        Ok(builder.build_query_as::<Vocab>().fetch_all(pool).await?)
    }

    /// 搜索生词（标题或翻译模糊匹配）
    pub async fn search(pool: &SqlitePool, keyword: &str) -> Result<Vec<Vocab>> {
        if keyword.trim().is_empty() {
            return Ok(Vec::new());
        }
        // 转义 LIKE 通配符，防止用户输入干扰查询语义
        let escaped = keyword.replace('%', r"\%").replace('_', r"\_");
        let pattern = format!("%{}%", escaped);

        Ok(sqlx::query_as::<_, Vocab>(
            "SELECT * FROM vocabulary_words \
             WHERE word LIKE ?1 ESCAPE '\\' OR translation LIKE ?1 ESCAPE '\\' \
             ORDER BY created_at DESC",
        )
        .bind(&pattern)
        .fetch_all(pool)
        .await?)
    }

    /// 更新生词状态
    pub async fn update_by_status(pool: &SqlitePool, id: &str, status: VocabStatus) -> Result<()> {
        sqlx::query("UPDATE vocabulary_words SET status = ?1, last_reviewed_at = ?2 WHERE id = ?3")
            .bind(status.as_ref())
            .bind(Utc::now().timestamp())
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 删除生词
    pub async fn delete_by_id(pool: &SqlitePool, id: &str) -> Result<()> {
        sqlx::query("DELETE FROM vocabulary_words WHERE id = ?1")
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取生词本统计
    pub async fn count(pool: &SqlitePool) -> Result<VocabStats> {
        #[derive(sqlx::FromRow)]
        struct StatsRow {
            total_words: i64,
            learning_count: i64,
            mastered_count: i64,
        }

        //COALESCE 防止空表时 SUM 返回 NULL 导致解码失败
        let row: StatsRow = sqlx::query_as(
            "SELECT \
                COUNT(*) AS total_words, \
                COALESCE(SUM(CASE WHEN status = 'learning' THEN 1 ELSE 0 END), 0) AS learning_count, \
                COALESCE(SUM(CASE WHEN status = 'mastered' THEN 1 ELSE 0 END), 0) AS mastered_count \
             FROM vocabulary_words",
        )
        .fetch_one(pool)
        .await?;

        Ok(VocabStats {
            total_words: row.total_words,
            learning_count: row.learning_count,
            known_count: 0,
            mastered_count: row.mastered_count,
        })
    }
}
