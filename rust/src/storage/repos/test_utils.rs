// use chrono::{DateTime, Utc};
// use sqlx::SqlitePool;

// use super::super::models::*;

// pub async fn setup_test_db() -> SqlitePool {
//     let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
//     sqlx::query("PRAGMA foreign_keys = ON")
//         .execute(&pool)
//         .await
//         .unwrap();
//     sqlx::migrate!("./migrations").run(&pool).await.unwrap();
//     pool
// }

// pub fn test_book() -> Book {
//     Book {
//         book_id: "book1".to_string(),
//         file_path: "/path/to/book.txt".to_string(),
//         file_hash: Some("abc123".to_string()),
//         file_size: 1024,
//         file_mtime: Some(1700000000),
//         title: "测试书籍".to_string(),
//         author: Some("作者A".to_string()),
//         description: Some("描述".to_string()),
//         cover_path: None,
//         chapter_count: 3,
//         total_characters: 5000,
//         format: BookFormat::Txt,
//         added_at: Utc::now(),
//         last_opened_at: Some(Utc::now()),
//         status: BookStatus::Reading,
//         is_pinned: false,
//         publisher: Some("人民出版社".to_string()),
//         translator: Some("李磊".to_string()),
//         isbn:Some("sn342523452".to_string()) ,
//     }
// }

// pub fn test_chapter(book_id: &str, index: i32) -> Chapter {
//     Chapter {
//         id: format!("ch-{}-{}", book_id, index),
//         book_id: book_id.to_string(),
//         title: format!("第{}章", index + 1),
//         content_file: format!("{}/{}.txt", book_id, index),
//         chapter_index: index,
//         word_count: 1000,
//         cached_at: Utc::now(),
//         level: 0,
//         start_index: 0,
//         end_index: 0,
//         content_length: 0,
//     }
// }

// pub fn test_bookmark(book_id: &str, chapter_index: i32) -> Bookmark {
//     Bookmark::new {
//       // id: format!("bm-{}-{}", book_id, chapter_index),
//         book_id: book_id.to_string(),
//         chapter_index,
//         chapter_id: None,
//         char_offset: 100,
//         title: format!("书签-第{}章", chapter_index + 1),
//         created_at: Utc::now(),
//       }

// }

// pub fn test_highlight(book_id: &str, chapter_index: i32) -> Note {
//     Note::highlight(book_id, chapter_index, 10, 5, "测试高亮文本", 0xFFFF00)
// }

// pub fn test_annotation(book_id: &str, chapter_index: i32) -> Note {
//     Note::annotation(book_id, chapter_index, 20, "这是一条笔记", Some("测试高亮"))
// }

// pub fn test_progress(book_id: &str) -> ReadingProgress {
//     ReadingProgress {
//         book_id: book_id.to_string(),
//         chapter_index: 1,
//         chapter_id: None,
//         char_offset: 200,
//         page_index: 5,
//         total_pages: 20,
//         progress: 0.25,
//         reading_time_seconds: 600,
//         last_read_at: Utc::now(),
//         is_completed: false,
//     }
// }

// pub fn test_session(book_id: &str, chapter_index: i32, started_at: Option<DateTime<Utc>>) -> ReadingSession {
//     let start = started_at.unwrap_or_else(|| {
//         Utc::now() - chrono::Duration::minutes(30)
//     });
//     ReadingSession {
//         id: format!("sess-{}-{}", book_id, chapter_index),
//         book_id: book_id.to_string(),
//         chapter_index,
//         chapter_id: None,
//         start_char_offset: 0,
//         end_char_offset: 500,
//         started_at: start,
//         ended_at: start + chrono::Duration::minutes(30),
//         duration_seconds: 1800,
//     }
// }

// pub fn test_category() -> BookCategory {
//     BookCategory {
//         id: "cat1".to_string(),
//         name: "科幻".to_string(),
//         description: Some("科幻小说".to_string()),
//         color: "#FF0000".to_string(),
//         sort_order: 0,
//         is_system: false,
//         created_at: Utc::now(),
//         updated_at: None,
//     }
// }

// // pub fn test_vocab_entry(word: &str, translation: &str) -> VocabEntry {
// //     VocabEntry {
// //         id: uuid::Uuid::new_v4().to_string(),
// //         word: word.to_string(),
// //         pinyin: "".to_string(),
// //         translation: translation.to_string(),
// //         context_sentence: None,
// //         book_id: None,
// //         chapter_index: None,
// //         char_offset: None,
// //         created_at: Utc::now(),
// //         review_count: 0,
// //         last_reviewed_at: None,
// //         status: "learning".to_string(),
// //         word_list: None,
// //     }
// // }
