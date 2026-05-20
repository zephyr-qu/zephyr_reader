use flutter_rust_bridge::frb;


use crate::domain::AppError;
use crate::init::init_storage as rust_init_storage;
use crate::storage::ensure_storage;
use crate::storage::repos::{
    BookRepository, BookmarkRepository, CategoryRepository, ChapterRepository,
    LayoutCacheRepository, NoteRepository, ProgressRepository, SessionRepository, StatsRepository,
};

pub use crate::storage::models::{
    BookCategory, Book, BookStatus, Bookmark, Chapter, GlobalStats,
    Note, NoteType, ReadingProgress, ReadingSession, ReadingStats, NoteStats,
};

// ==================== 存储初始化 ====================

#[frb]
pub async fn init_storage(data_dir: String) -> Result<(), AppError> {
    rust_init_storage(&data_dir)
        .await
        .map_err(|e| AppError::internal(e.to_string()))
}

// ==================== 书籍操作 ====================

#[frb]
pub async fn get_all_books() -> Result<Vec<Book>, AppError> {
    async_storage!(BookRepository::list)
}

#[frb]
pub async fn save_book(book: Book) -> Result<(), AppError> {
    async_storage!(|pool| BookRepository::save(pool, &book))
}

#[frb]
pub async fn delete_book(book_id: String) -> Result<(), AppError> {
    let storage = ensure_storage().map_err(|e| AppError::database_error(e.to_string()))?;
    let pool = storage.pool().map_err(|e| AppError::database_error(e.to_string()))?;
    BookRepository::delete_by_id(&pool, &book_id)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    let kv = storage.kv();
    let cache_repo = LayoutCacheRepository::new(kv);
    if let Err(e) = cache_repo.invalidate_book_cache(&book_id) {
        tracing::warn!("清除书籍缓存失败: {}", e);
    }
    if let Err(e) = crate::api::search::delete_book_search_index(book_id).await {
        tracing::warn!("清除搜索索引失败: {}", e);
    }
    Ok(())
}

#[frb]
pub async fn search_books(keyword: String) -> Result<Vec<Book>, AppError> {
    async_storage!(|pool| BookRepository::search(pool, &keyword))
}

#[frb]
pub async fn get_book(book_id: String) -> Result<Option<Book>, AppError> {
    async_storage!(|pool| BookRepository::find_by_id(pool, &book_id))
}

#[frb]
pub async fn get_books_by_status(status: BookStatus) -> Result<Vec<Book>, AppError> {
    async_storage!(|pool| BookRepository::list_by_status(pool, status))
}

#[frb]
pub async fn get_pinned_books() -> Result<Vec<Book>, AppError> {
    async_storage!(BookRepository::list_pinned)
}

#[frb]
pub async fn get_recently_read_books(limit: usize) -> Result<Vec<Book>, AppError> {
    async_storage!(|pool| BookRepository::list_recently(pool, limit))
}

#[frb]
pub async fn get_books_paginated(
    limit: i32,
    offset: i32,
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<Book>, AppError> {
    let sort_by = sort_by.unwrap_or_else(|| "added_at".to_string());
    let sort_order = sort_order.unwrap_or_else(|| "desc".to_string());
    async_storage!(|pool| BookRepository::list_paginated(
        pool,
        limit as i64,
        offset as i64,
        &sort_by,
        &sort_order
    ))
}

#[frb]
pub async fn get_book_count() -> Result<i64, AppError> {
    async_storage!(BookRepository::count)
}

// ==================== 阅读进度操作 ====================

#[frb]
pub async fn get_reading_progress(book_id: String) -> Result<Option<ReadingProgress>, AppError> {
    async_storage!(|pool| ProgressRepository::get_progress(pool, &book_id))
}

#[frb]
pub async fn save_reading_progress(progress: ReadingProgress) -> Result<(), AppError> {
    async_storage!(|pool| ProgressRepository::save_progress(pool, &progress))
}

#[frb]
pub async fn clear_reading_progress(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| ProgressRepository::clear_progress(pool, &book_id))
}

// ==================== 书签操作 ====================

