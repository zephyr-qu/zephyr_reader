//! 插件化解析器架构
//!
//! 提供统一的解析器 trait 和注册表，支持动态扩展文件格式支持。
//!
//! # 设计目标
//!
//! - **可扩展性**: 轻松添加新的文件格式支持
//! - **统一接口**: 所有解析器实现相同的 trait
//! - **运行时注册**: 支持动态注册/注销解析器
//! - **线程安全**: 支持多线程并发访问

use parking_lot::Mutex;
use std::collections::HashMap;
use std::sync::Arc;

use flutter_rust_bridge::frb;

use crate::ffi::{ApiResult, ParseResult, ParserError};

/// 书籍元数据
#[derive(Debug, Clone, Default)]
#[frb]
pub struct BookMetadata {
    /// 书籍标题
    pub title: String,
    /// 作者
    pub author: String,
    /// 描述/简介
    pub description: Option<String>,
    /// 封面路径
    pub cover_path: Option<String>,
    /// 出版年份
    pub publish_year: Option<i32>,
    /// 语言
    pub language: Option<String>,
    /// 总章节数
    pub chapter_count: i32,
    /// 总字符数
    pub total_characters: i64,
}

/// 解析器 trait
///
/// 所有文件格式解析器必须实现此 trait。
pub trait BookParser: Send + Sync {
    /// 获取解析器名称
    fn name(&self) -> &str;

    /// 获取支持的格式列表
    ///
    /// 返回文件扩展名列表（小写，不含点）
    /// 例如：["txt", "text"]
    fn supported_formats(&self) -> Vec<&str>;

    /// 解析文件
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析成功
    /// * `Err(ParserError)` - 解析失败
    fn parse(&self, file_path: &str) -> ApiResult<ParseResult>;

