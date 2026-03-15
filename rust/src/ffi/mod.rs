//! FFI 接口模块
//! 对外暴露的模块声明

pub mod error;
pub mod types;

pub use error::{ApiResult, ParserError, TypesetError};
pub use types::*;
