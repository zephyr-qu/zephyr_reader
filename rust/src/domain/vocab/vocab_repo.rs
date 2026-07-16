use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：生词仓储，管理生词本的增删改查
//
// 公有类型/函数：
//   - VocabRepository — 生词仓储结构体
//   - save() — 添加生词条目
//   - find_by_status() / search() — 查询与搜索
//   - update_by_status() — 更新生词状态
//   - delete_by_id() — 删除生词
//   - count() / count_by_book() — 统计
// ============================================================

use crate::domain::vocab::models::{Vocab, VocabStatus, VocabStats};
use crate::domain::AppError;
use chrono::Utc;
use sqlx::{QueryBuilder, SqlitePool};


/// 生词仓储 — 管理生词本的增删改查
#[frb(opaque)]
pub struct VocabRepository;

impl VocabRepository {
    /// 添加生词条目
    pub async fn save(pool: &SqlitePool, vocab: &Vocab) -> Result<Vocab, AppError> {
        sqlx::query(
            "INSERT INTO vocabulary_words \
             (id, word, pinyin, translation, context_sentence, book_id, chapter_index, char_offset, word_list, created_at, review_count, status, dict_source, dict_entry_hash, last_reviewed_at) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15) \
             ON CONFLICT(id) DO UPDATE SET \
             word = excluded.word, pinyin = excluded.pinyin, translation = excluded.translation, \
             context_sentence = excluded.context_sentence, book_id = excluded.book_id, \
             chapter_index = excluded.chapter_index, char_offset = excluded.char_offset, \
             word_list = excluded.word_list, review_count = excluded.review_count, \
             status = excluded.status, dict_source = excluded.dict_source, \
             dict_entry_hash = excluded.dict_entry_hash, last_reviewed_at = excluded.last_reviewed_at",
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
        .bind(vocab.created_at)
        .bind(vocab.review_count)
        .bind(vocab.status.as_ref())
        .bind(&vocab.dict_source)
        .bind(&vocab.dict_entry_hash)
        .bind(vocab.last_reviewed_at)
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
    ) -> Result<Vec<Vocab>, AppError> {
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
    pub async fn search(pool: &SqlitePool, keyword: &str) -> Result<Vec<Vocab>, AppError> {
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
    pub async fn update_by_status(pool: &SqlitePool, id: &str, status: VocabStatus) -> Result<(), AppError> {
        sqlx::query("UPDATE vocabulary_words SET status = ?1, last_reviewed_at = ?2 WHERE id = ?3")
            .bind(status.as_ref())
            .bind(Utc::now().timestamp())
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 删除生词
    pub async fn delete_by_id(pool: &SqlitePool, id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM vocabulary_words WHERE id = ?1")
            .bind(id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取生词本统计
    pub async fn count(pool: &SqlitePool) -> Result<VocabStats, AppError> {
    let stats: VocabStats = sqlx::query_as(
        "SELECT \
            COUNT(*) AS total_words, \
            COALESCE(SUM(CASE WHEN status = 'unstarted' THEN 1 ELSE 0 END), 0) AS unstarted_count, \
            COALESCE(SUM(CASE WHEN status = 'learning' THEN 1 ELSE 0 END), 0) AS learning_count, \
            COALESCE(SUM(CASE WHEN status = 'mastered' THEN 1 ELSE 0 END), 0) AS mastered_count, \
            COALESCE(SUM(CASE WHEN status = 'ignored' THEN 1 ELSE 0 END), 0) AS ignored_count \
         FROM vocabulary_words",
    )
    .fetch_one(pool)
    .await?;

    Ok(stats)
}

    /// 获取指定书籍的生词数量
    pub async fn count_by_book(pool: &SqlitePool, book_id: &str) -> Result<i32, AppError> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM vocabulary_words WHERE book_id = ?",
        )
        .bind(book_id)
        .fetch_one(pool)
        .await?;
        Ok(count as i32)
    }
}
