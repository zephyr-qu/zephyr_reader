//! 仓库模式封装
//!
//! 为 Flutter 侧提供高层 API，隐藏数据库细节

use std::sync::Arc;

use anyhow::{Context, Result};

use super::kv_store::KvStore;
use super::models::*;

macro_rules! impl_db_repo {
    ($name:ident) => {
        pub struct $name {
            db: std::sync::Arc<parking_lot::Mutex<crate::storage::database::Database>>,
        }
        impl $name {
            pub fn new(
                db: std::sync::Arc<parking_lot::Mutex<crate::storage::database::Database>>,
            ) -> Self {
                Self { db }
            }
            #[inline]
            fn db(&self) -> parking_lot::MutexGuard<'_, crate::storage::database::Database> {
                self.db.lock()
            }
        }
    };
}
impl_db_repo!(ProgressRepository);
impl_db_repo!(BookmarkRepository);
impl_db_repo!(NoteRepository);
impl_db_repo!(StatsRepository);
impl_db_repo!(ChapterRepository);
impl_db_repo!(CategoryRepository);
impl_db_repo!(SyncRepository);
impl_db_repo!(BookRepository);
impl_db_repo!(SessionRepository);

/// 阅读进度仓库
impl ProgressRepository {
    /// 保存阅读进度
    pub fn save_progress(&self, progress: &DbReadingProgress) -> Result<()> {
        let progress_value = if progress.total_pages > 0 {
            progress.page_index as f32 / progress.total_pages as f32
        } else {
            0.0
        };

        let mut updated = progress.clone();
        updated.progress = progress_value;
        updated.last_read_at = chrono::Utc::now();
        updated.is_completed = progress_value >= 1.0;
        self.db().save_progress(&updated)
    }

    /// 获取阅读进度
    pub fn get_progress(&self, book_id: &str) -> Result<Option<DbReadingProgress>> {
        self.db().get_progress(book_id)
    }

    /// 清除阅读进度
    pub fn clear_progress(&self, book_id: &str) -> Result<()> {
        self.db().delete_progress(book_id)
    }
}

impl BookmarkRepository {
    /// 创建书签
    pub fn create_bookmark(&self, bookmark: &DbBookmark) -> Result<()> {
        self.db().save_bookmark(bookmark)?;
        Ok(())
    }

    /// 获取书签列表
    pub fn get_bookmarks(&self, book_id: &str) -> Result<Vec<DbBookmark>> {
        self.db().get_bookmarks(book_id)
    }

    /// 删除书签
    pub fn delete_bookmark(&self, bookmark_id: &str) -> Result<()> {
        self.db().delete_bookmark(bookmark_id)
    }

    /// 获取书签详情
    pub fn get_bookmark(&self, bookmark_id: &str) -> Result<Option<DbBookmark>> {
        self.db().get_bookmark_by_id(bookmark_id)
    }

    /// 批量保存书签
    pub fn import_bookmarks(&self, bookmarks: Vec<DbBookmark>) -> Result<()> {
        if bookmarks.is_empty() {
            return Ok(());
        }
        // 使用事务批量插入
        self.db().save_bookmarks_batch(&bookmarks)?;
        Ok(())
    }

    /// 同步书签（简单合并策略）
    pub fn sync_bookmarks(
        &self,
        local_bookmarks: Vec<DbBookmark>,
        remote_bookmarks: Vec<DbBookmark>,
    ) -> Result<Vec<DbBookmark>> {
        let local_ids: std::collections::HashSet<_> =
            local_bookmarks.iter().map(|b| &b.id).collect();

        let to_insert: Vec<_> = remote_bookmarks
            .into_iter()
            .filter(|bm| !local_ids.contains(&bm.id))
            .collect();

        if !to_insert.is_empty() {
            let db = self.db();
            db.save_bookmarks_batch(&to_insert)?;
        }

        Ok(local_bookmarks.into_iter().chain(to_insert).collect())
    }

    /// 删除书籍的所有书签
    pub fn delete_bookmarks_by_book(&self, book_id: &str) -> Result<()> {
        self.db().delete_bookmark_book(book_id)?;
        Ok(())
    }

