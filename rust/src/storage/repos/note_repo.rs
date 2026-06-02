use std::collections::HashMap;

use anyhow::Result;
use sqlx::{QueryBuilder, SqlitePool};

use super::super::models::*;

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

pub struct NoteRepository;

impl NoteRepository {
    /// 保存或更新笔记
    pub async fn save(pool: &SqlitePool, note: &Note) -> Result<Note> {
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
            .bind(note.created_at.timestamp())
            .bind(note.updated_at.timestamp())
            .execute(pool)
            .await?;
        Ok(note.clone())
    }

    /// 获取指定书籍的所有笔记
    pub async fn list_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Note>> {
        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes WHERE book_id = ? ORDER BY chapter_index, char_offset",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    pub async fn list_by_books_batch(
        pool: &SqlitePool,
        book_ids: &[String],
    ) -> Result<HashMap<String, Vec<Note>>> {
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
    ) -> Result<Vec<Note>> {
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
        chapter_index: i32,
    ) -> Result<Vec<Note>> {
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
        chapter_index: i32,
        note_type: NoteType,
    ) -> Result<Vec<Note>> {
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
    pub async fn find_by_id(pool: &SqlitePool, note_id: &str) -> Result<Option<Note>> {
        Ok(
            sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE id = ?")
                .bind(note_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 删除单个笔记
    pub async fn delete_by_id(pool: &SqlitePool, note_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM notes WHERE id = ?")
            .bind(note_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 删除指定书籍的所有笔记
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<()> {
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
    ) -> Result<Option<Note>> {
        Ok(
            sqlx::query_as::<_, Note>("SELECT * FROM notes WHERE paired_note_id = ? AND id != ?")
                .bind(pair_id)
                .bind(exclude_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    pub async fn find_partner_notes_batch(
        pool: &SqlitePool,
        pairs: &[(String, String)],
    ) -> Result<std::collections::HashMap<String, Note>> {
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
        chapter_index: i32,
    ) -> Result<Vec<Note>> {
        Ok(sqlx::query_as::<_, Note>(
            "SELECT * FROM notes WHERE book_id = ? AND chapter_index = ? AND paired_note_id IS NOT NULL ORDER BY char_offset",
        )
        .bind(book_id)
        .bind(chapter_index)
        .fetch_all(pool)
        .await?)
    }

    /// 获取笔记统计（使用 query_as 替代手动 row.get）
    pub async fn find_note_stats(pool: &SqlitePool, book_id: &str) -> Result<NoteStats> {
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
