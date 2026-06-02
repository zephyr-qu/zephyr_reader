use anyhow::Result;
use sqlx::SqlitePool;

use super::super::models::*;

const SQL_UPSERT_BOOKMARK: &str = "\
INSERT INTO bookmarks (id, book_id, chapter_index, chapter_id, char_offset, title, created_at) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
chapter_id = excluded.chapter_id, \
char_offset = excluded.char_offset, \
title = excluded.title, \
created_at = excluded.created_at";

pub struct BookmarkRepository;

impl BookmarkRepository {
    /// 创建或更新书签
    pub async fn save(pool: &SqlitePool, bookmark: &Bookmark) -> Result<Bookmark> {
        sqlx::query(SQL_UPSERT_BOOKMARK)
            .bind(&bookmark.id)
            .bind(&bookmark.book_id)
            .bind(bookmark.chapter_index)
            .bind(&bookmark.chapter_id)
            .bind(bookmark.char_offset)
            .bind(&bookmark.title)
            .bind(bookmark.created_at.timestamp())
            .execute(pool)
            .await?;
        Ok(bookmark.clone())
    }

    /// 获取指定书籍的所有书签
    pub async fn find_by_book(pool: &SqlitePool, book_id: &str) -> Result<Vec<Bookmark>> {
        Ok(sqlx::query_as::<_, Bookmark>(
            "SELECT * FROM bookmarks WHERE book_id = ? ORDER BY chapter_index, char_offset",
        )
        .bind(book_id)
        .fetch_all(pool)
        .await?)
    }

    /// 删除单个书签
    pub async fn delete_by_id(pool: &SqlitePool, bookmark_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM bookmarks WHERE id = ?")
            .bind(bookmark_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 按 ID 查找书签
    pub async fn find_by_id(pool: &SqlitePool, bookmark_id: &str) -> Result<Option<Bookmark>> {
        Ok(
            sqlx::query_as::<_, Bookmark>("SELECT * FROM bookmarks WHERE id = ?")
                .bind(bookmark_id)
                .fetch_optional(pool)
                .await?,
        )
    }

    /// 批量导入书签
    pub async fn import_bookmarks(pool: &SqlitePool, bookmarks: &[Bookmark]) -> Result<()> {
        if bookmarks.is_empty() {
            return Ok(());
        }
        let mut tx = pool.begin().await?;
        for bookmark in bookmarks {
            sqlx::query(SQL_UPSERT_BOOKMARK)
                .bind(&bookmark.id)
                .bind(&bookmark.book_id)
                .bind(bookmark.chapter_index)
                .bind(&bookmark.chapter_id)
                .bind(bookmark.char_offset)
                .bind(&bookmark.title)
                .bind(bookmark.created_at.timestamp())
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }
    /// 删除指定书籍的所有书签
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<()> {
        sqlx::query("DELETE FROM bookmarks WHERE book_id = ?")
            .bind(book_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取指定书籍的书签数量
    pub async fn count_by_book(pool: &SqlitePool, book_id: &str) -> Result<i32> {
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM bookmarks WHERE book_id = ?")
            .bind(book_id)
            .fetch_one(pool)
            .await?;
        Ok(count as i32)
    }
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::test_utils::*;
//     use crate::storage::repos::book_repo::BookRepository;

//     #[tokio::test]
//     async fn test_create_bookmark() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let bm = test_bookmark("book1", 0);
//         BookmarkRepository::create_bookmark(&pool, &bm).await.unwrap();
//         let bookmarks = BookmarkRepository::get_bookmarks(&pool, "book1").await.unwrap();
//         assert_eq!(bookmarks.len(), 1);
//         assert_eq!(bookmarks[0].title, "书签-第1章");
//     }

//     #[tokio::test]
//     async fn test_get_bookmarks_by_book() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         BookmarkRepository::create_bookmark(&pool, &test_bookmark("book1", 0)).await.unwrap();
//         BookmarkRepository::create_bookmark(&pool, &test_bookmark("book1", 1)).await.unwrap();
//         let bookmarks = BookmarkRepository::get_bookmarks(&pool, "book1").await.unwrap();
//         assert_eq!(bookmarks.len(), 2);
//         let other = BookmarkRepository::get_bookmarks(&pool, "other").await.unwrap();
//         assert!(other.is_empty());
//     }

//     #[tokio::test]
//     async fn test_get_bookmark() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let bm = test_bookmark("book1", 0);
//         BookmarkRepository::create_bookmark(&pool, &bm).await.unwrap();
//         let found = BookmarkRepository::get_bookmark(&pool, &bm.id).await.unwrap();
//         assert!(found.is_some());
//         let missing = BookmarkRepository::get_bookmark(&pool, "nonexistent").await.unwrap();
//         assert!(missing.is_none());
//     }

//     #[tokio::test]
//     async fn test_delete_bookmark() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let bm = test_bookmark("book1", 0);
//         BookmarkRepository::create_bookmark(&pool, &bm).await.unwrap();
//         BookmarkRepository::delete_bookmark(&pool, &bm.id).await.unwrap();
//         let bookmarks = BookmarkRepository::get_bookmarks(&pool, "book1").await.unwrap();
//         assert!(bookmarks.is_empty());
//     }

//     #[tokio::test]
//     async fn test_delete_bookmarks_by_book() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         BookmarkRepository::create_bookmark(&pool, &test_bookmark("book1", 0)).await.unwrap();
//         BookmarkRepository::create_bookmark(&pool, &test_bookmark("book1", 1)).await.unwrap();
//         BookmarkRepository::delete_bookmarks_by_book(&pool, "book1").await.unwrap();
//         let remaining = BookmarkRepository::get_bookmarks(&pool, "book1").await.unwrap();
//         assert!(remaining.is_empty());
//     }
// }
