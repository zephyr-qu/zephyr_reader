//! 备份数据模型

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 备份清单
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
#[frb(non_opaque)]
pub struct BackupManifest {
    pub app_version: String,
    pub exported_at: i64,
    pub db_size: i64,
    pub stats: BackupStats,
}

/// 当前数据库行数统计
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
#[frb(non_opaque)]
pub struct BackupStats {
    pub books: i64,
    pub chapters: i64,
    pub notes: i64,
    pub bookmarks: i64,
    pub reading_sessions: i64,
    pub reading_progress: i64,
    pub categories: i64,
}
