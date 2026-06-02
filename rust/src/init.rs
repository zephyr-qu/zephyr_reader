use std::sync::OnceLock;

/// 应用初始化模块
///
/// 负责初始化 Rust 核心引擎的各项服务，包括：
/// - 日志系统（tracing）
/// - 线程池（rayon）
/// - 解析器注册表
/// - 封面提取器注册表
use flutter_rust_bridge::frb;

use crate::parser;

// Rayon 全局线程池初始化状态
static RAYON_INIT: OnceLock<()> = OnceLock::new();

/// 初始化 Rayon 全局线程池（线程安全，只执行一次）
///
/// 根据 CPU 核心数创建线程池，默认最少 4 个线程。
/// 该函数是线程安全的，多次调用只会执行一次初始化。
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

/// 应用初始化入口函数
///
/// 由 Flutter 端通过 flutter_rust_bridge 调用，在应用启动时执行一次。
///
/// 初始化内容包括：
/// 1. 配置日志系统，支持通过环境变量控制日志级别
/// 2. 初始化 rayon 全局线程池，用于并行处理
/// 3. 初始化 flutter_rust_bridge 默认工具
/// 4. 注册所有文件格式解析器（TXT、EPUB 等）
/// 5. 注册封面提取器
#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::EnvFilter;

    // 从环境变量读取日志级别，如果未设置则默认为 "info"
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .try_init();

    // 初始化 rayon 全局线程池，用于大文件并行解析
    init_rayon_pool();
    // 设置 flutter_rust_bridge 默认用户工具
    flutter_rust_bridge::setup_default_user_utils();

    // 所有解析器已内建于 Parser 枚举，无需注册
    tracing::info!("Parser registry initialized (built-in enum)");

    // 初始化封面提取器注册表
    parser::get_cover_registry();
    tracing::info!("Cover extractor registry initialized");

    tracing::info!("Rust core engine initialized");
}
