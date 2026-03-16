//! 统一配置系统
//!
//! 提供应用配置的集中管理，支持 TOML 文件加载和默认配置。
//!
//! # 配置结构
//!
//! - **ParserConfig**: 解析器配置（并行、缓存等）
//! - **CacheConfig**: 缓存配置（大小、TTL 等）
//! - **SearchConfig**: 搜索配置（索引块大小、结果数等）
//! - **PerformanceConfig**: 性能配置（指标、慢操作日志等）
//!
//! # 使用示例
//!
//! ```rust
//! use rust_lib_zephyr_reader::config::{get_config, AppConfig};
//!
//! // 获取全局配置
//! let config = get_config();
//! println!("并行解析：{}", config.parser.enable_parallel);
//!
//! // 获取配置（FFI 接口）
//! let app_config = get_app_config();
//! ```

use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::OnceLock;

/// 应用配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    /// 解析器配置
    pub parser: ParserConfig,
    /// 缓存配置
    pub cache: CacheConfig,
    /// 搜索配置
    pub search: SearchConfig,
    /// 性能配置
    pub performance: PerformanceConfig,
}

/// 解析器配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParserConfig {
    /// 是否启用并行解析
    pub enable_parallel: bool,
    /// 并行处理的线程数（0 表示使用 CPU 核心数）
    pub parallel_threads: usize,
    /// 默认编码
    pub default_encoding: String,
    /// 是否验证章节
    pub validate_chapters: bool,
}

/// 缓存配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheConfig {
    /// 是否启用缓存
    pub enabled: bool,
    /// 最大条目数
    pub max_entries: usize,
    /// 最大内存占用（MB）
    pub max_memory_mb: usize,
    /// 缓存过期时间（秒）
    pub ttl_seconds: u64,
}

/// 搜索配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchConfig {
    /// 索引块大小
    pub index_chunk_size: usize,
    /// 摘要长度
    pub snippet_length: usize,
    /// 最大结果数
    pub max_results: usize,
}

/// 性能配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceConfig {
    /// 是否启用性能指标
    pub enable_metrics: bool,
    /// 是否记录慢操作
    pub log_slow_operations: bool,
    /// 慢操作阈值（毫秒）
    pub slow_threshold_ms: u64,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            parser: ParserConfig {
                enable_parallel: true,
                parallel_threads: 0, // 0 = 自动检测
                default_encoding: "utf-8".to_string(),
                validate_chapters: true,
            },
            cache: CacheConfig {
                enabled: true,
                max_entries: 100,
                max_memory_mb: 50,
                ttl_seconds: 3600,
            },
            search: SearchConfig {
                index_chunk_size: 500,
                snippet_length: 100,
                max_results: 50,
            },
            performance: PerformanceConfig {
                enable_metrics: true,
                log_slow_operations: true,
                slow_threshold_ms: 100,
            },
        }
    }
}

/// 全局配置实例
static CONFIG: OnceLock<AppConfig> = OnceLock::new();

/// 获取全局配置
///
/// 如果未加载配置文件，返回默认配置。
pub fn get_config() -> &'static AppConfig {
    CONFIG.get_or_init(|| {
        load_config().unwrap_or_else(|e| {
            tracing::warn!("加载配置文件失败：{}, 使用默认配置", e);
            AppConfig::default()
        })
    })
}

/// 加载配置文件
///
/// 从环境变量 `ZEPHYR_CONFIG` 指定的路径加载配置，
/// 如果未设置环境变量，默认从 `config.toml` 加载。
///
/// # 返回值
///
/// * `Ok(AppConfig)` - 加载成功
/// * `Err(Box<dyn std::error::Error>)` - 加载失败
pub fn load_config() -> Result<AppConfig, Box<dyn std::error::Error>> {
    let config_path = std::env::var("ZEPHYR_CONFIG").unwrap_or_else(|_| "config.toml".to_string());

    if Path::new(&config_path).exists() {
        let content = std::fs::read_to_string(&config_path)?;
        let config: AppConfig = toml::from_str(&content)?;
        tracing::info!("配置文件加载成功：{}", config_path);
        Ok(config)
    } else {
        tracing::info!("配置文件不存在，使用默认配置：{}", config_path);
        Ok(AppConfig::default())
    }
}

/// 初始化配置
///
/// 从指定路径加载配置文件。
///
/// # 参数
///
/// * `config_path` - 配置文件路径
///
/// # 返回值
///
/// * `Ok(())` - 初始化成功
/// * `Err(Box<dyn std::error::Error>)` - 初始化失败
pub fn init_config(config_path: &str) -> Result<(), Box<dyn std::error::Error>> {
    let config = if Path::new(config_path).exists() {
        let content = std::fs::read_to_string(config_path)?;
        toml::from_str(&content)?
    } else {
        tracing::warn!("配置文件不存在，使用默认配置：{}", config_path);
        AppConfig::default()
    };

    CONFIG.set(config).map_err(|_| "配置已经初始化")?;
    Ok(())
}

/// 获取应用配置（FFI 接口）
///
/// 供 Flutter 侧调用，获取当前配置。
#[flutter_rust_bridge::frb(sync)]
pub fn get_app_config() -> AppConfig {
    get_config().clone()
}

/// 初始化配置（FFI 接口）
///
/// 供 Flutter 侧调用，从指定路径加载配置。
///
/// # 参数
///
/// * `config_path` - 配置文件路径
///
/// # 返回值
///
/// * `Ok(())` - 初始化成功
/// * `Err(String)` - 初始化失败
#[flutter_rust_bridge::frb(sync)]
pub fn init_app_config(config_path: String) -> Result<(), String> {
    init_config(&config_path).map_err(|e| e.to_string())
}

/// 重置配置为默认值（FFI 接口）
///
/// 供 Flutter 侧调用，重置配置。
#[flutter_rust_bridge::frb(sync)]
pub fn reset_app_config() {
    // OnceLock 无法重置，这里仅记录日志
    tracing::info!("配置重置请求已接收（需要重启应用才能生效）");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = AppConfig::default();

        assert!(config.parser.enable_parallel);
        assert_eq!(config.parser.parallel_threads, 0);
        assert!(config.cache.enabled);
        assert_eq!(config.cache.max_entries, 100);
        assert!(config.performance.enable_metrics);
    }

    #[test]
    fn test_get_config() {
        let config = get_config();

        // 应该返回默认配置（因为没有配置文件）
        assert!(config.parser.enable_parallel);
    }

    #[test]
    fn test_config_serialization() {
        let config = AppConfig::default();
        let serialized = toml::to_string(&config).unwrap();

        assert!(serialized.contains("enable_parallel"));
        assert!(serialized.contains("max_entries"));
    }

    #[test]
    fn test_config_deserialization() {
        let toml_str = r#"
            [parser]
            enable_parallel = false
            parallel_threads = 4
            default_encoding = "utf-8"
            validate_chapters = true

            [cache]
            enabled = true
            max_entries = 200
            max_memory_mb = 100
            ttl_seconds = 7200

            [search]
            index_chunk_size = 1000
            snippet_length = 200
            max_results = 100

            [performance]
            enable_metrics = false
            log_slow_operations = true
            slow_threshold_ms = 200
        "#;

        let config: AppConfig = toml::from_str(toml_str).unwrap();

        assert!(!config.parser.enable_parallel);
        assert_eq!(config.parser.parallel_threads, 4);
        assert_eq!(config.cache.max_entries, 200);
        assert!(!config.performance.enable_metrics);
    }
}
