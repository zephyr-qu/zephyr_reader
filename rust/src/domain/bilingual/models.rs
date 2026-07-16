//! 双语对齐领域模型

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 对齐片段
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct AlignedSegment {
    pub chinese: String,
    pub english: String,
    pub similarity_score: f32,
    pub chinese_position: usize,
    pub english_position: usize,
}

/// 双语对齐结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BilingualAlignment {
    pub segments: Vec<AlignedSegment>,
    pub unmatched_chinese: Vec<String>,
    pub unmatched_english: Vec<String>,
}

/// 双语高亮配对
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BilingualHighlightPair {
    pub chinese_note_id: String,
    pub english_note_id: String,
    pub chinese_text: String,
    pub english_text: String,
}

/// 创建双语高亮配对的参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BilingualHighlightParams {
    pub book_id: String,
    pub chapter_index: i64,
    pub chinese_text: String,
    pub english_text: String,
    pub chinese_char_offset: i64,
    pub chinese_length: i64,
    pub english_char_offset: i64,
    pub english_length: i64,
    pub highlight_color: i64,
    pub language: Option<String>,
}
