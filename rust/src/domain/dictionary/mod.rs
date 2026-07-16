//! 词典管理模块

pub mod dictionary_repo;
pub mod mdict_engine;
pub mod models;
pub mod service;

pub use mdict_engine::MdictEngine;
pub use models::{DictEntry, DictSearchResult};
