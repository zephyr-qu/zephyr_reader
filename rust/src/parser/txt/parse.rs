// ============================================================
// 文件作用：TXT 文件解析，负责章节提取、内容分段、元数据提取。
//
// 公有类型/函数：
//   - parse_txt() — 解析 TXT 文件，返回 ParseResult
//
// 私有函数：
//   - extract_metadata_from_content() — 从内容头部提取元数据
//   - extract_kv() — 从一行提取键值对
//   - extract_chapters() — 从内容中提取章节
//   - parse_txt_inner() — 内部解析逻辑
// ============================================================

//! TXT 文件解析
//! 负责章节提取、内容分段

use std::path::Path;

use super::decode;
use crate::domain::{AppError, ParseResult};
use crate::storage::models::{Book, BookFormat, Chapter};
use crate::text::chapter_detect;

/// 解析 TXT 文件
pub fn parse_txt(file_path: String) -> Result<ParseResult, AppError> {
    parse_txt_inner(file_path)
}

/// 从 TXT 文件内容头部提取元数据
///
/// 扫描前 100 行，识别常见的元数据标记：
/// - `书名[：:]xxx`
/// - `作者[：:]xxx`
/// - `简介[：:]xxx` / `内容简介[：:]xxx`
fn extract_metadata_from_content(
    content: &str,
) -> (Option<String>, Option<String>, Option<String>) {
    let mut title = None;
    let mut author = None;
    let mut description = None;

    for line in content.lines().take(100) {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if title.is_none()
            && let Some(val) = extract_kv(line, &["书名", "書名"]) {
                title = Some(val);
                continue;
            }

        if author.is_none()
            && let Some(val) = extract_kv(line, &["作者"]) {
                author = Some(val);
                continue;
            }

        if description.is_none()
            && let Some(val) =
                extract_kv(line, &["简介", "簡介", "内容简介", "內容簡介", "内容提要"])
            {
                description = Some(val);
            }

        if title.is_some() && author.is_some() && description.is_some() {
            break;
        }
    }

    (title, author, description)
}

/// 从一行中提取键值对的值部分
///
/// 例如 `extract_kv("书名：三体", &["书名"])` → `Some("三体")`
fn extract_kv(line: &str, keys: &[&str]) -> Option<String> {
    for key in keys {
        if let Some(rest) = line.strip_prefix(key) {
            let rest = rest.trim();
            let val = rest
                .strip_prefix(':')
                .or_else(|| rest.strip_prefix('：'))
                .unwrap_or(rest)
                .trim();
            if !val.is_empty() {
                return Some(val.to_string());
            }
        }
    }
    None
}

fn parse_txt_inner(file_path: String) -> Result<ParseResult, AppError> {
    let start_time = std::time::Instant::now();
    tracing::info!("start parsing TXT file: {}", file_path);

    // 检查文件是否存在
    if !Path::new(&file_path).exists() {
        return Err(AppError::FileNotFound { path: file_path });
    }
    tracing::debug!("file existence check passed: {}", file_path);

    // 解码文件内容
    let content = decode::decode_file(&file_path)?;
    let total_chars = content.chars().count() as i64;
    tracing::debug!("file decoded, characters: {}", total_chars);

    // 提取文件名（用于书名回退）
    let file_name = Path::new(&file_path)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Book")
        .to_string();

    // 从文件头部提取元数据
    let (meta_title, meta_author, meta_description) = extract_metadata_from_content(&content);

    // 书名优先级：元数据标题 > 文件名
    let title = meta_title.unwrap_or(file_name);
    // 作者优先级：元数据作者 > 默认作者
    let author = meta_author.unwrap_or_else(|| "Unknown Author".to_string());

    // 提取章节
    let book_id = uuid::Uuid::new_v4().to_string();
    let chapters = extract_chapters(&content, &book_id);
    tracing::debug!("chapters extracted, count: {}", chapters.len());

    let file_size = std::fs::metadata(&file_path)
        .map(|m| m.len() as i64)
        .unwrap_or(0);

    let book_info = Book {
        book_id,
        file_path: file_path.clone(),
        title,
        author: Some(author),
        chapter_count: chapters.len() as i64,
        total_characters: total_chars,
        file_size,
        description: meta_description,
        format: BookFormat::Txt,
        added_at: chrono::Utc::now(),
        ..Default::default()
    };

    let elapsed = start_time.elapsed();
    tracing::info!(
        "TXT parse complete: {} chapters, {} chars, elapsed: {:?}",
        chapters.len(),
        total_chars,
        elapsed
    );

    Ok(ParseResult {
        book_info,
        chapters,
    })
}

