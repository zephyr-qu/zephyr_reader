use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：笔记仓储，管理笔记（高亮/标注）的增删改查
//
// 公有类型/函数：
//   - NoteRepository — 笔记仓储结构体
//   - save() — 保存或更新笔记
//   - list_by_book() / find_by_chapter() / find_by_type() — 查询
//   - find_by_id() / search() / list_all_paginated() — 搜索与分页
//   - delete_by_id() / delete_by_book() — 删除
//   - find_partner_note() / find_partner_notes_batch() — 配对查询
//   - find_note_stats() / count_filtered() — 统计
//   - list_with_titles() — 笔记列表附带书名
// ============================================================

use std::collections::HashMap;

use crate::domain::{
    AppError,
    note::{Note, NoteStats, NoteType, NoteWithBook},
};
use sqlx::{QueryBuilder, SqlitePool};

use crate::domain::book::book_repo::BookRepository;

const SQL_UPSERT_NOTE: &str = "\
INSERT INTO notes (id, book_id, chapter_index, chapter_id, char_offset, length, note_type, content, selected_text, highlight_color, paired_note_id, language, created_at, updated_at) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
chapter_id = excluded.chapter_id, \
char_offset = excluded.char_offset, \
length = excluded.length, \
note_type = excluded.note_type, \
content = excluded.content, \
selected_text = excluded.selected_text, \
highlight_color = excluded.highlight_color, \
paired_note_id = excluded.paired_note_id, \
language = excluded.language, \
updated_at = excluded.updated_at";

/// 笔记仓储 — 管理笔记（高亮/标注）的增删改查
#[frb(opaque)]
pub struct NoteRepository;

impl NoteRepository {
    /// 保存或更新笔记
    pub async fn save(pool: &SqlitePool, note: &Note) -> Result<Note, AppError> {
        sqlx::query(SQL_UPSERT_NOTE)
            .bind(&note.id)
            .bind(&note.book_id)
            .bind(note.chapter_index)
            .bind(&note.chapter_id)
            .bind(note.char_offset)
            .bind(note.length)
            .bind(note.note_type.as_ref())
            .bind(&note.content)
            .bind(&note.selected_text)
            .bind(note.highlight_color)
            .bind(&note.paired_note_id)
            .bind(&note.language)
            .bind(note.created_at)
            .bind(note.updated_at)
            .execute(pool)
            .await?;
        Ok(note.clone())
    }

    /// 获取指定书籍的所有笔记
    pub async fn list_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes WHERE book_id = ? ORDER BY chapter_index, char_offset",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    /// 批量获取多本书的所有笔记
    ///
    /// # 参数
    /// `book_ids` - 书籍 ID 列表（为空时返回空 HashMap）
    ///
    /// # 返回值
    /// 按 book_id 分组的笔记 HashMap
    pub async fn list_by_books_batch(
        pool: &SqlitePool,
        book_ids: &[String],
    ) -> Result<HashMap<String, Vec<Note>>, AppError> {
        if book_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let mut builder =
            QueryBuilder::<sqlx::Sqlite>::new("SELECT * FROM notes WHERE book_id IN (");

        // 使用 push_separated 自动处理占位符和逗号
        let mut separated = builder.separated(", ");
        for id in book_ids {
            separated.push_bind(id);
        }
        separated.push_unseparated(") ORDER BY book_id, chapter_index, char_offset");

        let notes = builder.build_query_as::<Note>().fetch_all(pool).await?;

        // 按 book_id 分组
        let mut map: HashMap<String, Vec<Note>> = HashMap::new();
        for note in notes {
            map.entry(note.book_id.clone()).or_default().push(note);
        }

        Ok(map)
    }

