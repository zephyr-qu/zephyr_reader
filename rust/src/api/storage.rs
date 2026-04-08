//! 存储层 FFI API
//!
//! 通过 flutter_rust_bridge 暴露存储操作到 Flutter 端

use crate::api::ApiResult;
pub use crate::storage::models::{
    DbBookCategory, DbBookFormat, DbBookRecord, DbBookStatus, DbBookmark, DbChapter,
    DbDailyReadingStats, DbGlobalStats, DbLayoutCache, DbNote, DbNoteType, DbReadingProgress,
    DbReadingSession, DbSyncRecord, DbSyncStatus, LayoutCacheKey,
};

use crate::storage::ensure_storage;
use crate::storage::repositories::{
    BookRepository, BookmarkRepository, CategoryRepository, ChapterRepository,
    LayoutCacheRepository, NoteRepository, ProgressRepository, SessionRepository, StatsRepository,
    SyncRepository,
};
use flutter_rust_bridge::frb;

// ==================== 存储操作====================

/// 简化存储操作的宏
/// 用法：`storage_op!(|db| Repository::new(db).some_method())`
///
/// 注意：此宏同时适用于读写操作。对于写操作，底层数据库方法
/// 会通过事务确保原子性
macro_rules! storage_op {
    // 模式 1：保留原始返回值
    ($op:expr) => {{
        let db = ensure_storage()?.db();
        $op(db).map_err(Into::into)
    }};

    // 模式 2：指定返回 ()，丢弃原 Ok 值
    ($op:expr => ()) => {{
        let db = ensure_storage()?.db();
        $op(db).map(|_| ()).map_err(Into::into)
    }};
}

/// 获取所有书籍
#[frb]
pub fn get_all_books() -> ApiResult<Vec<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).list())
}

/// 保存书籍
#[frb]
pub fn save_book(book: DbBookRecord) -> ApiResult<()> {
    storage_op!(|db| BookRepository::new(db).save(&book))
}

/// 删除书籍
#[frb]
pub fn delete_book(book_id: String) -> ApiResult<()> {
    storage_op!(|db| BookRepository::new(db).delete_by_id(&book_id))
}

/// 搜索书籍
#[frb]
pub fn search_books(keyword: String) -> ApiResult<Vec<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).search(&keyword))
}

/// 获取章节列表
#[frb]
pub fn get_chapters_by_book(book_id: String) -> ApiResult<Vec<DbChapter>> {
    storage_op!(|db| ChapterRepository::new(db).get_chapters_by_book(&book_id))
}

/// 保存章节列表
#[frb]
pub fn save_chapters(book_id: String, chapters: Vec<DbChapter>) -> ApiResult<()> {
    storage_op!(|db| ChapterRepository::new(db).save_chapters(&book_id, &chapters))
}

/// 删除书籍的所有章节
#[frb]
pub fn delete_chapters_by_book(book_id: String) -> ApiResult<()> {
    storage_op!(|db| ChapterRepository::new(db).delete_chapters_by_book(&book_id))
}

/// 获取阅读进度
#[frb]
pub fn get_reading_progress(book_id: String) -> ApiResult<Option<DbReadingProgress>> {
    storage_op!(|db| ProgressRepository::new(db).get_progress(&book_id))
}

/// 保存阅读进度
#[frb]
pub fn save_reading_progress(progress: DbReadingProgress) -> ApiResult<()> {
    storage_op!(|db| ProgressRepository::new(db).save_progress(&progress))
}

/// 清除阅读进度
#[frb]
pub fn clear_reading_progress(book_id: String) -> ApiResult<()> {
    storage_op!(|db| ProgressRepository::new(db).clear_progress(&book_id))
}

/// 获取书签列表
#[frb]
pub fn get_bookmarks(book_id: String) -> ApiResult<Vec<DbBookmark>> {
    storage_op!(|db| BookmarkRepository::new(db).get_bookmarks(&book_id))
}

/// 创建书签
#[frb]
pub fn create_bookmark(bookmark: DbBookmark) -> ApiResult<()> {
    storage_op!(|db| BookmarkRepository::new(db).create_bookmark(&bookmark) => ())
}

/// 删除书签
#[frb]
pub fn delete_bookmark(bookmark_id: String) -> ApiResult<()> {
    storage_op!(|db| BookmarkRepository::new(db).delete_bookmark(&bookmark_id))
}

/// 记录阅读会话
#[frb]
pub fn record_reading_session(session: DbReadingSession) -> ApiResult<()> {
    storage_op!(|db| SessionRepository::new(db).record_session(&session))
}

/// 获取今日统计
#[frb]
pub fn get_today_reading_stats() -> ApiResult<DbDailyReadingStats> {
    storage_op!(|db| StatsRepository::new(db).get_today_stats())
}

/// 获取日期范围统计
#[frb]
pub fn get_reading_stats_range(
    start_date: String,
    end_date: String,
) -> ApiResult<Vec<DbDailyReadingStats>> {
    storage_op!(|db| StatsRepository::new(db).get_stats_range(&start_date, &end_date))
}

