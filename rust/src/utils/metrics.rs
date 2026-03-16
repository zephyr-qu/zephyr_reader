//! 性能监控指标模块
//!
//! 提供性能指标收集和统计功能，用于监控和优化 Rust 引擎性能。
//!
//! # 功能特性
//!
//! - **解析性能**: 记录解析操作的耗时和次数
//! - **缓存命中率**: 跟踪缓存命中/未命中情况
//! - **搜索性能**: 记录搜索操作的耗时
//! - **内存使用**: 估算内存占用情况
//! - **全局指标**: 使用 `once_cell` 实现全局单例
//!
//! # 使用示例
//!
//! ```rust
//! use rust_lib_zephyr_reader::utils::metrics::{METRICS, record_metrics};
//! use std::time::Instant;
//!
//! let start = Instant::now();
//! // ... 执行解析操作 ...
//! record_metrics!(parse, start);
//!
//! // 获取统计信息
//! let stats = METRICS.get_stats();
//! println!("平均解析时间：{} ms", stats.average_parse_time_ms);
//! ```

use once_cell::sync::Lazy;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};

/// 性能指标收集器
pub struct PerformanceMetrics {
    /// 解析操作次数
    parse_count: AtomicUsize,
    /// 解析总耗时（毫秒）
    parse_total_ms: AtomicU64,
    /// 缓存命中次数
    cache_hits: AtomicUsize,
    /// 缓存未命中次数
    cache_misses: AtomicUsize,
    /// 搜索操作次数
    search_count: AtomicUsize,
    /// 搜索总耗时（毫秒）
    search_total_ms: AtomicU64,
    /// 文件读取次数
    file_read_count: AtomicUsize,
    /// 文件读取总耗时（毫秒）
    file_read_total_ms: AtomicU64,
    /// 章节验证次数
    chapter_validate_count: AtomicUsize,
    /// 章节验证失败次数
    chapter_validate_failures: AtomicUsize,
}

impl PerformanceMetrics {
    /// 创建新的性能指标收集器
    pub fn new() -> Self {
        Self {
            parse_count: AtomicUsize::new(0),
            parse_total_ms: AtomicU64::new(0),
            cache_hits: AtomicUsize::new(0),
            cache_misses: AtomicUsize::new(0),
            search_count: AtomicUsize::new(0),
            search_total_ms: AtomicU64::new(0),
            file_read_count: AtomicUsize::new(0),
            file_read_total_ms: AtomicU64::new(0),
            chapter_validate_count: AtomicUsize::new(0),
            chapter_validate_failures: AtomicUsize::new(0),
        }
    }

    /// 记录解析操作
    ///
    /// # 参数
    ///
    /// * `duration_ms` - 解析耗时（毫秒）
    pub fn record_parse(&self, duration_ms: u64) {
        self.parse_count.fetch_add(1, Ordering::Relaxed);
        self.parse_total_ms
            .fetch_add(duration_ms, Ordering::Relaxed);
    }

    /// 记录缓存命中
    pub fn record_cache_hit(&self) {
        self.cache_hits.fetch_add(1, Ordering::Relaxed);
    }

    /// 记录缓存未命中
    pub fn record_cache_miss(&self) {
        self.cache_misses.fetch_add(1, Ordering::Relaxed);
    }

    /// 记录搜索操作
    ///
    /// # 参数
    ///
    /// * `duration_ms` - 搜索耗时（毫秒）
    pub fn record_search(&self, duration_ms: u64) {
        self.search_count.fetch_add(1, Ordering::Relaxed);
        self.search_total_ms
            .fetch_add(duration_ms, Ordering::Relaxed);
    }

    /// 记录文件读取操作
    ///
    /// # 参数
    ///
    /// * `duration_ms` - 读取耗时（毫秒）
    pub fn record_file_read(&self, duration_ms: u64) {
        self.file_read_count.fetch_add(1, Ordering::Relaxed);
        self.file_read_total_ms
            .fetch_add(duration_ms, Ordering::Relaxed);
    }

    /// 记录章节验证
    ///
    /// # 参数
    ///
    /// * `success` - 验证是否成功
    pub fn record_chapter_validate(&self, success: bool) {
        self.chapter_validate_count.fetch_add(1, Ordering::Relaxed);
        if !success {
            self.chapter_validate_failures
                .fetch_add(1, Ordering::Relaxed);
        }
    }

