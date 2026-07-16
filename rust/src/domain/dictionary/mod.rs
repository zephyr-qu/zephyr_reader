//! 词典管理模块

pub mod dictionary_repo;
pub mod engine;
pub mod models;
pub mod service;

pub use engine::Engine;
pub use models::{DictEntry, DictSearchResult};