/// 获取全局统计
#[frb]
pub fn get_global_reading_stats() -> ApiResult<DbGlobalStats> {
    storage_op!(|db| StatsRepository::new(db).get_global_stats())
}

/// 获取所有分类
#[frb]
pub fn get_all_categories() -> ApiResult<Vec<DbBookCategory>> {
    storage_op!(|db| CategoryRepository::new(db).get_all_categories())
}

/// 保存分类
#[frb]
pub fn save_category(category: DbBookCategory) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).save_category(&category))
}

/// 删除分类
#[frb]
pub fn delete_category(category_id: String) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).delete_category(&category_id))
}

/// 获取书籍的分类
#[frb]
pub fn get_categories_for_book(book_id: String) -> ApiResult<Vec<DbBookCategory>> {
    storage_op!(|db| CategoryRepository::new(db).get_categories_for_book(&book_id))
}

/// 分配分类到书籍
#[frb]
pub fn assign_category_to_book(book_id: String, category_id: String) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).assign_category(&book_id, &category_id))
}

/// 移除书籍的分类
#[frb]
pub fn remove_category_from_book(book_id: String, category_id: String) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).remove_category(&book_id, &category_id))
}

/// 设置书籍的分类列表
#[frb]
pub fn set_categories_for_book(book_id: String, category_ids: Vec<String>) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).set_categories_for_book(&book_id, &category_ids))
}

/// 保存排版缓存
#[frb]
pub fn save_layout_cache(cache: DbLayoutCache, key: LayoutCacheKey) -> ApiResult<()> {
    storage_op!(|_db| {
        let kv = ensure_storage()?.kv();
        let repo = LayoutCacheRepository::new(kv);
        repo.save_layout_cache(&cache, &key)
    })
}

/// 获取排版缓存
#[frb]
pub fn get_layout_cache(
    book_id: String,
    chapter_index: i32,
    config_hash: String,
) -> ApiResult<Option<DbLayoutCache>> {
    storage_op!(|_db| {
        let kv = ensure_storage()?.kv();
        let repo = LayoutCacheRepository::new(kv);
        repo.get_cached_layout(&book_id, chapter_index, &config_hash)
    })
}

/// 清除书籍排版缓存
#[frb]
pub fn clear_layout_cache(book_id: String) -> ApiResult<()> {
    storage_op!(|_db| {
        let kv = ensure_storage()?.kv();
        let repo = LayoutCacheRepository::new(kv);
        repo.invalidate_book_cache(&book_id)
    })
}

/// 清理过期排版缓存
#[frb]
pub fn cleanup_expired_layout_cache(max_age_days: i64) -> ApiResult<usize> {
    storage_op!(|_db| {
        let kv = ensure_storage()?.kv();
        let repo = LayoutCacheRepository::new(kv);
        repo.cleanup_expired(max_age_days)
    })
}

// ── Book ──────────────────────────────────────────────────────────────────────

/// 根据 ID 获取书籍
#[frb]
pub fn get_book(book_id: String) -> ApiResult<Option<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).find_by_id(&book_id))
}

/// 按状态筛选书籍
#[frb]
pub fn get_books_by_status(status: DbBookStatus) -> ApiResult<Vec<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).list_by_status(status))
}

/// 获取置顶书籍
#[frb]
pub fn get_pinned_books() -> ApiResult<Vec<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).list_by_pinned_books())
}

/// 获取最近阅读的书籍
#[frb]
pub fn get_recently_read_books(limit: usize) -> ApiResult<Vec<DbBookRecord>> {
    storage_op!(|db| BookRepository::new(db).list_by_recently(limit))
}

// ── Bookmark ──────────────────────────────────────────────────────────────────

/// 获取单个书签详情
#[frb]
pub fn get_bookmark(bookmark_id: String) -> ApiResult<Option<DbBookmark>> {
    storage_op!(|db| BookmarkRepository::new(db).get_bookmark(&bookmark_id))
}

/// 删除书籍的所有书签
#[frb]
pub fn delete_bookmarks_by_book(book_id: String) -> ApiResult<()> {
    storage_op!(|db| BookmarkRepository::new(db).delete_bookmarks_by_book(&book_id))
}

/// 导入书签列表（upsert）
#[frb]
pub fn import_bookmarks(bookmarks: Vec<DbBookmark>) -> ApiResult<()> {
    storage_op!(|db| BookmarkRepository::new(db).import_bookmarks(bookmarks))
}

// ── Session ───────────────────────────────────────────────────────────────────

/// 获取书籍的阅读会话列表
#[frb]
pub fn get_reading_sessions(book_id: String, limit: usize) -> ApiResult<Vec<DbReadingSession>> {
    storage_op!(|db| SessionRepository::new(db).get_sessions_by_book(&book_id, limit))
}

/// 获取日期范围内的阅读会话
#[frb]
pub fn get_sessions_by_date_range(
    book_id: String,
    start_date: String,
    end_date: String,
) -> ApiResult<Vec<DbReadingSession>> {
    storage_op!(|db| SessionRepository::new(db).get_sessions_by_date_range(
        &book_id,
        &start_date,
        &end_date
    ))
}