    /// 按类型筛选笔记
    pub async fn find_by_type(
        pool: &SqlitePool,
        book_id: &str,
        note_type: NoteType,
    ) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND note_type = ? ORDER BY chapter_index, char_offset",
    )
    .bind(book_id)
    .bind(note_type.as_ref())
    .fetch_all(pool)
    .await?)
    }

    /// 获取指定章节的所有笔记
    pub async fn find_by_chapter(
        pool: &SqlitePool,
        book_id: &str,
        chapter_index: i64,
    ) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? ORDER BY char_offset",
        )
        .bind(book_id)
        .bind(chapter_index)
        .fetch_all(pool)
        .await?)
    }

    /// 按类型筛选指定章节的笔记
    pub async fn find_by_type_in_chapter(
        pool: &SqlitePool,
        book_id: &str,
        chapter_index: i64,
        note_type: NoteType,
    ) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? AND note_type = ? ORDER BY char_offset",
    )
    .bind(book_id)
    .bind(chapter_index)
    .bind(note_type.as_ref())
    .fetch_all(pool)
    .await?)
    }

    /// 按 ID 查找笔记
    pub async fn find_by_id(pool: &SqlitePool, note_id: &str) -> Result<Option<Note>, AppError> {
        Ok(
            sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE id = ?")
                .bind(note_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 删除单个笔记
    pub async fn delete_by_id(pool: &SqlitePool, note_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM notes WHERE id = ?")
            .bind(note_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 删除指定书籍的所有笔记
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM notes WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 查找配对笔记
    pub async fn find_partner_note(
        pool: &SqlitePool,
        pair_id: &str,
        exclude_id: &str,
    ) -> Result<Option<Note>, AppError> {
        Ok(
            sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE paired_note_id = ? AND id != ?")
                .bind(pair_id)
                .bind(exclude_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 批量查找配对笔记
    ///
    /// 根据多组 (pair_id, exclude_id) 一次性查询配对对象，减少 N+1 查询。
    ///
    /// # 返回值
    /// 以 pair_id 为 key 的配对笔记 HashMap
    pub async fn find_partner_notes_batch(
        pool: &SqlitePool,
        pairs: &[(String, String)],
    ) -> Result<std::collections::HashMap<String, Note>, AppError> {
        if pairs.is_empty() {
            return Ok(std::collections::HashMap::new());
        }

        let mut builder = QueryBuilder::<sqlx::Sqlite>::new("SELECT * FROM notes WHERE ");

        // 构建 OR 连接的条件
        for (i, (pair_id, exclude_id)) in pairs.iter().enumerate() {
            if i > 0 {
                builder.push(" OR ");
            }

            builder.push("(paired_note_id = ");
            builder.push_bind(pair_id);
            builder.push(" AND id != ");
            builder.push_bind(exclude_id);
            builder.push(")");
        }

        let partners = builder.build_query_as::<Note>().fetch_all(pool).await?;

        let mut map: std::collections::HashMap<String, Note> = std::collections::HashMap::new();
        for partner in partners {
            if let Some(ref pair_id) = partner.paired_note_id {
                map.entry(pair_id.clone()).or_insert(partner);
            }
        }

        Ok(map)
    }

    /// 获取指定章节中所有已配对的笔记
    pub async fn find_paired_notes_in_chapter(
        pool: &SqlitePool,
        book_id: &str,
        chapter_index: i64,
    ) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? AND paired_note_id IS NOT NULL ORDER BY char_offset",
    )
    .bind(book_id)
    .bind(chapter_index)
    .fetch_all(pool)
    .await?)
    }

    /// 获取笔记统计（使用 query_as 替代手动 row.get）
    pub async fn find_note_stats(pool: &SqlitePool, book_id: &str) -> Result<NoteStats, AppError> {
        Ok(sqlx::query_as::<_, NoteStats>(
            "SELECT \
            COUNT(*) as total_count, \
            SUM(CASE WHEN note_type = 'highlight' THEN 1 ELSE 0 END) as highlight_count, \
            SUM(CASE WHEN note_type = 'annotation' THEN 1 ELSE 0 END) as annotation_count \
         FROM notes WHERE book_id = ?",
        )
        .bind(book_id)
        .fetch_one(pool)
        .await?)
    }

    /// 搜索笔记（内容/选中文本模糊匹配）
    pub async fn search(pool: &SqlitePool, query: &str) -> Result<Vec<Note>, AppError> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }
        // 转义 LIKE 通配符，防止用户输入干扰查询语义
        let escaped = query.replace('%', r"\%").replace('_', r"\_");
        let pattern = format!("%{}%", escaped);

        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes WHERE content LIKE ?1 ESCAPE '\\' OR selected_text LIKE ?1 ESCAPE '\\' ORDER BY created_at DESC",
        )
        .bind(&pattern)
        .fetch_all(pool)
        .await?)
    }

    /// 跨书分页获取所有笔记，按创建时间倒序
    pub async fn list_all_paginated(
        pool: &SqlitePool,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Note>, AppError> {
        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes ORDER BY created_at DESC LIMIT ?1 OFFSET ?2",
        )
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await?)
    }

    /// 分页获取所有笔记，每笔记附带书名
    pub async fn list_with_titles(
        pool: &SqlitePool,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<NoteWithBook>, AppError> {
        let notes = Self::list_all_paginated(pool, limit, offset).await?;
        let titles = BookRepository::list_titles(pool).await?;
        let title_map: HashMap<String, String> =
            titles.into_iter().map(|t| (t.book_id, t.title)).collect();
        Ok(notes
            .into_iter()
            .map(|note| {
                let book_title = title_map.get(&note.book_id).cloned().unwrap_or_default();
                NoteWithBook { note, book_title }
            })
            .collect())
    }

    /// 获取笔记总数（可选按 book_id 过滤）
    pub async fn count_filtered(pool: &SqlitePool, book_id: Option<&str>) -> Result<i32, AppError> {
        let count: i32 = if let Some(bid) = book_id {
            sqlx::query_scalar("SELECT COUNT(*) FROM notes WHERE book_id = ?")
                .bind(bid)
                .fetch_one(pool)
                .await?
        } else {
            sqlx::query_scalar("SELECT COUNT(*) FROM notes")
                .fetch_one(pool)
                .await?
        };
        Ok(count)
    }
}
