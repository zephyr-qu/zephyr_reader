// ============================================================
// 文件作用：应用初始化入口函数
//
// 公有类型/函数：
//   - init_app() — 由 Flutter 端通过 FRB 调用，一次初始化
//     日志系统、FRB 工具、解析器注册表、封面提取器
// ============================================================

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::parser;

/// 应用初始化入口函数
///
/// 由 Flutter 端通过 flutter_rust_bridge 调用，在应用启动时执行一次。
///
/// 初始化内容包括：
/// 1. 配置日志系统，支持通过环境变量控制日志级别
/// 2. 初始化 flutter_rust_bridge 默认工具
/// 3. 注册所有文件格式解析器（TXT、EPUB 等）
/// 4. 注册封面提取器
#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::EnvFilter;

    // 从环境变量读取日志级别，如果未设置则默认为 "info"
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .try_init();

    // 设置 flutter_rust_bridge 默认用户工具
    flutter_rust_bridge::setup_default_user_utils();

    // 所有解析器已内建于 Parser 枚举，无需注册
    tracing::info!("Parser registry initialized (built-in enum)");

    // 初始化封面提取器注册表
    parser::get_cover_registry();
    tracing::info!("Cover extractor registry initialized");

    tracing::info!("Rust reader engine initialized");
}

// Reserved: FRB binding exists for binary compatibility (frb_generated.rs).
#[frb]
pub fn test_connection() -> Result<String, AppError> {
    Ok("Rust reader engine connected successfully".to_string())
}
