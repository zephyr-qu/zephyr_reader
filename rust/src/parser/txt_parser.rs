//! TXT 文件解析器实现
//!
//! 实现 `BookParser` trait，提供 TXT 文件格式的解析支持。

use std::sync::Arc;

use crate::ffi::{ApiResult, ParseResult, ParserError};
use crate::parser::traits::{BookMetadata, BookParser};
use crate::text_process::chapter_detect::extract_chapters;

/// TXT 文件解析器
pub struct TxtParser {}

impl TxtParser {
    /// 创建新的 TXT 解析器实例
    pub fn new() -> Self {
        Self {}
    }
}

impl Default for TxtParser {
    fn default() -> Self {
        Self::new()
    }
}

impl BookParser for TxtParser {
    fn name(&self) -> &str {
        "TXT Parser"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["txt", "text"]
    }

    fn parse(&self, file_path: &str) -> ApiResult<ParseResult> {
        crate::parser::parse_txt(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> ApiResult<BookMetadata> {
        let result = self.parse(file_path)?;

        Ok(BookMetadata {
            title: result.book_info.title,
            author: result.book_info.author,
            description: None,
            cover_path: None,
            publish_year: None,
            language: None,
            chapter_count: result.book_info.chapter_count,
            total_characters: result.book_info.total_characters,
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_id: i32) -> ApiResult<String> {
        use crate::parser::txt::decode;

        let content = decode::decode_file(file_path)?;
        let chapters = extract_chapters(&content, 1000);

        let chapter = chapters
            .iter()
            .find(|c| c.index == chapter_id)
            .ok_or_else(|| {
                ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id))
            })?;

        // 注意：start_index 和 end_index 是字节偏移（来自 regex::Match::start()）
        // 直接使用字节边界进行切片，无需 char_indices 转换
        let start = chapter.start_index as usize;
        let end = chapter.end_index as usize;

        // 边界检查
        if start >= content.len() {
            return Ok(String::new());
        }

        let safe_end = end.min(content.len());

        // 验证 UTF-8 边界（确保不会截断多字节字符）
        if !content.is_char_boundary(start) || !content.is_char_boundary(safe_end) {
            tracing::warn!(
                "章节边界不是有效的 UTF-8 字符边界：start={}, end={}",
                start,
                safe_end
            );
            return Err(ParserError::ChapterExtractError(format!(
                "章节边界无效：{}-{}",
                start, safe_end
            )));
        }

        Ok(content[start..safe_end].to_string())
    }
}

/// 创建 TXT 解析器实例（方便外部使用）
pub fn create_txt_parser() -> Arc<dyn BookParser> {
    Arc::new(TxtParser::new())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_txt_parser_name() {
        let parser = TxtParser::new();
        assert_eq!(parser.name(), "TXT Parser");
    }

    #[test]
    fn test_txt_parser_supported_formats() {
        let parser = TxtParser::new();
        let formats = parser.supported_formats();
        assert!(formats.contains(&"txt"));
        assert!(formats.contains(&"text"));
    }

    #[test]
    fn test_txt_parser_supports_format() {
        let parser = TxtParser::new();
        assert!(parser.supports_format("txt"));
        assert!(parser.supports_format("TXT"));
        assert!(!parser.supports_format("epub"));
    }

    #[test]
    fn test_txt_parser_parse_file_not_found() {
        let parser = TxtParser::new();
        let result = parser.parse("non_existent.txt");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_txt_parser_extract_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n这是测试内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let metadata = parser
            .extract_metadata(file_path.to_str().unwrap())
            .unwrap();

        assert!(metadata.title.contains("第一章"));
        assert_eq!(metadata.chapter_count, 1);
        assert!(metadata.total_characters > 0);
    }

    #[test]
    fn test_txt_parser_extract_chapter() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n这是第一章的内容。\n\n第二章 结束\n这是第二章的内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let chapter_content = parser
            .extract_chapter(file_path.to_str().unwrap(), 0)
            .unwrap();

        assert!(chapter_content.contains("第一章"));
        assert!(chapter_content.contains("这是第一章的内容"));
    }
}
