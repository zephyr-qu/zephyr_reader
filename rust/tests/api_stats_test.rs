//! 阅读统计 API 集成测试
//!
//! 测试每日阅读统计的 CRUD 操作和全局统计汇总功能。

mod common;

use rust_lib_zephyr_reader::api::stats;
use rust_lib_zephyr_reader::domain::stats::models::ReadingStats;

fn make_stats(book_id: &str, date: &str, secs: i64, chars: i64) -> ReadingStats {
    ReadingStats {
        book_id: book_id.to_string(),
        date: date.to_string(),
        reading_time_seconds: secs,
        characters_read: chars,
        session_count: 1,
        last_session_id: None,
    }
}

// ==================== 今日统计 ====================

#[tokio::test]
async fn test_update_and_get_today_stats() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_today").await;

    let today = chrono::Utc::now().date_naive().to_string();
    let stats = make_stats("stats_test_book_today", &today, 1800, 5000);
    stats::update_daily_stats(stats).await.unwrap();

    let results = stats::get_today_reading_stats().await.unwrap();
    assert!(
        !results.is_empty(),
        "should have at least one reading stats for today"
    );
    let entry = results
        .iter()
        .find(|s| s.book_id == "stats_test_book_today");
    assert!(entry.is_some(), "should find the inserted book's stats");
    assert_eq!(entry.unwrap().reading_time_seconds, 1800);
}

// ==================== 范围查询 ====================

#[tokio::test]
async fn test_get_reading_stats_by_range() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_range").await;

    // Insert stats for a known date
    let stats = make_stats("stats_test_book_range", "2024-06-01", 900, 2000);
    stats::update_daily_stats(stats).await.unwrap();

    // Query range that includes that date
    let results =
        stats::get_reading_stats_by_range("2024-06-01".to_string(), "2024-06-07".to_string())
            .await
            .unwrap();
    assert!(
        !results.is_empty(),
        "should return stats for the matching range"
    );

    // Query range that does NOT include it
    let empty =
        stats::get_reading_stats_by_range("2024-07-01".to_string(), "2024-07-07".to_string())
            .await
            .unwrap();
    assert!(
        empty.is_empty(),
        "should return empty for non-matching range"
    );
}

// ==================== 最近N天查询 ====================

#[tokio::test]
async fn test_get_reading_stats_by_days() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_days").await;

    let today = chrono::Utc::now().date_naive().to_string();
    let stats = make_stats("stats_test_book_days", &today, 600, 1500);
    stats::update_daily_stats(stats).await.unwrap();

    let results = stats::get_reading_stats_by_days(30).await.unwrap();
    // May include multiple entries; at minimum our inserted one should be present
    let entry = results.iter().find(|s| s.book_id == "stats_test_book_days");
    assert!(
        entry.is_some(),
        "should find stats for the test book in last 30 days"
    );
}

#[tokio::test]
async fn test_get_reading_stats_by_days_with_fill() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_fill").await;

    let today = chrono::Utc::now().date_naive().to_string();
    let stats = make_stats("stats_test_book_fill", &today, 600, 1500);
    stats::update_daily_stats(stats).await.unwrap();

    let results = stats::get_reading_stats_by_days_with_fill(30)
        .await
        .unwrap();
    // find_by_days_with_fill collapses by date (day → one entry), so book_id
    // may not be ours if another test inserted a record for today. Just verify
    // the API call succeeds and returns the expected number of days.
    assert_eq!(
        results.len(),
        30,
        "should return exactly 30 entries for 30-day fill, got {}",
        results.len()
    );
}

// ==================== 全局统计 ====================

#[tokio::test]
async fn test_get_global_reading_stats() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_global").await;

    // Insert a reading_stats entry (global stats reads from sessions table,
    // not reading_stats, so we can't assert on reading_time here).
    // Just verify the API call succeeds and books are counted.
    let today = chrono::Utc::now().date_naive().to_string();
    let stats = make_stats("stats_test_book_global", &today, 3600, 10000);
    stats::update_daily_stats(stats).await.unwrap();

    let global = stats::get_global_reading_stats().await.unwrap();
    assert!(
        global.total_books_count >= 1,
        "there should be at least 1 book since we created one, got {}",
        global.total_books_count
    );
}
// ==================== 多天更新 ====================

#[tokio::test]
async fn test_update_multiple_days() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("stats_test_book_multi").await;

    // Use far-future dates to avoid overlaps with other tests
    let stats1 = make_stats("stats_test_book_multi", "2099-06-01", 1200, 3000);
    let stats2 = make_stats("stats_test_book_multi", "2099-06-02", 2400, 6000);
    stats::update_daily_stats(stats1).await.unwrap();
    stats::update_daily_stats(stats2).await.unwrap();

    let results =
        stats::get_reading_stats_by_range("2099-06-01".to_string(), "2099-06-02".to_string())
            .await
            .unwrap();
    assert_eq!(
        results.len(),
        2,
        "should return 2 entries for the two-day range, got {}",
        results.len()
    );

    let day1 = results.iter().find(|s| s.date == "2099-06-01");
    let day2 = results.iter().find(|s| s.date == "2099-06-02");
    assert!(day1.is_some(), "should have entry for 2099-06-01");
    assert!(day2.is_some(), "should have entry for 2099-06-02");
    assert_eq!(day1.unwrap().reading_time_seconds, 1200);
    assert_eq!(day2.unwrap().reading_time_seconds, 2400);
}
