//! 书籍管理领域

pub mod book_repo;
pub mod models;
pub mod service;

pub use book_repo::BookRepository;
pub use models::*;
pub use service::*;
