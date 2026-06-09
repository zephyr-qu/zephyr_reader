#[allow(dead_code)]
use std::sync::Once;
#[allow(dead_code)]
use tempfile::TempDir;

#[allow(dead_code)]
static INIT: Once = Once::new();

/// 初始化 tracing 日志（仅在集成测试中启动一次）
#[allow(dead_code)]
pub fn init_logger() {
    INIT.call_once(|| {
        let _ = tracing_subscriber::fmt()
            .with_env_filter(tracing_subscriber::EnvFilter::new("error"))
            .try_init();
    });
}

/// 创建临时文件并返回路径（文件随 TempDir drop 自动清理）
#[allow(dead_code)]
pub fn create_temp_file(name: &str, content: &str) -> (TempDir, String) {
    let dir = TempDir::new().expect("failed to create temp dir");
    let path = dir.path().join(name);
    std::fs::write(&path, content).expect("failed to write temp file");
    let path_str = path.to_str().unwrap().to_string();
    (dir, path_str)
}