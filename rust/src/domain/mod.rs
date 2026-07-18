// ============================================================
// 文件作用：领域层模块声明 — 所有子领域拍平到 domain/ 根级
// ============================================================

pub mod backup;
pub mod bilingual;
pub mod book;
pub mod bookmark;
pub mod category;
pub mod chapter;
pub mod chapter_detect;
pub mod cover;
pub mod dictionary;
pub mod note;
pub mod progress;
pub mod search;
pub mod sessions;
pub mod stats;
pub mod vocab;
pub mod wordlist;

pub(crate) use crate::common::AppError;