    /// 获取书签统计
    pub fn get_bookmark_stats(&self, book_id: &str) -> Result<i32> {
        let bookmarks = self.db().get_bookmark_count(book_id)?;
        Ok(bookmarks)
    }
}

/// 笔记仓库
impl NoteRepository {
    /// 保存笔记（支持高亮和注释）
    pub fn save_note(&self, note: &DbNote) -> Result<DbNote> {
        self.db().save_note(note)?;
        Ok(note.clone())
    }

    /// 获取书籍的所有笔记
    pub fn get_notes(&self, book_id: &str) -> Result<Vec<DbNote>> {
        self.db().get_notes(book_id)
    }

    /// 按类型获取笔记
    pub fn get_notes_by_type(&self, book_id: &str, note_type: DbNoteType) -> Result<Vec<DbNote>> {
        self.db().get_notes_by_type(book_id, note_type)
    }

    /// 获取笔记详情
    pub fn get_note(&self, note_id: &str) -> Result<Option<DbNote>> {
        self.db().get_note_by_id(note_id)
    }

    /// 删除笔记
    pub fn delete_note(&self, note_id: &str) -> Result<()> {
        self.db().delete_note(note_id)
    }

    /// 删除书籍的所有笔记
    pub fn delete_notes_by_book(&self, book_id: &str) -> Result<()> {
        self.db().delete_notes_by_book(book_id)
    }

    /// 批量保存笔记（使用事务）
    pub fn save_notes_batch(&self, notes: Vec<DbNote>) -> Result<()> {
        if notes.is_empty() {
            return Ok(());
        }
        self.db().save_notes_batch(&notes)
    }

    /// 获取笔记统计
    pub fn get_note_stats(&self, book_id: &str) -> Result<NoteStats> {
        let notes = self.db().get_note_stats(book_id)?;
        Ok(notes)
    }
}

/// 笔记统计
pub struct NoteStats {
    pub total_count: i32,
    pub highlight_count: i32,
    pub annotation_count: i32,
}

/// 排版缓存仓库
pub struct LayoutCacheRepository {
    kv: Arc<KvStore>,
}

impl LayoutCacheRepository {
    pub fn new(kv: Arc<KvStore>) -> Self {
        Self { kv }
    }

    /// 获取缓存的排版结果
    pub fn get_cached_layout(
        &self,
        book_id: &str,
        chapter_index: i32,
        config_hash: &str,
    ) -> Result<Option<DbLayoutCache>> {
        self.kv.get_layout_cache(&LayoutCacheKey {
            book_id: book_id.to_string(),
            chapter_index,
            config_hash: config_hash.to_string(),
        })
    }

    /// 保存排版结果到缓存
    pub fn save_layout_cache(&self, cache: &DbLayoutCache, key: &LayoutCacheKey) -> Result<()> {
        self.kv.save_layout_cache(key, cache)
    }

    /// 删除书籍的所有排版缓存
    pub fn invalidate_book_cache(&self, book_id: &str) -> Result<()> {
        self.kv.delete_book_layout_cache(book_id)
    }

    /// 清理过期缓存
    pub fn cleanup_expired(&self, max_age_days: i64) -> Result<usize> {
        self.kv.cleanup_expired_cache(max_age_days)
    }
}

impl StatsRepository {
    /// 获取今日统计
    pub fn get_today_stats(&self) -> Result<DbDailyReadingStats> {
        let today = chrono::Utc::now().date_naive().to_string();
        self.db().get_daily_stats(&today).map(|stats| {
            stats.unwrap_or(DbDailyReadingStats {
                date: today.clone(),
                total_reading_time_seconds: 0,
                total_characters_read: 0,
                books_read: vec![],
                session_count: 0,
                chapters_read: 0,
                pages_read: 0,
            })
        })
    }

