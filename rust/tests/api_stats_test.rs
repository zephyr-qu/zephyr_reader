//! 阅读统计 API 集成测试
//!
//! 只覆盖存活的读接口：`get_reading_stats_by_days_with_fill`（补零）与
//! `get_global_reading_stats`。数据写入路径由 `api_session_test.rs` 的
//! `create_session` 聚合测试覆盖（不变量：reading_stats 只在会话结束时聚合）。

mod common;

use rust_lib_zephyr_reader::api::session;
use rust_lib_zephyr_reader::api::stats;

// ==================== 最近N天查询（补零） ====================

#[tokio::test]
async fn test_get_reading_stats_by_days_with_fill_shape() {
    common::init_logger();
    common::init_test_storage().await;

    // 不变量：无论库中是否有数据，窗口内每天都应有一条记录（补零）。
    // 注意：集成测试共享 TEST_STORAGE 单例，并行测试可能先写入，故不做“空库”假设。
    let results = stats::get_reading_stats_by_days_with_fill(30)
        .await
        .unwrap();
    assert_eq!(
        results.len(),
        30,
        "应返回整整 30 天（含补零），got {}",
        results.len()
    );
    assert_eq!(
        results.first().unwrap().date,
        (chrono::Utc::now().date_naive() - chrono::Duration::days(29)).to_string(),
        "窗口应从 29 天前开始",
    );
}

#[tokio::test]
async fn test_get_reading_stats_by_days_with_fill_contains_aggregated_sessions() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_fill").await;

    // 通过 create_session 聚合写入（唯一合法写入路径）
    let now = chrono::Utc::now();
    session::create_session(
        "stats_test_book_fill".to_string(),
        0,
        now.timestamp(),
        1000,
    )
    .await
    .unwrap();

    let results = stats::get_reading_stats_by_days_with_fill(7).await.unwrap();
    // GROUP BY date 后 book_id 为聚合占位符，按“有阅读时长”的行断言
    let today_str = chrono::Utc::now().date_naive().to_string();
    let entry = results
        .iter()
        .find(|s| s.date == today_str && s.reading_time_seconds > 0);
    assert!(entry.is_some(), "今天应有聚合后的会话数据");
    assert_eq!(entry.unwrap().session_count, 1);
}

// ==================== 全局统计 ====================

#[tokio::test]
async fn test_get_global_reading_stats() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_global").await;

    let global = stats::get_global_reading_stats().await.unwrap();
    assert!(
        global.total_books_count >= 1,
        "应有至少 1 本书（ensure_test_book 已创建），got {}",
        global.total_books_count
    );
}