    /// 获取平均解析时间（毫秒）
    pub fn get_average_parse_time(&self) -> f64 {
        let count = self.parse_count.load(Ordering::Relaxed);
        if count == 0 {
            return 0.0;
        }
        self.parse_total_ms.load(Ordering::Relaxed) as f64 / count as f64
    }

    /// 获取平均搜索时间（毫秒）
    pub fn get_average_search_time(&self) -> f64 {
        let count = self.search_count.load(Ordering::Relaxed);
        if count == 0 {
            return 0.0;
        }
        self.search_total_ms.load(Ordering::Relaxed) as f64 / count as f64
    }

    /// 获取平均文件读取时间（毫秒）
    pub fn get_average_file_read_time(&self) -> f64 {
        let count = self.file_read_count.load(Ordering::Relaxed);
        if count == 0 {
            return 0.0;
        }
        self.file_read_total_ms.load(Ordering::Relaxed) as f64 / count as f64
    }

    /// 获取缓存命中率
    pub fn get_cache_hit_rate(&self) -> f64 {
        let hits = self.cache_hits.load(Ordering::Relaxed);
        let misses = self.cache_misses.load(Ordering::Relaxed);
        if hits + misses == 0 {
            return 0.0;
        }
        hits as f64 / (hits + misses) as f64
    }

    /// 获取章节验证成功率
    pub fn get_chapter_validate_success_rate(&self) -> f64 {
        let count = self.chapter_validate_count.load(Ordering::Relaxed);
        let failures = self.chapter_validate_failures.load(Ordering::Relaxed);
        if count == 0 {
            return 1.0;
        }
        (count - failures) as f64 / count as f64
    }

    /// 获取完整统计信息
    pub fn get_stats(&self) -> MetricsStats {
        MetricsStats {
            parse_count: self.parse_count.load(Ordering::Relaxed),
            average_parse_time_ms: self.get_average_parse_time(),
            cache_hit_rate: self.get_cache_hit_rate(),
            search_count: self.search_count.load(Ordering::Relaxed),
            average_search_time_ms: self.get_average_search_time(),
            file_read_count: self.file_read_count.load(Ordering::Relaxed),
            average_file_read_time_ms: self.get_average_file_read_time(),
            chapter_validate_count: self.chapter_validate_count.load(Ordering::Relaxed),
            chapter_validate_success_rate: self.get_chapter_validate_success_rate(),
        }
    }

    /// 重置所有指标
    pub fn reset(&self) {
        self.parse_count.store(0, Ordering::Relaxed);
        self.parse_total_ms.store(0, Ordering::Relaxed);
        self.cache_hits.store(0, Ordering::Relaxed);
        self.cache_misses.store(0, Ordering::Relaxed);
        self.search_count.store(0, Ordering::Relaxed);
        self.search_total_ms.store(0, Ordering::Relaxed);
        self.file_read_count.store(0, Ordering::Relaxed);
        self.file_read_total_ms.store(0, Ordering::Relaxed);
        self.chapter_validate_count.store(0, Ordering::Relaxed);
        self.chapter_validate_failures.store(0, Ordering::Relaxed);
    }
}

impl Default for PerformanceMetrics {
    fn default() -> Self {
        Self::new()
    }
}

/// 性能统计信息
#[derive(Debug, Clone)]
pub struct MetricsStats {
    /// 解析操作次数
    pub parse_count: usize,
    /// 平均解析时间（毫秒）
    pub average_parse_time_ms: f64,
    /// 缓存命中率（0.0 - 1.0）
    pub cache_hit_rate: f64,
    /// 搜索操作次数
    pub search_count: usize,
    /// 平均搜索时间（毫秒）
    pub average_search_time_ms: f64,
    /// 文件读取次数
    pub file_read_count: usize,
    /// 平均文件读取时间（毫秒）
    pub average_file_read_time_ms: f64,
    /// 章节验证次数
    pub chapter_validate_count: usize,
    /// 章节验证成功率（0.0 - 1.0）
    pub chapter_validate_success_rate: f64,
}

/// 全局性能指标收集器
pub static METRICS: Lazy<PerformanceMetrics> = Lazy::new(PerformanceMetrics::new);