    /// 获取日期范围统计
    pub fn get_stats_range(
        &self,
        start_date_str: &str,
        end_date_str: &str,
    ) -> Result<Vec<DbDailyReadingStats>> {
        // 1. 解析日期以验证格式并用于迭代
        let start = chrono::NaiveDate::parse_from_str(start_date_str, "%Y-%m-%d")
            .context("Invalid start_date format")?;
        let end = chrono::NaiveDate::parse_from_str(end_date_str, "%Y-%m-%d")
            .context("Invalid end_date format")?;

        if start > end {
            return Ok(vec![]);
        }

        // 2. 一次性从数据库获取所有存在的记录
        // 使用 HashMap 方便快速查找
        let db_records = self
            .db()
            .get_daily_stats_range(start_date_str, end_date_str)?;
        let mut stats_map: std::collections::HashMap<String, DbDailyReadingStats> = db_records
            .into_iter()
            .map(|s| (s.date.clone(), s))
            .collect();

        // 3. 在内存中遍历每一天，补全缺失的日期
        let mut results = Vec::new();
        let mut current = start;

        while current <= end {
            let date_str = current.to_string();

            // 尝试从 Map 中获取，如果没有则创建默认值
            let stat = stats_map.remove(&date_str).unwrap_or(DbDailyReadingStats {
                date: date_str.clone(),
                total_reading_time_seconds: 0,
                total_characters_read: 0,
                books_read: vec![],
                session_count: 0,
                chapters_read: 0,
                pages_read: 0,
            });

            results.push(stat);

            // 下一天
            match current.succ_opt() {
                Some(next) => current = next,
                None => break,
            }
        }

        Ok(results)
    }

    /// 获取全局统计
    pub fn get_global_stats(&self) -> Result<DbGlobalStats> {
        self.db().get_global_stats()
    }

    /// 更新每日统计
    pub fn update_daily_stats(&self, stats: &DbDailyReadingStats) -> Result<()> {
        self.db().update_daily_stats(stats)
    }
}

/// 章节仓库
impl ChapterRepository {
    /// 保存章节列表
    pub fn save_chapters(&self, book_id: &str, chapters: &[DbChapter]) -> Result<()> {
        self.db().save_chapters(book_id, chapters)
    }

    /// 获取章节列表
    pub fn get_chapters_by_book(&self, book_id: &str) -> Result<Vec<DbChapter>> {
        self.db().get_chapters_by_book(book_id)
    }

    /// 获取指定章节
    pub fn get_chapter_by_index(
        &self,
        book_id: &str,
        chapter_index: i32,
    ) -> Result<Option<DbChapter>> {
        self.db().get_chapter_by_index(book_id, chapter_index)
    }

    /// 删除书籍的所有章节
    pub fn delete_chapters_by_book(&self, book_id: &str) -> Result<()> {
        self.db().delete_chapters_by_book(book_id)
    }
}

/// 分类仓库
impl CategoryRepository {
    /// 获取所有分类
    pub fn get_all_categories(&self) -> Result<Vec<DbBookCategory>> {
        self.db().get_all_categories()
    }

    /// 保存分类
    pub fn save_category(&self, category: &DbBookCategory) -> Result<()> {
        self.db().save_category(category)
    }

    /// 删除分类
    pub fn delete_category(&self, category_id: &str) -> Result<()> {
        self.db().delete_category(category_id)
    }

    /// 获取分类详情
    pub fn get_category(&self, category_id: &str) -> Result<Option<DbBookCategory>> {
        self.db().get_category_by_id(category_id)
    }

    /// 分配分类到书籍
    pub fn assign_category(&self, book_id: &str, category_id: &str) -> Result<()> {
        self.db().assign_category(book_id, category_id)
    }

    /// 移除书籍的分类
    pub fn remove_category(&self, book_id: &str, category_id: &str) -> Result<()> {
        self.db().remove_category(book_id, category_id)
    }

    /// 获取书籍的分类
    pub fn get_categories_for_book(&self, book_id: &str) -> Result<Vec<DbBookCategory>> {
        self.db().get_categories_for_book(book_id)
    }

    /// 清除书籍的所有分类
    pub fn clear_categories_for_book(&self, book_id: &str) -> Result<()> {
        self.db().clear_categories_for_book(book_id)
    }

