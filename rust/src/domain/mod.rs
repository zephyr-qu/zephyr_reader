// ============================================================
// 文件作用：领域层模块声明 — 所有子领域拍平到 domain/ 根级
// ============================================================

pub mod backup;
pub mod book;
pub mod bookmark;
pub mod category;
pub mod chapter;
pub mod cover;
pub mod engine_positions;
pub mod progress;
pub mod sessions;
pub mod stats;
pub(crate) use crate::common::AppError;
