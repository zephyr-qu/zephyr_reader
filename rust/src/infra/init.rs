// ============================================================
// 文件作用：应用初始化入口函数
//
// 公有类型/函数：
//   - init_app() — 由 Flutter 端通过 FRB 调用，一次初始化
//     日志系统、FRB 工具、解析器注册表、封面提取器
// ============================================================

use flutter_rust_bridge::frb;

use crate::common::AppError;

/// 应用初始化入口函数
///
/// 由 Flutter 端通过 flutter_rust_bridge 调用，在应用启动时执行一次。
#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::EnvFilter;

    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .try_init();

    flutter_rust_bridge::setup_default_user_utils();
    crate::parser::init_parser();

    tracing::info!("Rust reader engine initialized");
}

// Reserved: FRB binding exists for binary compatibility (frb_generated.rs).
#[frb]
pub fn test_connection() -> Result<String, AppError> {
    Ok("Rust reader engine connected successfully".to_string())
}
