//! 双语对齐 API
//!
//! 提供中英双语文本的自动对齐功能，支持对照阅读。

use crate::ffi::{ApiResult, BilingualAlignment, ParserError};
use flutter_rust_bridge::frb;

/// 对齐双语文本（基于相似度匹配）
///
/// 使用编辑距离计算句子相似度，通过贪心+窗口搜索算法
/// 自动匹配中英文对应的句子。
///
/// # 参数
///
/// * `chinese_content` - 中文文本内容
/// * `english_content` - 英文文本内容
/// * `min_similarity` - 最小相似度阈值 (0.0 - 1.0)，低于此值不匹配
///
/// # 返回值
///
/// 返回对齐结果，包含匹配的片段对和未匹配的片段
#[frb(sync)]
pub fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> ApiResult<BilingualAlignment> {
    let similarity = min_similarity.max(0.3).min(1.0);
    crate::text_process::bilingual::align_bilingual_content(
        chinese_content,
        english_content,
        similarity,
    )
    .map_err(|e| ParserError::Other(format!("双语对齐失败: {}", e)))
}

/// 简单的句子对齐（1:1 位置对齐）
///
/// 将中英文文本按句子分割后逐句配对，不进行相似度计算。
/// 适用于已知中英文内容顺序一致的场景。
///
/// # 参数
///
/// * `chinese_content` - 中文文本内容
/// * `english_content` - 英文文本内容
///
/// # 返回值
///
/// 返回对齐结果，句子按位置一一配对
#[frb(sync)]
pub fn simple_bilingual_align(
    chinese_content: String,
    english_content: String,
) -> BilingualAlignment {
    crate::text_process::bilingual::simple_bilingual_align(chinese_content, english_content)
}