    /// 设置书籍的分类列表
    pub fn set_categories_for_book(&self, book_id: &str, category_ids: &[String]) -> Result<()> {
        self.db().set_categories_for_book(book_id, category_ids)
    }
}

/// 同步状态仓库
impl SyncRepository {
    /// 记录同步状态
    pub fn record_sync(&self, record: &DbSyncRecord) -> Result<()> {
        self.db().record_sync(record)?;
        Ok(())
    }

    /// 获取待同步项目
    pub fn get_pending_sync(&self, book_id: &str) -> Result<Vec<DbSyncRecord>> {
        self.db().get_pending_sync(book_id)
    }

    /// 获取同步冲突
    pub fn get_sync_conflicts(&self, book_id: &str) -> Result<Vec<DbSyncRecord>> {
        self.db().get_sync_conflicts(book_id)
    }

    /// 更新同步冲突
    pub fn clear_sync_conflicts(&self, book_id: &str) -> Result<()> {
        self.db().clear_sync_conflicts(book_id)
    }

    /// 删除同步记录
    pub fn delete_sync_record(&self, record_id: &str) -> Result<()> {
        self.db().delete_sync_record(record_id)
    }

    /// 清除所有同步记录
    pub fn clear_all_sync_records(&self) -> Result<()> {
        self.db().clear_all_sync_records()
    }

    /// 更新同步状态
    pub fn update_sync_status(
        &self,
        record_id: &str,
        status: DbSyncStatus,
        remote_version: Option<i32>,
    ) -> Result<()> {
        self.db()
            .update_sync_status(record_id, status, remote_version)
    }
}

/// 书籍仓库
impl BookRepository {
    /// 获取所有书籍
    pub fn list(&self) -> Result<Vec<DbBookRecord>> {
        self.db().get_all_books()
    }

    /// 根据 ID 获取书籍
    pub fn find_by_id(&self, book_id: &str) -> Result<Option<DbBookRecord>> {
        self.db().get_book(book_id)
    }

    /// 保存书籍
    pub fn save(&self, book: &DbBookRecord) -> Result<()> {
        self.db().save_book(book)
    }

    /// 删除书籍
    pub fn delete_by_id(&self, book_id: &str) -> Result<()> {
        self.db().delete_book(book_id)
    }

    /// 搜索书籍
    pub fn search(&self, keyword: &str) -> Result<Vec<DbBookRecord>> {
        self.db().search_books(keyword)
    }

    /// 按状态筛选书籍
    pub fn list_by_status(&self, status: DbBookStatus) -> Result<Vec<DbBookRecord>> {
        self.db().get_books_by_status(status.as_str())
    }

    /// 获取置顶书籍
    pub fn list_by_pinned_books(&self) -> Result<Vec<DbBookRecord>> {
        self.db().get_pinned_books()
    }

    /// 获取最近阅读的书籍
    pub fn list_by_recently(&self, limit: usize) -> Result<Vec<DbBookRecord>> {
        self.db().get_recently_read_books(limit)
    }
}

/// 会话仓库
impl SessionRepository {
    /// 记录阅读会话
    pub fn record_session(&self, session: &DbReadingSession) -> Result<()> {
        self.db().save_session(session)
    }

    /// 获取书籍的阅读会话
    pub fn get_sessions_by_book(
        &self,
        book_id: &str,
        limit: usize,
    ) -> Result<Vec<DbReadingSession>> {
        self.db().get_sessions_by_book(book_id, limit)
    }

    /// 获取日期范围内的阅读会话
    pub fn get_sessions_by_date_range(
        &self,
        book_id: &str,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<DbReadingSession>> {
        self.db()
            .get_sessions_by_date_range(book_id, start_date, end_date)
    }

    /// 获取最近的阅读会话
    pub fn get_recent_sessions(&self, limit: usize) -> Result<Vec<DbReadingSession>> {
        self.db().get_recent_sessions(limit)
    }

    /// 删除书籍的所有阅读会话
    pub fn delete_sessions_by_book(&self, book_id: &str) -> Result<()> {
        self.db().delete_sessions_by_book(book_id)
    }
}
