//! 简单的测试 API

use flutter_rust_bridge::frb;

/// 简单的问候函数
#[frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}
