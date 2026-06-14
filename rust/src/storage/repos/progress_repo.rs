use crate::domain::AppError;
use sqlx::SqlitePool;

use super::super::models::*;

const SQL_UPSERT_PROGRESS: &str = "\
INSERT INTO reading_progress (book_id, chapter_index, chunk_index, chapter_id, char_offset, page_index, total_pages, progress, reading_time_seconds, last_read_at, is_completed) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11) \
ON CONFLICT(book_id) DO UPDATE SET \
chapter_index = excluded.chapter_index, \
chunk_index = excluded.chunk_index, \
chapter_id = excluded.chapter_id, \
char_offset = excluded.char_offset, \
page_index = excluded.page_index, \
total_pages = excluded.total_pages, \
progress = excluded.progress, \
reading_time_seconds = excluded.reading_time_seconds, \
last_read_at = excluded.last_read_at, \
is_completed = excluded.is_completed";

/// 阅读进度仓储 — 管理阅读进度的增改查
pub struct ProgressRepository;

impl ProgressRepository {
    /// 保存或更新阅读进度
    pub async fn save(pool: &SqlitePool, progress: &ReadingProgress) -> Result<(), AppError> {
        sqlx::query(SQL_UPSERT_PROGRESS)
            .bind(&progress.book_id)
            .bind(progress.chapter_index)
            .bind(progress.chunk_index)
            .bind(&progress.chapter_id)
            .bind(progress.char_offset)
            .bind(progress.page_index)
            .bind(progress.total_pages)
            .bind(progress.progress)
            .bind(progress.reading_time_seconds)
            .bind(progress.last_read_at)
            .bind(progress.is_completed as i32)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取所有书籍的阅读进度（用于书架批量展示）
    ///
    /// 内部执行 2 次查询（books + progress），Rust 层按 book_id 匹配，
    /// 替代 Dart 侧 N+1 次 FRB 调用。
    pub async fn list_all_with_progress(pool: &SqlitePool) -> Result<Vec<BookWithProgress>, AppError> {
        let books = super::BookRepository::list_progress(pool).await?;
        let all_progress: Vec<ReadingProgress> =
            sqlx::query_as::<_, ReadingProgress>("SELECT * FROM reading_progress")
                .fetch_all(pool)
                .await?;

        let progress_map: std::collections::HashMap<&str, &ReadingProgress> = all_progress
            .iter()
            .map(|p| (p.book_id.as_str(), p))
            .collect();

        let result = books
            .into_iter()
            .map(|book| BookWithProgress {
                progress: progress_map.get(book.book_id.as_str()).copied().cloned(),
                book,
            })
            .collect();

        Ok(result)
    }

    /// 获取指定书籍的阅读进度
    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Option<ReadingProgress>, AppError> {
        Ok(
            sqlx::query_as::<_, ReadingProgress>(
                "SELECT * FROM reading_progress WHERE book_id = ?",
            )
            .bind(book_id)
            .fetch_optional(pool)
            .await?,
        )
    }

    /// 清除指定书籍的阅读进度
    pub async fn clear_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> {
        sqlx::query("DELETE FROM reading_progress WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::test_utils::*;
//     use crate::storage::repos::book_repo::BookRepository;

//     #[tokio::test]
//     async fn test_save_new_progress() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let p = test_progress("book1");
//         ProgressRepository::save_progress(&pool, &p).await.unwrap();
//         let loaded = ProgressRepository::get_progress(&pool, "book1").await.unwrap();
//         assert!(loaded.is_some());
//         assert_eq!(loaded.unwrap().progress, 0.25);
//     }

//     #[tokio::test]
//     async fn test_save_overwrite_progress() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let mut p = test_progress("book1");
//         ProgressRepository::save_progress(&pool, &p).await.unwrap();
//         p.progress = 0.9;
//         p.chapter_index = 3;
//         ProgressRepository::save_progress(&pool, &p).await.unwrap();
//         let loaded = ProgressRepository::get_progress(&pool, "book1").await.unwrap().unwrap();
//         assert_eq!(loaded.progress, 0.9);
//         assert_eq!(loaded.chapter_index, 3);
//     }

//     #[tokio::test]
//     async fn test_get_progress_not_found() {
//         let pool = setup_test_db().await;
//         let loaded = ProgressRepository::get_progress(&pool, "nonexistent").await.unwrap();
//         assert!(loaded.is_none());
//     }

//     #[tokio::test]
//     async fn test_clear_progress() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         ProgressRepository::save_progress(&pool, &test_progress("book1")).await.unwrap();
//         ProgressRepository::clear_progress(&pool, "book1").await.unwrap();
//         let loaded = ProgressRepository::get_progress(&pool, "book1").await.unwrap();
//         assert!(loaded.is_none());
//     }
// }
