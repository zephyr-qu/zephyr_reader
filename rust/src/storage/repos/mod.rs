//! 数据库仓储层
//!
//! 每个实体对应一个 Repository，封装对该实体表的 CRUD 操作

pub mod book_repo;
pub mod bookmark_repo;
pub mod category_repo;
pub mod chapter_repo;
pub mod dictionary_repo;
pub mod layout_cache_repo;
pub mod note_repo;
pub mod progress_repo;
pub mod session_repo;
pub mod stats_repo;
pub mod vocab_repo;

#[cfg(test)]
pub mod test_utils;

pub use book_repo::BookRepository;
pub use bookmark_repo::BookmarkRepository;
pub use category_repo::CategoryRepository;
pub use chapter_repo::ChapterRepository;
pub use dictionary_repo::DictionaryRepository;
pub use layout_cache_repo::LayoutCacheRepository;
pub use note_repo::NoteRepository;
pub use progress_repo::ProgressRepository;
pub use session_repo::SessionRepository;
pub use stats_repo::StatsRepository;
pub use vocab_repo::VocabRepository;
