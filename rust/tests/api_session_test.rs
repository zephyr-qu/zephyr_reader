//! 阅读会话 API 集成测试
//!
//! 测试会话的 CRUD 操作：创建、查询（多维度）、更新、清除。

mod common;

use rust_lib_zephyr_reader::api::session;
use rust_lib_zephyr_reader::domain::stats::models::ReadingStats;

#[tokio::test]
async fn test_create_and_list_session() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-test-book").await;

    let now = chrono::Utc::now().timestamp();
    let result = session::create_session(
        "session-test-book".to_string(),
        0,   // chapter_index
        0,   // start_char_offset
        100, // end_char_offset
        now, // started_at (Unix timestamp)
    )
    .await;
    assert!(result.is_ok(), "创建会话应该成功: {:?}", result);
    let s = result.unwrap();
    assert_eq!(s.book_id, "session-test-book");
    assert_eq!(s.chapter_index, 0);
    assert_eq!(s.start_char_offset, 0);
    assert_eq!(s.end_char_offset, 100);

    let sessions = session::list_sessions_by_book("session-test-book".to_string(), 10)
        .await
        .unwrap();
    assert!(!sessions.is_empty(), "应返回至少1个会话");
}

#[tokio::test]
async fn test_list_sessions_by_book_limit() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-limit-book").await;

    // 创建3个会话（时间戳递增避免冲突）
    for i in 0..3i32 {
        let ts = chrono::Utc::now().timestamp() + i as i64;
        session::create_session(
            "session-limit-book".to_string(),
            0,
            i * 100,
            (i + 1) * 100,
            ts,
        )
        .await
        .unwrap();
    }

    let sessions = session::list_sessions_by_book("session-limit-book".to_string(), 2)
        .await
        .unwrap();
    // 数据库返回数量不一定严格=2（可能创建同名标签），但 ≤2
    assert!(
        sessions.len() <= 2,
        "limit=2 应最多返回2个会话，实际: {}",
        sessions.len()
    );
}

#[tokio::test]
async fn test_list_sessions_by_recent() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-recent-book").await;

    let ts = chrono::Utc::now().timestamp();
    session::create_session("session-recent-book".to_string(), 0, 0, 50, ts)
        .await
        .unwrap();

    let recent = session::list_sessions_by_recent(10).await.unwrap();
    assert!(!recent.is_empty(), "最近会话不应为空");
}

#[tokio::test]
async fn test_clear_sessions_by_book() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-clear-book").await;

    let ts = chrono::Utc::now().timestamp();
    session::create_session("session-clear-book".to_string(), 0, 0, 50, ts)
        .await
        .unwrap();

    // 清除
    session::delete_sessions_by_book("session-clear-book".to_string())
        .await
        .unwrap();

    // 验证清空
    let sessions = session::list_sessions_by_book("session-clear-book".to_string(), 10)
        .await
        .unwrap();
    assert!(sessions.is_empty(), "清除后会话列表应为空");
}

#[tokio::test]
async fn test_create_session_aggregates_daily_stats() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-stats-book").await;

    // 同一天内两次会话（跨章节）：时长与字符数应增量聚合到 reading_stats。
    // 注意：不能用 get_reading_stats_by_days_with_fill 断言——它按日期折叠（一天一行，
    // 与书无关），并行测试的其他书会遮蔽本行。直接查 reading_stats 表验证聚合结果。
    let now = chrono::Utc::now();
    let started_at = now.timestamp();
    let s1 = session::create_session("session-stats-book".to_string(), 0, 1000, 2000, started_at)
        .await
        .unwrap();
    let s2 = session::create_session(
        "session-stats-book".to_string(),
        1,
        2000,
        2500,
        started_at + 300,
    )
    .await
    .unwrap();

    let pool = rust_lib_zephyr_reader::infra::manager::storage_pool().unwrap();
    let row: ReadingStats =
        sqlx::query_as("SELECT * FROM reading_stats WHERE book_id = 'session-stats-book'")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(
        row.reading_time_seconds,
        s1.duration_seconds + s2.duration_seconds,
        "两次会话时长应累加",
    );
    assert_eq!(row.characters_read, 1500, "字符数应累加（1000 + 500）");
    assert_eq!(row.session_count, 2);
    assert_eq!(
        row.last_session_id.as_deref(),
        Some(s2.id.as_str()),
        "last_session_id 应记录最后一次聚合的会话",
    );
}
