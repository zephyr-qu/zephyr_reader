use std::collections::HashMap;

use crate::domain::AppError;
use sqlx::{QueryBuilder, SqlitePool};

use super::super::models::*;
use super::BookRepository;

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
pub struct NoteRepository;

impl NoteRepository {
    /// 保存或更新笔记
    pub async fn save(pool: &SqlitePool, note: &Note) -> Result<Note, AppError> { sqlx::query(SQL_UPSERT_NOTE)
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
    Ok(note.clone()) }

    /// 获取指定书籍的所有笔记
    pub async fn list_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? ORDER BY chapter_index, char_offset",
    )
    .bind(book_id)
    .fetch_all(pool)
    .await?) }

    /// 批量获取多本书的所有笔记
    ///
    /// # 参数
    /// `book_ids` - 书籍 ID 列表（为空时返回空 HashMap）
    ///
    /// # 返回值
    /// 按 book_id 分组的笔记 HashMap
    pub async fn list_by_books_batch(pool: &SqlitePool,
    book_ids: &[String],) -> Result<HashMap<String, Vec<Note>>, AppError> { if book_ids.is_empty() {
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
    
    Ok(map) }

    /// 按类型筛选笔记
    pub async fn find_by_type(pool: &SqlitePool,
    book_id: &str,
    note_type: NoteType,) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND note_type = ? ORDER BY chapter_index, char_offset",
    )
    .bind(book_id)
    .bind(note_type.as_ref())
    .fetch_all(pool)
    .await?) }

    /// 获取指定章节的所有笔记
    pub async fn find_by_chapter(pool: &SqlitePool,
    book_id: &str,
    chapter_index: i64,) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? ORDER BY char_offset",
    )
    .bind(book_id)
    .bind(chapter_index)
    .fetch_all(pool)
    .await?) }

    /// 按类型筛选指定章节的笔记
    pub async fn find_by_type_in_chapter(pool: &SqlitePool,
    book_id: &str,
    chapter_index: i64,
    note_type: NoteType,) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? AND note_type = ? ORDER BY char_offset",
    )
    .bind(book_id)
    .bind(chapter_index)
    .bind(note_type.as_ref())
    .fetch_all(pool)
    .await?) }

    /// 按 ID 查找笔记
    pub async fn find_by_id(pool: &SqlitePool, note_id: &str) -> Result<Option<Note>, AppError> { Ok(
        sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE id = ?")
            .bind(note_id)
            .fetch_optional(pool)
            .await?,
    ) }

    /// 删除单个笔记
    pub async fn delete_by_id(pool: &SqlitePool, note_id: &str) -> Result<(), AppError> { sqlx::query("DELETE FROM notes WHERE id = ?")
        .bind(note_id)
        .execute(pool)
        .await?;
    Ok(()) }

    /// 删除指定书籍的所有笔记
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> { sqlx::query("DELETE FROM notes WHERE book_id = ?")
        .bind(book_id)
        .execute(pool)
        .await?;
    Ok(()) }

    /// 查找配对笔记
    pub async fn find_partner_note(pool: &SqlitePool,
    pair_id: &str,
    exclude_id: &str,) -> Result<Option<Note>, AppError> { Ok(
        sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE paired_note_id = ? AND id != ?")
            .bind(pair_id)
            .bind(exclude_id)
            .fetch_optional(pool)
            .await?,
    ) }

    /// 批量查找配对笔记
    ///
    /// 根据多组 (pair_id, exclude_id) 一次性查询配对对象，减少 N+1 查询。
    ///
    /// # 返回值
    /// 以 pair_id 为 key 的配对笔记 HashMap
    pub async fn find_partner_notes_batch(pool: &SqlitePool,
    pairs: &[(String, String)],) -> Result<std::collections::HashMap<String, Note>, AppError> { if pairs.is_empty() {
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
    
    Ok(map) }

    /// 获取指定章节中所有已配对的笔记
    pub async fn find_paired_notes_in_chapter(pool: &SqlitePool,
    book_id: &str,
    chapter_index: i64,) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? AND paired_note_id IS NOT NULL ORDER BY char_offset",
    )
    .bind(book_id)
    .bind(chapter_index)
    .fetch_all(pool)
    .await?) }

    /// 获取笔记统计（使用 query_as 替代手动 row.get）
    pub async fn find_note_stats(pool: &SqlitePool, book_id: &str) -> Result<NoteStats, AppError> { Ok(sqlx::query_as::<_, NoteStats>(
        "SELECT \
            COUNT(*) as total_count, \
            SUM(CASE WHEN note_type = 'highlight' THEN 1 ELSE 0 END) as highlight_count, \
            SUM(CASE WHEN note_type = 'annotation' THEN 1 ELSE 0 END) as annotation_count \
         FROM notes WHERE book_id = ?",
    )
    .bind(book_id)
    .fetch_one(pool)
    .await?) }

    /// 搜索笔记（内容/选中文本模糊匹配）
    pub async fn search(pool: &SqlitePool,
    query: &str,) -> Result<Vec<Note>, AppError> { let pattern = format!("%{}%", query);
    Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes WHERE content LIKE ?1 OR selected_text LIKE ?1 ORDER BY created_at DESC",
    )
    .bind(&pattern)
    .fetch_all(pool)
    .await?) }

    /// 跨书分页获取所有笔记，按创建时间倒序
    pub async fn list_all_paginated(pool: &SqlitePool,
    limit: i64,
    offset: i64,) -> Result<Vec<Note>, AppError> { Ok(sqlx::query_as::<_, Note>(
        "SELECT * FROM notes ORDER BY created_at DESC LIMIT ?1 OFFSET ?2",
    )
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await?) }

    /// 分页获取所有笔记，每笔记附带书名
    pub async fn list_with_titles(pool: &SqlitePool,
    limit: i64,
    offset: i64,) -> Result<Vec<NoteWithBook>, AppError> { let notes = Self::list_all_paginated(pool, limit, offset).await?;
    let titles = BookRepository::list_titles(pool).await?;
    let title_map: HashMap<String, String> =
        titles.into_iter().map(|t| (t.book_id, t.title)).collect();
    Ok(notes
        .into_iter()
        .map(|note| {
            let book_title = title_map.get(&note.book_id).cloned().unwrap_or_default();
            NoteWithBook { note, book_title }
        })
        .collect()) }

    /// 获取笔记总数（可选按 book_id 过滤）
    pub async fn count_filtered(pool: &SqlitePool, book_id: Option<&str>) -> Result<i32, AppError> { let count: i32 = if let Some(bid) = book_id {
        sqlx::query_scalar("SELECT COUNT(*) FROM notes WHERE book_id = ?")
            .bind(bid)
            .fetch_one(pool)
            .await?
    } else {
        sqlx::query_scalar("SELECT COUNT(*) FROM notes")
            .fetch_one(pool)
            .await?
    };
    Ok(count) }

}
// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::test_utils::*;
//     use crate::storage::repos::book_repo::BookRepository;