/// 记录解析操作宏
///
/// # 使用示例
///
/// ```rust
/// use rust_lib_zephyr_reader::utils::metrics::{record_metrics, METRICS};
/// use std::time::Instant;
///
/// let start = Instant::now();
/// // ... 执行解析 ...
/// record_metrics!(parse, start);
/// ```
#[macro_export]
macro_rules! record_metrics {
    (parse, $start:expr) => {
        $crate::utils::metrics::METRICS.record_parse($start.elapsed().as_millis() as u64);
    };
    (cache_hit) => {
        $crate::utils::metrics::METRICS.record_cache_hit();
    };
    (cache_miss) => {
        $crate::utils::metrics::METRICS.record_cache_miss();
    };
    (search, $start:expr) => {
        $crate::utils::metrics::METRICS.record_search($start.elapsed().as_millis() as u64);
    };
    (file_read, $start:expr) => {
        $crate::utils::metrics::METRICS.record_file_read($start.elapsed().as_millis() as u64);
    };
    (chapter_validate, $success:expr) => {
        $crate::utils::metrics::METRICS.record_chapter_validate($success);
    };
}

/// 获取性能统计信息（FFI 接口）
///
/// 供 Flutter 侧调用，获取当前性能指标。
#[flutter_rust_bridge::frb(sync)]
pub fn get_performance_stats() -> MetricsStats {
    METRICS.get_stats()
}

/// 重置性能指标（FFI 接口）
///
/// 供 Flutter 侧调用，重置所有性能指标。
#[flutter_rust_bridge::frb(sync)]
pub fn reset_performance_stats() {
    METRICS.reset();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_performance_metrics_record_parse() {
        let metrics = PerformanceMetrics::new();

        metrics.record_parse(100);
        metrics.record_parse(200);
        metrics.record_parse(300);

        assert_eq!(metrics.parse_count.load(Ordering::Relaxed), 3);
        assert_eq!(metrics.parse_total_ms.load(Ordering::Relaxed), 600);
        assert!((metrics.get_average_parse_time() - 200.0).abs() < f64::EPSILON);
    }

    #[test]
    fn test_performance_metrics_cache_hit_rate() {
        let metrics = PerformanceMetrics::new();

        metrics.record_cache_hit();
        metrics.record_cache_hit();
        metrics.record_cache_miss();

        assert_eq!(metrics.cache_hits.load(Ordering::Relaxed), 2);
        assert_eq!(metrics.cache_misses.load(Ordering::Relaxed), 1);
        assert!((metrics.get_cache_hit_rate() - 0.666666).abs() < 0.001);
    }

    #[test]
    fn test_performance_metrics_search() {
        let metrics = PerformanceMetrics::new();

        metrics.record_search(50);
        metrics.record_search(150);

        assert_eq!(metrics.search_count.load(Ordering::Relaxed), 2);
        assert_eq!(metrics.search_total_ms.load(Ordering::Relaxed), 200);
        assert!((metrics.get_average_search_time() - 100.0).abs() < f64::EPSILON);
    }

    #[test]
    fn test_performance_metrics_reset() {
        let metrics = PerformanceMetrics::new();

        metrics.record_parse(100);
        metrics.record_cache_hit();
        metrics.record_search(50);

        metrics.reset();

        assert_eq!(metrics.parse_count.load(Ordering::Relaxed), 0);
        assert_eq!(metrics.cache_hits.load(Ordering::Relaxed), 0);
        assert_eq!(metrics.search_count.load(Ordering::Relaxed), 0);
    }

    #[test]
    fn test_performance_metrics_chapter_validate() {
        let metrics = PerformanceMetrics::new();

        metrics.record_chapter_validate(true);
        metrics.record_chapter_validate(true);
        metrics.record_chapter_validate(false);

        assert_eq!(metrics.chapter_validate_count.load(Ordering::Relaxed), 3);
        assert_eq!(metrics.chapter_validate_failures.load(Ordering::Relaxed), 1);
        assert!((metrics.get_chapter_validate_success_rate() - 0.666666).abs() < 0.001);
    }

    #[test]
    fn test_metrics_stats_structure() {
        let metrics = PerformanceMetrics::new();
        let stats = metrics.get_stats();

        assert_eq!(stats.parse_count, 0);
        assert_eq!(stats.average_parse_time_ms, 0.0);
        assert_eq!(stats.cache_hit_rate, 0.0);
        assert_eq!(stats.search_count, 0);
    }
}
