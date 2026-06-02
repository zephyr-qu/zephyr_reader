use crate::domain::{AppError, LanguageType, TypesetConfig};
use flutter_rust_bridge::frb;

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