#[frb]
pub async fn get_bookmarks(book_id: String) -> Result<Vec<Bookmark>, AppError> {
    async_storage!(|pool| BookmarkRepository::get_bookmarks(pool, &book_id))
}

#[frb]
pub async fn create_bookmark(bookmark: Bookmark) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::create_bookmark(pool, &bookmark))
}

#[frb]
pub async fn delete_bookmark(bookmark_id: String) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::delete_bookmark(pool, &bookmark_id))
}

#[frb]
pub async fn get_bookmark(bookmark_id: String) -> Result<Option<Bookmark>, AppError> {
    async_storage!(|pool| BookmarkRepository::get_bookmark(pool, &bookmark_id))
}

#[frb]
pub async fn delete_bookmarks_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::delete_bookmarks_by_book(pool, &book_id))
}

#[frb]
pub async fn import_bookmarks(bookmarks: Vec<Bookmark>) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::import_bookmarks(pool, &bookmarks))
}

#[frb]
pub async fn sync_bookmarks(
    local_bookmarks: Vec<Bookmark>,
    remote_bookmarks: Vec<Bookmark>,
) -> Result<Vec<Bookmark>, AppError> {
    async_storage!(|pool| BookmarkRepository::sync_bookmarks(
        pool,
        &local_bookmarks,
        &remote_bookmarks
    ))
}

#[frb]
pub async fn get_bookmark_stats(book_id: String) -> Result<i32, AppError> {
    async_storage!(|pool| BookmarkRepository::get_bookmark_stats(pool, &book_id))
}

// ==================== 阅读会话操作 ====================

#[frb]
pub async fn record_reading_session(session: ReadingSession) -> Result<(), AppError> {
    async_storage!(|pool| SessionRepository::record_session(pool, &session))
}

#[frb]
pub async fn get_reading_sessions(
    book_id: String,
    limit: usize,
) -> Result<Vec<ReadingSession>, AppError> {
    async_storage!(|pool| SessionRepository::get_sessions_by_book(pool, &book_id, limit))
}

#[frb]
pub async fn get_sessions_by_date_range(
    book_id: String,
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingSession>, AppError> {
    async_storage!(|pool| SessionRepository::get_sessions_by_date_range(
        pool,
        &book_id,
        &start_date,
        &end_date
    ))
}

#[frb]
pub async fn get_recent_sessions(limit: usize) -> Result<Vec<ReadingSession>, AppError> {
    async_storage!(|pool| SessionRepository::get_recent_sessions(pool, limit))
}

#[frb]
pub async fn delete_sessions_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| SessionRepository::delete_sessions_by_book(pool, &book_id))
}

// ==================== 统计操作 ====================

#[frb]
pub async fn get_today_reading_stats() -> Result<Vec<ReadingStats>, AppError> {
    async_storage!(StatsRepository::get_today_stats)
}

#[frb]
pub async fn get_reading_stats_range(
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingStats>, AppError> {
    async_storage!(|pool| StatsRepository::get_stats_range(pool, &start_date, &end_date))
}

#[frb]
pub async fn get_global_reading_stats() -> Result<GlobalStats, AppError> {
    async_storage!(StatsRepository::get_global_stats)
}

#[frb]
pub async fn update_daily_stats(stats: ReadingStats) -> Result<(), AppError> {
    async_storage!(|pool| StatsRepository::update_daily_stats(pool, &stats))
}

// ==================== 章节操作 ====================

#[frb]
pub async fn get_chapters_by_book(book_id: String) -> Result<Vec<Chapter>, AppError> {
    async_storage!(|pool| ChapterRepository::get_chapters_by_book(pool, &book_id))
}

#[frb]
pub async fn save_chapters(book_id: String, chapters: Vec<Chapter>) -> Result<(), AppError> {
    async_storage!(|pool| ChapterRepository::save_chapters(pool, &book_id, &chapters))
}

#[frb]
pub async fn delete_chapters_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| ChapterRepository::delete_chapters_by_book(pool, &book_id))
}

#[frb]
pub async fn get_chapter_by_index(
    book_id: String,
    chapter_index: i32,
) -> Result<Option<Chapter>, AppError> {
    async_storage!(|pool| ChapterRepository::get_chapter_by_index(pool, &book_id, chapter_index))
}

