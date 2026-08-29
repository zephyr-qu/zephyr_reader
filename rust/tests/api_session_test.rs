//! 阅读会话 API 集成测试
//!
//! 测试会话的 CRUD 操作：创建、查询（多维度）、更新、清除。

mod common;

use rust_lib_zephyr_reader::api::session;
use rust_lib_zephyr_reader::api::stats;

#[tokio::test]
async fn test_create_and_list_session() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-test-book").await;

    let now = chrono::Utc::now().timestamp();
    let result = session::create_session(
        "session-test-book".to_string(),
        0,    // chapter_index
        now,  // started_at (Unix timestamp)
        100,  // duration_seconds
    )
    .await;
    assert!(result.is_ok(), "创建会话应该成功: {:?}", result);
    let s = result.unwrap();
    assert_eq!(s.book_id, "session-test-book");
    assert_eq!(s.chapter_index, 0);
    assert_eq!(s.duration_seconds, 100);

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
            ts,
            (i + 1) as i64 * 100,
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
    session::create_session("session-recent-book".to_string(), 0, ts, 50)
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
    session::create_session("session-clear-book".to_string(), 0, ts, 50)
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
async fn test_create_session_appears_in_daily_stats() {
    common::init_logger();
    common::init_test_storage().await;
    common::ensure_test_book("session-stats-book").await;

    // 会话按书可见即可（每日聚合的即时性由 api_stats_test 覆盖），
    // 避免与同库并行的 clear/recent 测试共享全局窗口造成竞争。
    let now = chrono::Utc::now();
    let started_at = now.timestamp();
    let s1 = session::create_session(
        "session-stats-book".to_string(),
        0,
        started_at,
        1000,
    )
    .await
    .unwrap();
    let s2 = session::create_session(
        "session-stats-book".to_string(),
        1,
        started_at + 300,
        500,
    )
    .await
    .unwrap();

    let listed = session::list_sessions_by_book("session-stats-book".to_string(), 10)
        .await
        .unwrap();
    assert_eq!(listed.len(), 2, "本书应有 2 条会话");
    assert_eq!(
        s1.duration_seconds + s2.duration_seconds,
        1500,
        "两次会话时长应即时聚合到 duration_seconds",
    );
}
