//! 词典数据模型 (Dictionary Data Models)
//!
//! 定义词典查询相关的数据结构，包括词条信息 (`DictEntry`) 和查询结果 (`DictSearchResult`)。
//! 词条包含单词、HTML 格式释义以及可选的音频资源键名。
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 词典词条
///
/// 表示从词典文件中查询到的单个词条信息。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct DictEntry {
    /// 查询的单词
    pub word: String,
    /// 来自 MDX 文件的原始 HTML 格式释义
    /// Flutter 端使用 flutter_widget_from_html_core 进行渲染
    pub definition_html: String,
    /// 发音音频资源在 .mdd 文件中的键名（如果可用）
    pub audio_key: Option<String>,
}

/// 词典查询结果
///
/// 包含精确匹配结果和拼写纠正建议。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct DictSearchResult {
    /// 精确匹配的词条（如果存在）
    pub exact: Option<DictEntry>,
    /// 拼写纠正建议列表（编辑距离 ≤ 2）
    pub suggestions: Vec<String>,
}

/// 词典
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct Dictionary {
    pub id: String,
    pub name: String,
    pub file_path: String,
    pub dict_type: String,
    pub lang_from: Option<String>,
    pub lang_to: Option<String>,
    pub is_enabled: bool,
    pub word_count: i64,
    pub added_at: DateTime<Utc>,
}
impl Dictionary {
    pub fn new(
        name: &str,
        file_path: &str,
        dict_type: &str,
        lang_from: Option<String>,
        lang_to: Option<String>,
        is_enabled: bool,
        word_count: i64,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: name.to_string(),
            file_path: file_path.to_string(),
            dict_type: dict_type.to_string(),
            lang_from,
            lang_to,
            is_enabled,
            word_count,
            added_at: Utc::now(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dict_entry_all_fields() {
        let entry = DictEntry {
            word: "hello".to_string(),
            definition_html: "<b>你好</b>".to_string(),
            audio_key: Some("\\hello.wav".to_string()),
        };
        assert_eq!(entry.word, "hello");
        assert_eq!(entry.definition_html, "<b>你好</b>");
        assert_eq!(entry.audio_key, Some("\\hello.wav".to_string()));
    }

    #[test]
    fn test_dict_entry_no_audio() {
        let entry = DictEntry {
            word: "world".to_string(),
            definition_html: "世界".to_string(),
            audio_key: None,
        };
        assert_eq!(entry.word, "world");
        assert!(entry.audio_key.is_none());
    }

    #[test]
    fn test_dict_entry_empty_strings() {
        let entry = DictEntry {
            word: String::new(),
            definition_html: String::new(),
            audio_key: None,
        };
        assert!(entry.word.is_empty());
        assert!(entry.definition_html.is_empty());
    }

    #[test]
    fn test_dict_search_result_exact_match() {
        let entry = DictEntry {
            word: "apple".to_string(),
            definition_html: "苹果".to_string(),
            audio_key: None,
        };
        let result = DictSearchResult {
            exact: Some(entry),
            suggestions: vec![],
        };
        assert!(result.exact.is_some());
        assert_eq!(result.exact.as_ref().unwrap().word, "apple");
        assert!(result.suggestions.is_empty());
    }

    #[test]
    fn test_dict_search_result_suggestions_only() {
        let result = DictSearchResult {
            exact: None,
            suggestions: vec!["apple".to_string(), "apply".to_string()],
        };
        assert!(result.exact.is_none());
        assert_eq!(result.suggestions.len(), 2);
        assert!(result.suggestions.contains(&"apple".to_string()));
    }

    #[test]
    fn test_dict_search_result_no_results() {
        let result = DictSearchResult {
            exact: None,
            suggestions: vec![],
        };
        assert!(result.exact.is_none());
        assert!(result.suggestions.is_empty());
    }

    #[test]
    fn test_dict_entry_serde_roundtrip() {
        let entry = DictEntry {
            word: "test".to_string(),
            definition_html: "<i>测试</i>".to_string(),
            audio_key: Some("\\test.mp3".to_string()),
        };
        let json = serde_json::to_string(&entry).expect("serialize");
        let deserialized: DictEntry = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(deserialized.word, "test");
        assert_eq!(deserialized.definition_html, "<i>测试</i>");
        assert_eq!(deserialized.audio_key, Some("\\test.mp3".to_string()));
    }

    #[test]
    fn test_dict_search_result_serde_roundtrip() {
        let entry = DictEntry {
            word: "book".to_string(),
            definition_html: "书".to_string(),
            audio_key: None,
        };
        let result = DictSearchResult {
            exact: Some(entry),
            suggestions: vec!["book".to_string(), "look".to_string()],
        };
        let json = serde_json::to_string(&result).expect("serialize");
        let deserialized: DictSearchResult = serde_json::from_str(&json).expect("deserialize");
        assert!(deserialized.exact.is_some());
        assert_eq!(deserialized.exact.unwrap().word, "book");
        assert_eq!(deserialized.suggestions.len(), 2);
    }

    #[test]
    fn test_dict_entry_debug_and_clone() {
        let entry = DictEntry {
            word: "debug".to_string(),
            definition_html: "调试".to_string(),
            audio_key: None,
        };
        let cloned = entry.clone();
        assert_eq!(entry.word, cloned.word);
        let debug_str = format!("{:?}", entry);
        assert!(debug_str.contains("debug"));
        assert!(debug_str.contains("调试"));
    }
}