// ==================== 分类操作 ====================

#[frb]
pub async fn get_all_categories() -> Result<Vec<BookCategory>, AppError> {
    async_storage!(CategoryRepository::get_all_categories)
}

#[frb]
pub async fn save_category(category: BookCategory) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::save_category(pool, &category))
}

#[frb]
pub async fn delete_category(category_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::delete_category(pool, &category_id))
}

#[frb]
pub async fn get_category(category_id: String) -> Result<Option<BookCategory>, AppError> {
    async_storage!(|pool| CategoryRepository::get_category(pool, &category_id))
}

#[frb]
pub async fn get_categories_for_book(book_id: String) -> Result<Vec<BookCategory>, AppError> {
    async_storage!(|pool| CategoryRepository::get_categories_for_book(pool, &book_id))
}

#[frb]
pub async fn assign_category_to_book(book_id: String, category_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::assign_category(pool, &book_id, &category_id))
}

#[frb]
pub async fn remove_category_from_book(book_id: String, category_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::remove_category(pool, &book_id, &category_id))
}

#[frb]
pub async fn set_categories_for_book(book_id: String, category_ids: Vec<String>) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::set_categories_for_book(
        pool,
        &book_id,
        &category_ids
    ))
}

#[frb]
pub async fn clear_categories_for_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| CategoryRepository::clear_categories_for_book(pool, &book_id))
}

// ==================== 书籍扩展操作 ====================

#[frb]
pub async fn update_book_status(book_id: String, status: BookStatus) -> Result<(), AppError> {
    async_storage!(|pool| BookRepository::update_status(pool, &book_id, status))
}

#[frb]
pub async fn update_book_pin(book_id: String, is_pinned: bool) -> Result<(), AppError> {
    async_storage!(|pool| BookRepository::update_pin(pool, &book_id, is_pinned))
}

// ==================== 笔记操作 ====================

#[frb]
pub async fn create_note(note: Note) -> Result<Note, AppError> {
    async_storage!(|pool| NoteRepository::save_note(pool, &note))
}

#[frb]
pub async fn update_note(note: Note) -> Result<(), AppError> {
    async_storage!(|pool| async move { NoteRepository::save_note(pool, &note).await.map(|_| ()) })
}

#[frb]
pub async fn get_notes(book_id: String, note_type: Option<NoteType>) -> Result<Vec<Note>, AppError> {
    async_storage!(|pool| async move {
        match note_type {
            Some(nt) => NoteRepository::get_notes_by_type(pool, &book_id, nt).await,
            None => NoteRepository::get_notes(pool, &book_id).await,
        }
    })
}

#[frb]
pub async fn get_notes_in_chapter(
    book_id: String,
    chapter_index: i32,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    async_storage!(|pool| async move {
        match note_type {
            Some(nt) => {
                NoteRepository::get_notes_by_type_in_chapter(pool, &book_id, chapter_index, nt)
                    .await
            }
            None => NoteRepository::get_notes_in_chapter(pool, &book_id, chapter_index).await,
        }
    })
}

#[frb]
pub async fn delete_note(note_id: String) -> Result<(), AppError> {
    async_storage!(|pool| NoteRepository::delete_note(pool, &note_id))
}

#[frb]
pub async fn delete_notes_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| NoteRepository::delete_notes_by_book(pool, &book_id))
}

#[frb]
pub async fn get_note_stats(book_id: String) -> Result<NoteStats, AppError> {
    async_storage!(|pool| NoteRepository::get_note_stats(pool, &book_id))
}

// ==================== 数据库备份与还原 ====================

#[frb]
pub async fn export_database(dest_path: String) -> Result<(), AppError> {
    let storage = ensure_storage().map_err(|e| AppError::database_error(e.to_string()))?;
    storage
        .export_db(&dest_path)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    Ok(())
}

#[frb]
pub async fn restore_database(backup_path: String) -> Result<(), AppError> {
    let storage = ensure_storage().map_err(|e| AppError::database_error(e.to_string()))?;
    storage
        .restore_from_backup(&backup_path)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    Ok(())
}
