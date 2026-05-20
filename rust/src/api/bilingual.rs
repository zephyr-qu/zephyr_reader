//! 双语对齐 API
//!
//! 提供中英双语文本的自动对齐功能，支持对照阅读
use crate::domain::AppError;
use flutter_rust_bridge::frb;

pub use crate::domain::BilingualAlignment;

const MAX_BILINGUAL_LEN: usize = 2_000_000;

/// 对齐双语文本（基于相似度匹配）
///
/// 使用编辑距离计算句子相似度，通过贪心+窗口搜索算法
/// 自动匹配中英文对应的句子
///
/// # 参数
///
/// * `chinese_content` - 中文文本内容
/// * `english_content` - 英文文本内容
/// * `min_similarity` - 最小相似度阈值 (0.3 - 1.0)，低于此值不匹配
///
///   传入的值会被 clamp 到 `[0.3, 1.0]` 区间，0.3 以下会静默提升到 0.3
///
/// # 返回值
///
/// 返回对齐结果，包含匹配的片段对和未匹配的片段
///
/// # 长度限制
///
/// 中英文文本**合计**不得超过 2MB，超限返回错误。
#[frb]
pub async fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, AppError> {
    if chinese_content.len() + english_content.len() > MAX_BILINGUAL_LEN {
        return Err(AppError::invalid_input(
            format!(
                "双语对齐输入过大: {} bytes (最大 {})",
                chinese_content.len() + english_content.len(),
                MAX_BILINGUAL_LEN,
            ),
        ));
    }

    let similarity = min_similarity.max(0.3).min(1.0);

    tokio::task::spawn_blocking(move || {
        crate::text::bilingual::align_bilingual_content(
            chinese_content,
            english_content,
            similarity,
        )
    })
    .await
    .map_err(|e| AppError::internal(format!("Bilingual alignment task failed: {}", e)))?
    .map_err(|e| AppError::internal(format!("双语对齐失败: {}", e)))
}

#[frb]
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
///
/// # 长度限制
///
/// 中英文文本**合计**不得超过 2MB，超限返回错误。
pub async fn simple_bilingual_align(
    chinese_content: String,
    english_content: String,
) -> Result<BilingualAlignment, AppError> {
    if chinese_content.len() + english_content.len() > MAX_BILINGUAL_LEN {
        return Err(AppError::invalid_input(
            format!(
                "双语对齐输入过大: {} bytes (最大 {})",
                chinese_content.len() + english_content.len(),
                MAX_BILINGUAL_LEN,
            ),
        ));
    }

    tokio::task::spawn_blocking(move || {
        Ok(crate::text::bilingual::simple_bilingual_align(
            chinese_content,
            english_content,
        ))
    })
    .await
    .map_err(|e| AppError::internal(format!("Bilingual alignment task failed: {}", e)))?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_align_bilingual_content_basic() {
        let result = align_bilingual_content(
            "你好世界。这是一个测试。".to_string(),
            "Hello World. This is a test.".to_string(),
            0.3,
        ).await.unwrap();
        assert!(!result.segments.is_empty());
    }

    #[tokio::test]
    async fn test_simple_bilingual_align() {
        let result = simple_bilingual_align(
            "你好。测试。".to_string(),
            "Hello. Test.".to_string(),
        ).await.unwrap();
        assert!(!result.segments.is_empty());
    }

    #[tokio::test]
    async fn test_bilingual_exceeds_max_length() {
        let long = "x".repeat(1_500_000);
        let result = align_bilingual_content(
            long.clone(), long, 0.3,
        ).await;
        assert!(result.is_err());
    }
}