/// 获取最近的阅读会话（跨书籍）
#[frb]
pub fn get_recent_sessions(limit: usize) -> ApiResult<Vec<DbReadingSession>> {
    storage_op!(|db| SessionRepository::new(db).get_recent_sessions(limit))
}

/// 删除书籍的所有阅读会话
#[frb]
pub fn delete_sessions_by_book(book_id: String) -> ApiResult<()> {
    storage_op!(|db| SessionRepository::new(db).delete_sessions_by_book(&book_id))
}

// ── Sync ──────────────────────────────────────────────────────────────────────

/// 保存同步记录
#[frb]
pub fn save_sync_record(record: DbSyncRecord) -> ApiResult<()> {
    storage_op!(|db| SyncRepository::new(db).record_sync(&record))
}

/// 获取待同步记录
#[frb]
pub fn get_pending_sync_records(book_id: String) -> ApiResult<Vec<DbSyncRecord>> {
    storage_op!(|db| SyncRepository::new(db).get_pending_sync(&book_id))
}

/// 更新同步状态
#[frb]
pub fn update_sync_status(
    record_id: String,
    status: DbSyncStatus,
    remote_version: Option<i32>,
) -> ApiResult<()> {
    storage_op!(|db| SyncRepository::new(db).update_sync_status(&record_id, status, remote_version))
}

/// 获取同步冲突记录
#[frb]
pub fn get_sync_conflicts(book_id: String) -> ApiResult<Vec<DbSyncRecord>> {
    storage_op!(|db| SyncRepository::new(db).get_sync_conflicts(&book_id))
}

/// 清除同步冲突（标记为已同步）
#[frb]
pub fn clear_sync_conflicts(book_id: String) -> ApiResult<()> {
    storage_op!(|db| SyncRepository::new(db).clear_sync_conflicts(&book_id))
}

/// 删除同步记录
#[frb]
pub fn delete_sync_record(record_id: String) -> ApiResult<()> {
    storage_op!(|db| SyncRepository::new(db).delete_sync_record(&record_id))
}

// ── Category ──────────────────────────────────────────────────────────────────

/// 获取单个分类详情
#[frb]
pub fn get_category(category_id: String) -> ApiResult<Option<DbBookCategory>> {
    storage_op!(|db| CategoryRepository::new(db).get_category(&category_id))
}

/// 清除书籍的所有分类关系
#[frb]
pub fn clear_categories_for_book(book_id: String) -> ApiResult<()> {
    storage_op!(|db| CategoryRepository::new(db).clear_categories_for_book(&book_id))
}

// ── Chapter ───────────────────────────────────────────────────────────────────

/// 获取指定章节
#[frb]
pub fn get_chapter_by_index(book_id: String, chapter_index: i32) -> ApiResult<Option<DbChapter>> {
    storage_op!(|db| ChapterRepository::new(db).get_chapter_by_index(&book_id, chapter_index))
}

/// 同步书签（本地与远端合并，返回合并后列表）
#[frb]
pub fn sync_bookmarks(
    local_bookmarks: Vec<DbBookmark>,
    remote_bookmarks: Vec<DbBookmark>,
) -> ApiResult<Vec<DbBookmark>> {
    storage_op!(|db| BookmarkRepository::new(db).sync_bookmarks(local_bookmarks, remote_bookmarks))
}

/// 获取书签统计（总数）
#[frb]
pub fn get_bookmark_stats(book_id: String) -> ApiResult<i32> {
    storage_op!(|db| BookmarkRepository::new(db).get_bookmark_stats(&book_id))
}

// ── Sync ──────────────────────────────────────────────────────────────────────

/// 清除所有同步记录
#[frb]
pub fn clear_all_sync_records() -> ApiResult<()> {
    storage_op!(|db| SyncRepository::new(db).clear_all_sync_records())
}

// ── Note ──────────────────────────────────────────────────────────────────────

/// 创建笔记
#[frb]
pub fn create_note(note: DbNote) -> ApiResult<DbNote> {
    storage_op!(|db| NoteRepository::new(db).save_note(&note))
}

/// 获取笔记列表
#[frb]
pub fn get_notes(book_id: String, note_type: Option<DbNoteType>) -> ApiResult<Vec<DbNote>> {
    storage_op!(|db| {
        let repo = NoteRepository::new(db);
        match note_type {
            Some(nt) => repo.get_notes_by_type(&book_id, nt),
            None => repo.get_notes(&book_id),
        }
    })
}

/// 删除笔记
#[frb]
pub fn delete_note(note_id: String) -> ApiResult<()> {
    storage_op!(|db| NoteRepository::new(db).delete_note(&note_id))
}

#[frb]
pub fn update_daily_stats(stats: DbDailyReadingStats) -> ApiResult<()> {
    storage_op!(|db| StatsRepository::new(db).update_daily_stats(&stats))
}
