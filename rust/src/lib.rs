//! Zephyr Reader Rust 核心引擎
//! 高性能双语文本解析引擎

use once_cell::sync::OnceCell;

pub mod api;
pub mod ffi;
pub mod parser;
pub mod search;
pub mod storage;
pub mod stream;
pub mod text_process;

// Rayon 全局线程池初始化状态
static RAYON_INIT: OnceCell<()> = OnceCell::new();

/// 初始化 Rayon 全局线程池（线程安全，只执行一次）
pub fn init_rayon_pool() {
    RAYON_INIT.get_or_init(|| {
        let num_threads = std::thread::available_parallelism()
            .map(|p| p.get())
            .unwrap_or(4);

        rayon::ThreadPoolBuilder::new()
            .num_threads(num_threads)
            .build_global()
            .unwrap_or_else(|e| {
                tracing::warn!("Rayon pool already initialized: {}", e);
            });
    });
}
// mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */