//! 排版 API
//!
//! 提供文本排版功能，支持中文、英文及混合文本的排版处理。
//! 根据 TypesetConfig 配置（页面尺寸、字体、间距等）对内容进行格式化。
use crate::domain::{AppError, LanguageType, TypesetConfig};
use flutter_rust_bridge::frb;

/// 对文本进行排版处理
///
/// 根据排版配置，对输入文本进行格式化（首行缩进、标点优化、连字符等）。
/// 自动验证并修正配置参数，确保在合法范围内。
///
/// # 参数
/// - `content`: 待排版的文本内容（最大 1,000,000 字节）
/// - `config`: 排版配置
///
/// # 返回值
/// 返回排版后的文本
#[frb]
pub async fn typeset_text(content: String, config: TypesetConfig) -> Result<String, AppError> {
    const MAX_INPUT_LEN: usize = 1_000_000;
    if content.len() > MAX_INPUT_LEN {
        return Err(AppError::invalid_input(format!(
            "Input too large: {} bytes (max {})",
            content.len(),
            MAX_INPUT_LEN
        )));
    }
    let config = config.validate_and_fix();
    let lang = match config.language {
        LanguageType::Chinese => "zh",
        LanguageType::English => "en",
        LanguageType::Mixed => "mix",
        LanguageType::Auto => "auto",
    };
    let lang = lang.to_string();
    tokio::task::spawn_blocking(move || {
        crate::text::typeset::typeset_content(content, lang, config)
    })
    .await
    .map_err(|e| AppError::task_panic("typeset", e.to_string()))?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_typeset_text_exceeds_max_length() {
        let oversized = "x".repeat(1_000_001);
        let config = TypesetConfig::default();
        let result = typeset_text(oversized, config).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_typeset_text_accepts_reasonable_input() {
        let content = "Hello, world!".to_string();
        let config = TypesetConfig {
            language: crate::domain::LanguageType::English,
            ..Default::default()
        };
        let result = typeset_text(content.clone(), config).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_typeset_text_language_auto() {
        let content = "你好世界".to_string();
        let config = TypesetConfig::default();
        let result = typeset_text(content, config).await;
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(!output.is_empty());
    }

    #[tokio::test]
    async fn test_typeset_text_japanese() {
        let content = "こんにちは世界".to_string();
        let config = TypesetConfig {
            language: crate::domain::LanguageType::Auto,
            ..Default::default()
        };
        let result = typeset_text(content, config).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_typeset_text_english() {
        let content = "The quick brown fox jumps over the lazy dog.".to_string();
        let config = TypesetConfig {
            language: crate::domain::LanguageType::English,
            ..Default::default()
        };
        let result = typeset_text(content.clone(), config).await;
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("The quick brown fox"));
    }
}
