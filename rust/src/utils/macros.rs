//! 宏定义模块
//! 包含通用宏和辅助宏

/// 捕获 panic 并转换为 ParserError 的宏
///
/// 用于 FFI 边界函数，防止 panic 传播到 Dart 侧导致崩溃
///
/// # 用法
///
/// ```rust,ignore
/// #[frb(sync)]
/// pub fn some_function(...) -> ApiResult<SomeType> {
///     catch_panic! {
///         {
///             // 可能 panic 的代码
///             some_risky_operation()
///         }
///     }
/// }
/// ```
///
/// # 展开后
///
/// 宏会自动将 panic 转换为 `ParserError::InternalError`，并记录日志
#[macro_export]
macro_rules! catch_panic {
    ($block:block) => {{
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $block)).unwrap_or_else(|e| {
            let msg = if let Some(s) = e.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = e.downcast_ref::<String>() {
                s.clone()
            } else {
                "未知 panic".to_string()
            };
            tracing::error!("panic caught: {}", msg);
            Err($crate::ffi::ParserError::InternalError(format!(
                "内部错误：{}",
                msg
            )))
        })
    }};
}

/// 捕获 panic 并转换为 ParserError 的宏（带自定义错误消息）
///
/// 与 `catch_panic!` 类似，但允许指定自定义错误消息前缀
///
/// # 用法
///
/// ```rust,ignore
/// #[frb(sync)]
/// pub fn parse_file(...) -> ApiResult<ParseResult> {
///     catch_panic_with_msg! {
///         {
///             crate::parser::parse_txt(path)
///         },
///         "文件解析失败"
///     }
/// }
/// ```
#[macro_export]
macro_rules! catch_panic_with_msg {
    ($block:block, $msg:expr) => {{
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $block)).unwrap_or_else(|e| {
            let panic_msg = if let Some(s) = e.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = e.downcast_ref::<String>() {
                s.clone()
            } else {
                "未知 panic".to_string()
            };
            let full_msg = format!("{}: {}", $msg, panic_msg);
            tracing::error!("panic caught: {}", full_msg);
            Err($crate::ffi::ParserError::InternalError(full_msg))
        })
    }};
}

// #[cfg(test)]
// mod tests {

//     use rayon::result;

//     use crate::api::ParserError;
//     #[test]
//     fn test_catch_panic_normal() {
//         let result = catch_panic! {
//             {
//                 Ok::<_, ParserError>(42)
//             }
//         };
//         assert_eq!(result.unwrap(), 42);
//     }

// #[test]
// fn test_catch_panic_panics() {
//     let result = catch_panic! {
//         {
//             panic!("test panic");
//         }
//     };
//     assert!(result.is_err());
// }
// }