    /// 提取元数据
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(BookMetadata)` - 元数据提取成功
    /// * `Err(ParserError)` - 提取失败
    fn extract_metadata(&self, file_path: &str) -> ApiResult<BookMetadata>;

    /// 提取章节内容
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    /// * `chapter_id` - 章节 ID
    ///
    /// # 返回值
    ///
    /// * `Ok(String)` - 章节内容
    /// * `Err(ParserError)` - 提取失败
    fn extract_chapter(&self, file_path: &str, chapter_id: i32) -> ApiResult<String>;

    /// 检查是否支持指定格式
    fn supports_format(&self, format: &str) -> bool {
        self.supported_formats()
            .iter()
            .any(|&f| f.eq_ignore_ascii_case(format))
    }
}

/// 解析器注册表
///
/// 管理所有已注册的解析器，提供格式到解析器的映射。
pub struct ParserRegistry {
    parsers: HashMap<String, Arc<dyn BookParser>>,
    format_map: HashMap<String, String>, // format -> parser_name
}

impl ParserRegistry {
    /// 创建新的解析器注册表
    pub fn new() -> Self {
        Self {
            parsers: HashMap::new(),
            format_map: HashMap::new(),
        }
    }

    /// 注册解析器
    ///
    /// # 参数
    ///
    /// * `parser` - 解析器实例（必须实现 `BookParser` trait）
    ///
    /// # 返回值
    ///
    /// * `Ok(())` - 注册成功
    /// * `Err(String)` - 注册失败（解析器名称冲突）
    pub fn register(&mut self, parser: Arc<dyn BookParser>) -> Result<(), String> {
        let name = parser.name().to_string();

        if self.parsers.contains_key(&name) {
            return Err(format!("解析器 '{}' 已经注册", name));
        }

        // 注册格式映射
        for format in parser.supported_formats() {
            let format_lower = format.to_lowercase();
            if let Some(existing) = self.format_map.get(&format_lower) {
                tracing::warn!(
                    "格式 '{}' 已被解析器 '{}' 注册，现在被 '{}' 覆盖",
                    format_lower,
                    existing,
                    name
                );
            }
            self.format_map.insert(format_lower, name.clone());
        }

        self.parsers.insert(name.clone(), parser);
        tracing::info!("解析器注册成功：{}", name);
        Ok(())
    }

    /// 注销解析器
    ///
    /// # 参数
    ///
    /// * `name` - 解析器名称
    ///
    /// # 返回值
    ///
    /// * `Some(Arc<dyn BookParser>)` - 注销成功，返回被移除的解析器
    /// * `None` - 解析器不存在
    pub fn unregister(&mut self, name: &str) -> Option<Arc<dyn BookParser>> {
        if let Some(parser) = self.parsers.remove(name) {
            // 清理格式映射
            let formats_to_remove: Vec<String> = self
                .format_map
                .iter()
                .filter(|(_, v)| v.as_str() == name)
                .map(|(k, _)| k.clone())
                .collect();

            for format in formats_to_remove {
                self.format_map.remove(&format);
            }

            tracing::info!("解析器注销成功：{}", name);
            Some(parser)
        } else {
            None
        }
    }

    /// 获取指定格式的解析器
    ///
    /// # 参数
    ///
    /// * `format` - 文件格式（扩展名，不含点）
    ///
    /// # 返回值
    ///
    /// * `Some(Arc<dyn BookParser>)` - 找到解析器
    /// * `None` - 未找到支持的解析器
    pub fn get_parser(&self, format: &str) -> Option<Arc<dyn BookParser>> {
        let format_lower = format.to_lowercase();
        self.format_map
            .get(&format_lower)
            .and_then(|name| self.parsers.get(name).cloned())
    }

    /// 获取所有已注册的解析器名称
    pub fn registered_parsers(&self) -> Vec<&str> {
        self.parsers.keys().map(|s| s.as_str()).collect()
    }

    /// 获取所有支持的格式
    pub fn supported_formats(&self) -> Vec<String> {
        self.format_map.keys().cloned().collect()
    }

    /// 检查是否支持指定格式
    pub fn supports_format(&self, format: &str) -> bool {
        self.format_map.contains_key(&format.to_lowercase())
    }

    /// 解析文件（自动选择解析器）
    ///
    /// # 参数
    ///
    /// * `file_path` - 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析成功
    /// * `Err(ParserError)` - 解析失败
    pub fn parse_file(&self, file_path: &str) -> ApiResult<ParseResult> {
        let extension = std::path::Path::new(file_path)
            .extension()
            .and_then(|ext| ext.to_str())
            .ok_or_else(|| ParserError::UnsupportedFormat("无法识别文件扩展名".to_string()))?;

        let parser = self.get_parser(extension).ok_or_else(|| {
            ParserError::UnsupportedFormat(format!("不支持的文件格式：{}", extension))
        })?;

        parser.parse(file_path)
    }
}

impl Default for ParserRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// 线程安全的解析器注册表
pub struct ThreadSafeParserRegistry {
    inner: Mutex<ParserRegistry>,
}

impl ThreadSafeParserRegistry {
    /// 创建新的线程安全注册表
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(ParserRegistry::new()),
        }
    }

    /// 注册解析器
    pub fn register(&self, parser: Arc<dyn BookParser>) -> Result<(), String> {
        let mut registry = self.inner.lock();
        registry.register(parser)
    }

    /// 解析文件
    pub fn parse_file(&self, file_path: &str) -> ApiResult<ParseResult> {
        let registry = self.inner.lock();
        registry.parse_file(file_path)
    }

    /// 检查是否支持指定格式
    pub fn supports_format(&self, format: &str) -> bool {
        self.inner.lock().supports_format(format)
    }

    /// 获取指定格式的解析器
    ///
    /// # 参数
    ///
    /// * `format` - 文件格式（扩展名，不含点）
    ///
    /// # 返回值
    ///
    /// * `Some(Arc<dyn BookParser>)` - 找到解析器
    /// * `None` - 未找到支持的解析器
    pub fn get_parser(&self, format: &str) -> Option<Arc<dyn BookParser>> {
        self.inner.lock().get_parser(format)
    }

    /// 获取所有支持的格式
    pub fn supported_formats(&self) -> Vec<String> {
        self.inner.lock().supported_formats()
    }
}

impl Default for ThreadSafeParserRegistry {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试用解析器
    struct TestParser {
        name: String,
        formats: Vec<String>,
    }

    impl TestParser {
        fn new(name: &str, formats: Vec<&str>) -> Self {
            Self {
                name: name.to_string(),
                formats: formats.iter().map(|s| s.to_string()).collect(),
            }
        }
    }

    impl BookParser for TestParser {
        fn name(&self) -> &str {
            &self.name
        }

        fn supported_formats(&self) -> Vec<&str> {
            self.formats.iter().map(|s| s.as_str()).collect()
        }

        fn parse(&self, _file_path: &str) -> ApiResult<ParseResult> {
            unimplemented!()
        }

        fn extract_metadata(&self, _file_path: &str) -> ApiResult<BookMetadata> {
            unimplemented!()
        }

        fn extract_chapter(&self, _file_path: &str, _chapter_id: i32) -> ApiResult<String> {
            unimplemented!()
        }
    }

    #[test]
    fn test_parser_registry_register() {
        let mut registry = ParserRegistry::new();
        let parser = Arc::new(TestParser::new("test", vec!["txt"]));

        assert!(registry.register(parser).is_ok());
        assert!(registry.supports_format("txt"));
    }

    #[test]
    fn test_parser_registry_duplicate_register() {
        let mut registry = ParserRegistry::new();
        let parser1 = Arc::new(TestParser::new("test", vec!["txt"]));
        let parser2 = Arc::new(TestParser::new("test", vec!["epub"]));

        assert!(registry.register(parser1).is_ok());
        assert!(registry.register(parser2).is_err()); // 名称冲突
    }

    #[test]
    fn test_parser_registry_get_parser() {
        let mut registry = ParserRegistry::new();
        let parser = Arc::new(TestParser::new("test", vec!["txt", "text"]));
        registry.register(parser).unwrap();

        assert!(registry.get_parser("txt").is_some());
        assert!(registry.get_parser("TXT").is_some()); // 大小写不敏感
        assert!(registry.get_parser("epub").is_none());
    }

    #[test]
    fn test_parser_registry_unregister() {
        let mut registry = ParserRegistry::new();
        let parser = Arc::new(TestParser::new("test", vec!["txt"]));
        registry.register(parser).unwrap();

        assert!(registry.unregister("test").is_some());
        assert!(registry.get_parser("txt").is_none());
    }

    #[test]
    fn test_parser_registry_supported_formats() {
        let mut registry = ParserRegistry::new();
        registry
            .register(Arc::new(TestParser::new("txt_parser", vec!["txt"])))
            .unwrap();
        registry
            .register(Arc::new(TestParser::new("epub_parser", vec!["epub"])))
            .unwrap();

        let formats = registry.supported_formats();
        assert!(formats.contains(&"txt".to_string()));
        assert!(formats.contains(&"epub".to_string()));
    }

    #[test]
    fn test_thread_safe_registry() {
        let registry = ThreadSafeParserRegistry::new();
        let parser = Arc::new(TestParser::new("test", vec!["txt"]));

        assert!(registry.register(parser).is_ok());
        assert!(registry.supports_format("txt"));
        assert!(!registry.supports_format("epub"));
    }
}
