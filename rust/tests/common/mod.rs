#[allow(dead_code)]
use std::sync::Once;
#[allow(dead_code)]
use std::sync::OnceLock;
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

// ==================== 存储测试工具 ====================

/// 全局测试存储目录，仅初始化一次（生命周期与测试进程一致）
static TEST_STORAGE: OnceLock<TempDir> = OnceLock::new();

/// 初始化测试存储环境（全局只初始化一次）
///
/// 在第一个测试文件中被调用时创建临时目录并初始化存储引擎。
/// 后续调用直接返回，不会重复初始化。
#[allow(dead_code)]
#[allow(clippy::collapsible_if)]
pub async fn init_test_storage() {
    if TEST_STORAGE.get().is_some() {
        return;
    }

    let temp_dir = TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    if let Err(e) = rust_lib_zephyr_reader::infra::init::init_storage(data_dir).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {e}");
        }
    }

    TEST_STORAGE.get_or_init(|| temp_dir);
}

/// 创建（或更新）一个最小测试书籍，标准默认字段
#[allow(dead_code)]
pub async fn ensure_test_book(book_id: &str) {
    use rust_lib_zephyr_reader::api::book;
    use rust_lib_zephyr_reader::domain::book::Book;

    let b = Book {
        book_id: book_id.to_string(),
        file_path: format!("/test/{book_id}.txt"),
        file_size: 1024,
        title: book_id.to_string(),
        chapter_count: 1,
        added_at: chrono::Utc::now(),
        ..Default::default()
    };
    book::upsert_book(b).await.unwrap();
}
