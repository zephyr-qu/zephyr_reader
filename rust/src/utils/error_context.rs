//! 错误上下文增强模块
//!
//! 使用 `anyhow` 提供丰富的错误上下文信息，便于调试和问题定位。
//!
//! # 设计原则
//!
//! - **内部使用 anyhow**: 在内部实现中使用 `anyhow::Result` 和 `Context`
//! - **边界转换为 ParserError**: 在 FFI 边界将 anyhow 错误转换为 ParserError
//! - **保留完整上下文**: 错误链包含所有相关信息（文件路径、操作步骤等）

use anyhow::{Context, Result as AnyhowResult};
use std::path::Path;

use crate::ffi::{ApiResult, ParserError};

/// 文件读取错误上下文扩展
pub trait FileReadContext<T> {
    /// 添加文件读取错误上下文
    fn with_file_read_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> FileReadContext<T> for AnyhowResult<T> {
    fn with_file_read_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| ParserError::FileReadError {
            path: file_path.to_string(),
            message: format!("{}", e),
        })
    }
}

/// 文件打开错误上下文扩展
pub trait FileOpenContext<T> {
    /// 添加文件打开错误上下文
    fn with_file_open_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> FileOpenContext<T> for AnyhowResult<T> {
    fn with_file_open_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| ParserError::FileReadError {
            path: file_path.to_string(),
            message: format!("{}", e),
        })
    }
}

/// PDF 解析错误上下文扩展
pub trait PdfParseContext<T> {
    /// 添加 PDF 解析错误上下文
    fn with_pdf_parse_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> PdfParseContext<T> for AnyhowResult<T> {
    fn with_pdf_parse_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| ParserError::PdfParseError(format!("PDF 解析失败 [{}]: {}", file_path, e)))
    }
}

/// EPUB 解析错误上下文扩展
pub trait EpubParseContext<T> {
    /// 添加 EPUB 解析错误上下文
    fn with_epub_parse_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> EpubParseContext<T> for AnyhowResult<T> {
    fn with_epub_parse_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| {
            ParserError::EpubParseError(format!("EPUB 解析失败 [{}]: {}", file_path, e))
        })
    }
}

/// TXT 解析错误上下文扩展
pub trait TxtParseContext<T> {
    /// 添加 TXT 解析错误上下文
    fn with_txt_parse_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> TxtParseContext<T> for AnyhowResult<T> {
    fn with_txt_parse_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| ParserError::TxtParseError(format!("TXT 解析失败 [{}]: {}", file_path, e)))
    }
}

/// 章节提取错误上下文扩展
pub trait ChapterExtractContext<T> {
    /// 添加章节提取错误上下文
    fn with_chapter_extract_context(self, chapter_title: &str) -> ApiResult<T>;
}

impl<T> ChapterExtractContext<T> for AnyhowResult<T> {
    fn with_chapter_extract_context(self, chapter_title: &str) -> ApiResult<T> {
        self.map_err(|e| {
            ParserError::ChapterExtractError(format!("提取章节内容失败 [{}]: {}", chapter_title, e))
        })
    }
}

/// 编码检测错误上下文扩展
pub trait EncodingContext<T> {
    /// 添加编码检测错误上下文
    fn with_encoding_context(self, file_path: &str) -> ApiResult<T>;
}

impl<T> EncodingContext<T> for AnyhowResult<T> {
    fn with_encoding_context(self, file_path: &str) -> ApiResult<T> {
        self.map_err(|e| {
            ParserError::EncodingError(format!("编码检测/转换失败 [{}]: {}", file_path, e))
        })
    }
}

/// 辅助函数：使用 anyhow 包装文件读取
pub fn read_file_with_context(file_path: &str) -> ApiResult<Vec<u8>> {
    std::fs::read(file_path)
        .with_context(|| format!("无法读取文件：{}", file_path))
        .with_file_read_context(file_path)
}

/// 辅助函数：使用 anyhow 包装文件打开
pub fn open_file_with_context(file_path: &str) -> ApiResult<std::fs::File> {
    std::fs::File::open(file_path)
        .with_context(|| format!("无法打开文件：{}", file_path))
        .with_file_open_context(file_path)
}

/// 辅助函数：检查文件是否存在并返回路径
pub fn validate_file_path_with_context(file_path: &str) -> ApiResult<String> {
    let path = Path::new(file_path);

    if !path.exists() {
        return Err(ParserError::FileNotFound {
            path: file_path.to_string(),
            reason: "文件不存在".to_string(),
        });
    }

    if !path.is_file() {
        return Err(ParserError::FileReadError {
            path: file_path.to_string(),
            message: format!("路径不是有效文件：{}", file_path),
        });
    }

    Ok(file_path.to_string())
}

/// 错误上下文构建器
///
/// 提供链式调用的错误上下文添加方式
pub struct ErrorContextBuilder {
    file_path: Option<String>,
    operation: Option<String>,
    details: Vec<String>,
}

impl ErrorContextBuilder {
    /// 创建新的错误上下文构建器
    pub fn new() -> Self {
        Self {
            file_path: None,
            operation: None,
            details: Vec::new(),
        }
    }

    /// 设置文件路径
    pub fn file_path(mut self, path: &str) -> Self {
        self.file_path = Some(path.to_string());
        self
    }

    /// 设置操作描述
    pub fn operation(mut self, op: &str) -> Self {
        self.operation = Some(op.to_string());
        self
    }

    /// 添加详细信息
    pub fn detail(mut self, detail: &str) -> Self {
        self.details.push(detail.to_string());
        self
    }

    /// 构建错误消息
    pub fn build(&self) -> String {
        let mut parts = Vec::new();

        if let Some(ref op) = self.operation {
            parts.push(op.clone());
        }

        if let Some(ref path) = self.file_path {
            parts.push(format!("[{}]", path));
        }

        if !self.details.is_empty() {
            parts.push(format!("({})", self.details.join(", ")));
        }

        parts.join(" ")
    }

    /// 包装 anyhow 错误为 ParserError
    pub fn wrap_error(self, error: anyhow::Error) -> ParserError {
        let context = self.build();
        ParserError::Other(format!("{}: {}", context, error))
    }
}

impl Default for ErrorContextBuilder {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_context_builder() {
        let builder = ErrorContextBuilder::new()
            .file_path("test.txt")
            .operation("解析文件")
            .detail("章节数为 0");

        let context = builder.build();
        assert!(context.contains("解析文件"));
        assert!(context.contains("[test.txt]"));
        assert!(context.contains("(章节数为 0)"));
    }

    #[test]
    fn test_validate_file_path_with_context_not_found() {
        let result = validate_file_path_with_context("non_existent_file.txt");
        assert!(result.is_err());
        match result.unwrap_err() {
            ParserError::FileNotFound { .. } => (),
            _ => panic!("Expected FileNotFound error"),
        }
    }

    #[test]
    fn test_read_file_with_context_not_found() {
        let result = read_file_with_context("non_existent_file.txt");
        assert!(result.is_err());
        match result.unwrap_err() {
            ParserError::FileReadError { .. } => (),
            _ => panic!("Expected FileReadError"),
        }
    }
}
