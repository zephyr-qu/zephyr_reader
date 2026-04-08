//! 封面提取 API
//!
//! 提供统一的封面提取入口，支持 EPUB、PDF 等多种格式。
use crate::api::security::validate_file_path;
use crate::catch_panic;
use crate::ffi::{ApiResult, ParserError};
use crate::parser::get_cover_registry;
use flutter_rust_bridge::frb;
use std::path::Path;

/// 提取书籍封面
///
/// 自动检测文件类型并提取封面图片，保存到指定目录。
#[frb(sync)]
pub fn extract_book_cover(file_path: String, output_dir: String) -> ApiResult<String> {
    catch_panic! {
        {
            let validated_path = validate_file_path(&file_path)?;

            if !Path::new(&validated_path).exists() {
                return Err(ParserError::file_not_found(&validated_path));
            }

            let registry = get_cover_registry();
            registry.extract_cover(&validated_path, &output_dir)
        }
    }
}

/// 检查是否支持封面提取
#[frb(sync)]
pub fn supports_cover_extraction(file_path: String) -> bool {
    let path = Path::new(&file_path);
    let extension = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|s| s.to_lowercase())
        .unwrap_or_default();

    let registry = get_cover_registry();
    registry.supports_format(&extension)
}
