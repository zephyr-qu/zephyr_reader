use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 引擎私有位置提示（快速恢复加速）
///
/// 存储引擎特定的位置信息（如 Readium Locator JSON）用于加速跨会话恢复。
/// 与逻辑位置 `ReadingPosition` 分离；后者是跨引擎的领域真理。
///
/// I10 规则：publication_fingerprint 与实际文件不匹配时必须丢弃。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingEnginePosition {
    pub book_id: String,
    pub engine_kind: String,
    pub publication_fingerprint: String,
    pub opaque_position: String,
    pub updated_at: DateTime<Utc>,
}