/// 从内容中提取章节
///
/// **重要**：返回的 `Chapter.start_index` 和 `end_index` 是**字节偏移**（而非字符索引）。
/// 在使用这些值切片内容时，必须确保在 UTF-8 字符边界处截断。
fn extract_chapters(content: &str, book_id: &str) -> Vec<Chapter> {
    // 使用通用章节检测（支持中文、英文、数字等多种模式）
    let detected = chapter_detect::extract_chapters(content, 1000, book_id);
    if !detected.is_empty() {
        return detected;
    }

    // 如果没有检测到章节标记，将整个文件作为一章
    vec![


      Chapter::new(book_id, "Full Text", 0, 0, 0,  content.len() as i64)

    //   {
    //     id: uuid::Uuid::new_v4().to_string(),
    //     book_id: book_id.to_string(),
    //     title: "Full Text".to_string(),
    //     start_index: 0,
    //     end_index: content.len() as i64,
    //     chapter_index: 0,
    //     word_count: 0,
    //     cached_at: chrono::Utc::now(),
    //     level: 0,
    // }
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_extract_chapters_zh() {
        let content = r#"
第一章 开始
这是第一章的内容。

第二章 发展
这是第二章的内容。

第三章 结局
这是第三章的内容。
"#;

        let chapters = extract_chapters(content, "test");
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第一章 开始");
        assert_eq!(chapters[1].title, "第二章 发展");
    }

    #[test]
    fn test_parse_txt_file_not_found() {
        let result = parse_txt("non_existent_file.txt".to_string());
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_parse_txt_basic() {
        // 创建临时文件
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n\n这是测试内容。";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.format, BookFormat::Txt);
        // 无元数据时，书名回退到文件名
        assert_eq!(parse_result.book_info.title, "test");
        assert_eq!(parse_result.chapters.len(), 1);
    }

    #[test]
    fn test_parse_txt_with_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("三体.txt");
        let content = "书名：三体\n作者：刘慈欣\n\n这是正文内容。";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.title, "三体");
        assert_eq!(parse_result.book_info.author.unwrap(), "刘慈欣");
    }

    #[test]
    fn test_parse_txt_with_metadata_ascii_colon() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("novel.txt");
        let content = "书名:三体\n作者:刘慈欣\n\n正文内容。";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.title, "三体");
        assert_eq!(parse_result.book_info.author.unwrap(), "刘慈欣");
    }

    #[test]
    fn test_parse_txt_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.txt");
        fs::write(&file_path, "").unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        assert_eq!(parse_result.book_info.total_characters, 0);
    }

    #[test]
    fn test_extract_chapters_no_chapters() {
        // 没有章节标记的内容，应该作为一章处理
        let content = "这是没有章节的完整内容。";
        let chapters = extract_chapters(content, "test");
        assert_eq!(chapters.len(), 1);
        assert_eq!(chapters[0].title, "Full Text");
    }

    #[test]
    fn test_extract_chapters_with_special_chars() {
        // 测试包含特殊字符的章节标题
        let content = r#"第零章 序章
这是序章内容。

第一〇一章 特殊数字
这是第101章内容。

第一千零一章 大结局
这是最终章。"#;

        let chapters = extract_chapters(content, "test");
        assert_eq!(chapters.len(), 3);
        assert_eq!(chapters[0].title, "第零章 序章");
        assert_eq!(chapters[1].title, "第一〇一章 特殊数字");
    }

    #[test]
    fn test_parse_txt_with_long_content() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("long.txt");

        // 创建包含多个章节的长文本
        let mut content = String::new();
        for i in 1..=10 {
            content.push_str(&format!("第{}章 章节{}\n\n这是第{}章的内容。\n\n", i, i, i));
        }
        fs::write(&file_path, &content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
        let parse_result = result.unwrap();
        // 章节检测可能无法识别所有格式，但至少应该有章节
        assert!(!parse_result.chapters.is_empty());
    }

    #[test]
    fn test_parse_txt_with_chinese_punctuation() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("chinese.txt");
        let content = "第一章：开始\n这是中文标点符号的测试。\n";
        fs::write(&file_path, content).unwrap();

        let result = parse_txt(file_path.to_str().unwrap().to_string());
        assert!(result.is_ok());
    }
    #[test]
    fn extract_kv_chinese_colon() {
        assert_eq!(
            extract_kv("书名：三体", &["书名"]),
            Some("三体".to_string())
        );
    }

    #[test]
    fn extract_kv_ascii_colon() {
        assert_eq!(
            extract_kv("书名:三体", &["书名"]),
            Some("三体".to_string())
        );
    }

    #[test]
    fn extract_kv_no_match_returns_none() {
        assert_eq!(extract_kv("这是一行无标记的正文", &["书名", "作者"]), None);
    }

    #[test]
    fn extract_kv_multiple_keys_finds_first() {
        assert_eq!(
            extract_kv("书名：三体", &["书名", "作者"]),
            Some("三体".to_string())
        );
    }

    #[test]
    fn extract_kv_colon_only_no_value() {
        // extract_kv 要求值非空（line 77: if !val.is_empty()）
        assert_eq!(extract_kv("书名：", &["书名"]), None);
    }

    #[test]
    fn extract_kv_line_without_colon() {
        assert_eq!(extract_kv("没有冒号的行", &["书名"]), None);
    }

    #[test]
    fn extract_kv_author_field() {
        assert_eq!(
            extract_kv("作者：刘慈欣", &["作者"]),
            Some("刘慈欣".to_string())
        );
    }
}

