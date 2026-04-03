//! 内部工具模块
//!
//! 提供内部使用的工具函数和类型，不直接暴露给 FFI。

use crate::ffi::ParserError;
use anyhow::Result as AnyhowResult;

/// 内部结果类型（使用 anyhow）
///
/// 用于模块内部错误处理，提供更丰富的错误上下文。
/// 在 FFI 边界转换为 `ApiResult<T>`。
pub type InternalResult<T> = AnyhowResult<T>;

/// 将 anyhow 错误转换为 ParserError
///
/// # 用法
///
/// ```ignore
/// use crate::utils::internal::{InternalResult, AnyhowContext};
/// use crate::ffi::{ParserError, ApiResult};
///
/// fn internal_operation(path: &str) -> InternalResult<String> {
///     // ...
/// }
///
/// pub fn public_api(path: String) -> ApiResult<String> {
///     internal_operation(&path)
///         .context_with(format!("操作失败：{}", path))
///         .map_err(ParserError::from_anyhow)
/// }
/// ```
pub trait AnyhowContext<T> {
    /// 添加错误上下文并转换为 ParserError
    fn context_with<C>(self, context: C) -> Result<T, ParserError>
    where
        C: std::fmt::Display + Send + Sync + 'static;
}

impl<T> AnyhowContext<T> for AnyhowResult<T> {
    fn context_with<C>(self, context: C) -> Result<T, ParserError>
    where
        C: std::fmt::Display + Send + Sync + 'static,
    {
        self.map_err(|e| ParserError::InternalError(format!("{}: {}", context, e)))
    }
}

/// 扩展 ParserError，支持从 anyhow 转换
impl ParserError {
    /// 从 anyhow 错误创建 ParserError
    ///
    /// 保留完整的错误链信息。
    pub fn from_anyhow<E>(err: E) -> Self
    where
        E: std::fmt::Display + Send + Sync + 'static,
    {
        ParserError::InternalError(err.to_string())
    }

    /// 创建带上下文的文件读取错误
    pub fn file_read_error_with_context(
        path: impl Into<String>,
        context: impl std::fmt::Display,
    ) -> Self {
        ParserError::FileReadError {
            path: path.into(),
            message: format!("{}", context),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use anyhow::anyhow;

    #[test]
    fn test_anyhow_context_conversion() {
        let result: AnyhowResult<String> = Err(anyhow!("内部错误"));
        let converted = result.context_with("操作失败");

        assert!(converted.is_err());
        let err = converted.unwrap_err();
        match err {
            ParserError::InternalError(msg) => {
                assert!(
                    msg.contains("操作失败"),
                    "Expected error message to contain '操作失败', got: {}",
                    msg
                );
                assert!(
                    msg.contains("内部错误"),
                    "Expected error message to contain '内部错误', got: {}",
                    msg
                );
            }
            other => panic!("Expected InternalError, got: {:?}", other),
        }
    }
}
