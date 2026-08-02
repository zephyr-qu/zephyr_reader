use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 引擎私有位置恢复提示（ADR-019）。
///
/// 逻辑位置（chapter_index/char_offset）存 `reading_progress`；
/// 这里只存引擎私有、可丢弃的快速恢复信息 —— Readium 的完整 Locator JSON。
/// `publication_fingerprint` 与当前 EPUB 指纹不匹配时必须丢弃（Locator 不是领域真理）。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct EnginePositionHint {
    pub book_id: String,
    pub engine_kind: String,
    pub publication_fingerprint: String,
    pub opaque_position: String,
    pub updated_at: DateTime<Utc>,
}
