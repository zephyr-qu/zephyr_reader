use std::sync::Once;
use tempfile::TempDir;

static INIT: Once = Once::new();

pub fn init_logger() {
    INIT.call_once(|| {
        let _ = tracing_subscriber::fmt()
            .with_env_filter(tracing_subscriber::EnvFilter::new("error"))
            .try_init();
    });
}

pub fn create_temp_file(name: &str, content: &str) -> (TempDir, String) {
    let dir = TempDir::new().expect("failed to create temp dir");
    let path = dir.path().join(name);
    std::fs::write(&path, content).expect("failed to write temp file");
    let path_str = path.to_str().unwrap().to_string();
    (dir, path_str)
}

// pub async fn ensure_storage(dir: &TempDir) -> String {
//     let data_dir = dir.path().to_str().unwrap().to_string();
//     rust_lib_zephyr_reader::api::init_storage(data_dir.clone())
//         .await
//         .expect("failed to init storage");
//     data_dir
// }