//     #[tokio::test]
//     async fn test_save_and_get_note() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let note = test_highlight("book1", 0);
//         NoteRepository::save_note(&pool, &note).await.unwrap();
//         let notes = NoteRepository::get_notes(&pool, "book1").await.unwrap();
//         assert_eq!(notes.len(), 1);
//         assert_eq!(notes[0].note_type, NoteType::Highlight);
//     }

//     #[tokio::test]
//     async fn test_update_note() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let mut note = test_highlight("book1", 0);
//         NoteRepository::save_note(&pool, &note).await.unwrap();
//         note.content = "更新内容".to_string();
//         NoteRepository::save_note(&pool, &note).await.unwrap();
//         let notes = NoteRepository::get_notes(&pool, "book1").await.unwrap();
//         assert_eq!(notes.len(), 1);
//         assert_eq!(notes[0].content, "更新内容");
//     }

//     #[tokio::test]
//     async fn test_get_notes_by_book_empty() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let notes = NoteRepository::get_notes(&pool, "book1").await.unwrap();
//         assert!(notes.is_empty());
//     }

//     #[tokio::test]
//     async fn test_get_notes_in_chapter() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         NoteRepository::save_note(&pool, &test_highlight("book1", 0)).await.unwrap();
//         NoteRepository::save_note(&pool, &test_annotation("book1", 0)).await.unwrap();
//         NoteRepository::save_note(&pool, &test_highlight("book1", 1)).await.unwrap();
//         let ch0 = NoteRepository::get_notes_in_chapter(&pool, "book1", 0).await.unwrap();
//         assert_eq!(ch0.len(), 2);
//         let ch1 = NoteRepository::get_notes_in_chapter(&pool, "book1", 1).await.unwrap();
//         assert_eq!(ch1.len(), 1);
//     }

//     #[tokio::test]
//     async fn test_delete_note() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let note = test_highlight("book1", 0);
//         NoteRepository::save_note(&pool, &note).await.unwrap();
//         NoteRepository::delete_note(&pool, &note.id).await.unwrap();
//         let notes = NoteRepository::get_notes(&pool, "book1").await.unwrap();
//         assert!(notes.is_empty());
//     }

//     #[tokio::test]
//     async fn test_get_paired_notes_in_chapter() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let mut cn = Note::highlight("book1", 0, 10, 5, "中文高亮", 0xFF0000);
//         cn.paired_note_id = Some("pair1".to_string());
//         cn.language = Some("source".to_string());
//         let mut en = Note::highlight("book1", 0, 20, 5, "English highlight", 0x00FF00);
//         en.id = "note2".to_string();
//         en.paired_note_id = Some("pair1".to_string());
//         en.language = Some("target".to_string());
//         NoteRepository::save_note(&pool, &cn).await.unwrap();
//         NoteRepository::save_note(&pool, &en).await.unwrap();
//         let unpaired = Note::highlight("book1", 0, 30, 5, "独立高亮", 0x0000FF);
//         NoteRepository::save_note(&pool, &unpaired).await.unwrap();
//         let paired = NoteRepository::get_paired_notes_in_chapter(&pool, "book1", 0).await.unwrap();
//         assert_eq!(paired.len(), 2);
//     }

//     #[tokio::test]
//     async fn test_find_partner_note() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let mut cn = Note::highlight("book1", 0, 10, 5, "中文高亮", 0xFF0000);
//         cn.paired_note_id = Some("pair1".to_string());
//         let mut en = Note::highlight("book1", 0, 20, 5, "English highlight", 0x00FF00);
//         en.id = "note2".to_string();
//         en.paired_note_id = Some("pair1".to_string());
//         NoteRepository::save_note(&pool, &cn).await.unwrap();
//         NoteRepository::save_note(&pool, &en).await.unwrap();
//         let partner = NoteRepository::find_partner_note(&pool, "pair1", &cn.id).await.unwrap();
//         assert!(partner.is_some());
//         assert_eq!(partner.unwrap().id, "note2");
//     }
// }
