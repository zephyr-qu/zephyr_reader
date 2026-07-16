//! 备份数据模型

use flutter_rust_bridge::frb;
use chrono::{DateTime, Utc};
use uuid::Uuid;
use serde::{Deserialize, Serialize};



/// 生词学习状态
///
/// 数据库中存储为小写文本（`new` / `learning` / `mastered` / `ignored`）。
#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    sqlx::Type,
    Default,
    strum::AsRefStr,
    strum::EnumString,
)]
#[sqlx(rename_all = "lowercase")]
#[strum(serialize_all = "lowercase")]
#[frb]
pub enum VocabStatus {
    /// 新词，尚未开始学习
    #[default]
    Unstarted,
    /// 学习中，正在复习周期内
    Learning,
    /// 已掌握，通过所有复习阶段
    Mastered,
    /// 已忽略/移除出学习队列
    Ignored,
}

impl TryFrom<String> for VocabStatus {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        s.parse().map_err(|e: strum::ParseError| e.to_string())
    }
}
/// 生词条目
///
/// `status` 字段通过 `#[sqlx(try_from)]` 自动从 SQLite TEXT 解码为 `VocabStatus`，
/// 非法值会导致 `FromRow` 解析失败（Fail visibly）。
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Vocab {
    pub id: String,
    pub word: String,
    pub pinyin: String,
    pub translation: String,
    pub context_sentence: Option<String>,
    pub book_id: Option<String>,
    pub chapter_index: Option<i64>,
    pub char_offset: Option<i64>,
    pub created_at: DateTime<Utc>,
    pub review_count: i64,
    pub last_reviewed_at: Option<DateTime<Utc>>,
    #[sqlx(try_from = "String")]
    pub status: VocabStatus,
    pub word_list: Option<String>,
    #[sqlx(default)]
    pub dict_source: Option<String>,
    #[sqlx(default)]
    pub dict_entry_hash: Option<String>,
}
impl Vocab {
    /// 添加生词条目
    ///
    /// - `id` / `created_at` 自动生成
    /// - `status` 默认为 `Unstarted`（新词）
    /// - `review_count` 初始为 0
    /// - 关联上下文（book_id/chapter_index 等）为可选参数
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        word: &str,
        pinyin: &str,
        translation: &str,
        context_sentence: Option<String>,
        book_id: Option<String>,
        chapter_index: Option<i64>,
        char_offset: Option<i64>,
        word_list: Option<String>,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            word: word.to_string(),
            pinyin: pinyin.to_string(),
            translation: translation.to_string(),
            context_sentence,
            book_id,
            chapter_index,
            char_offset,
            created_at: Utc::now(),
            review_count: 0,
            last_reviewed_at: None,
            status: VocabStatus::Unstarted,
            word_list,
            dict_source: None,
            dict_entry_hash: None,
        }
    }
}
/// 生词本统计摘要（应用层计算，非直接 DB 映射）
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct VocabStats {
    #[sqlx(try_from = "i64")]
    pub total_words: i64,
    #[sqlx(try_from = "i64")]
    pub unstarted_count: i64,
    #[sqlx(try_from = "i64")]
    pub learning_count: i64,
    #[sqlx(try_from = "i64")]
    pub mastered_count: i64,
    #[sqlx(try_from = "i64")]
    pub ignored_count: i64,
}
